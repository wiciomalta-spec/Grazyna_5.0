// ============================================================
// GRAŻYNA 5.0 — OPTYMALIZACJA EVENT LOOP
// Analiza oparta na RZECZYWISTYCH metrykach:
//   Przed: lag=19ms, max=869ms, p99=24.8ms
//   Po:    lag=1.58ms, max=35ms, p99=29.9ms
//
// Cel: lag<5ms, max<20ms, p99<15ms, heap<70%
// ============================================================

// ─────────────────────────────────────────────────────────
// 1. NODE.JS STARTUP FLAGS (package.json scripts)
// ─────────────────────────────────────────────────────────
/*
  W backend/package.json zmień scripts:

  "dev":   "node --max-old-space-size=256 --expose-gc node_modules/.bin/tsx watch src/index.ts",
  "start": "node --max-old-space-size=256 --expose-gc dist/index.js",

  Flagi:
  --max-old-space-size=256   → limit heap do 256MB (wymusza GC wcześniej)
  --expose-gc                → pozwala na ręczne gc() w kodzie
  --max-semi-space-size=64   → mniejszy new space → częstszy minor GC (szybszy)
  --optimize-for-size        → mniejszy kod, wolniejszy start ale mniej RAM
*/

// ─────────────────────────────────────────────────────────
// 2. EVENT LOOP MONITOR — wykrywa blokady
// ─────────────────────────────────────────────────────────
import { monitorEventLoopDelay } from 'perf_hooks';

const EL_WARN_THRESHOLD_MS  = 50;   // ostrzeżenie
const EL_CRIT_THRESHOLD_MS  = 100;  // krytyczny
const EL_SAMPLE_INTERVAL_MS = 1000; // próbkowanie co 1s

export function startEventLoopMonitor(io?: any) {
  const histogram = monitorEventLoopDelay({ resolution: 10 });
  histogram.enable();

  let warnCount = 0;
  let critCount = 0;

  setInterval(() => {
    const lagMs = histogram.mean / 1e6;
    const maxMs = histogram.max  / 1e6;
    const p99Ms = histogram.percentile(99) / 1e6;

    // Reset histogram co iterację
    histogram.reset();

    // Log do Winston
    if (maxMs > EL_CRIT_THRESHOLD_MS) {
      critCount++;
      console.error(`[EL] 🔴 KRYTYCZNY lag: mean=${lagMs.toFixed(1)}ms max=${maxMs.toFixed(1)}ms p99=${p99Ms.toFixed(1)}ms`);
      // Emit alert przez Socket.io
      if (io) io.emit('alert:new', {
        type: 'system', severity: 'critical',
        message: `Event Loop lag krytyczny: ${maxMs.toFixed(0)}ms`,
        timestamp: new Date().toISOString()
      });
    } else if (maxMs > EL_WARN_THRESHOLD_MS) {
      warnCount++;
      console.warn(`[EL] ⚠️  Wysoki lag: mean=${lagMs.toFixed(1)}ms max=${maxMs.toFixed(1)}ms`);
    } else {
      // Tylko co 60s loguj OK
      if (Date.now() % 60000 < EL_SAMPLE_INTERVAL_MS) {
        console.log(`[EL] ✅ OK: mean=${lagMs.toFixed(1)}ms max=${maxMs.toFixed(1)}ms p99=${p99Ms.toFixed(1)}ms`);
      }
    }

    // Expose metrics dla Prometheus
    elLagGauge.set(lagMs);
    elLagMaxGauge.set(maxMs);
    elLagP99Gauge.set(p99Ms);

  }, EL_SAMPLE_INTERVAL_MS);

  console.log('[EL] Event Loop Monitor uruchomiony (threshold: warn=50ms crit=100ms)');
  return histogram;
}

// ─────────────────────────────────────────────────────────
// 3. PROMETHEUS GAUGES dla EL
// ─────────────────────────────────────────────────────────
import * as promClient from 'prom-client';

export const elLagGauge = new promClient.Gauge({
  name: 'nodejs_eventloop_lag_custom_ms',
  help: 'Custom Event Loop lag in milliseconds (mean)',
});
export const elLagMaxGauge = new promClient.Gauge({
  name: 'nodejs_eventloop_lag_custom_max_ms',
  help: 'Custom Event Loop lag max in milliseconds',
});
export const elLagP99Gauge = new promClient.Gauge({
  name: 'nodejs_eventloop_lag_custom_p99_ms',
  help: 'Custom Event Loop lag p99 in milliseconds',
});

// ─────────────────────────────────────────────────────────
// 4. ASYNC QUEUE — zapobiega blokowaniu EL
// ─────────────────────────────────────────────────────────
import { setImmediate as setImmediatePromise } from 'timers/promises';

/**
 * Przetwarza duże tablice w chunkach, oddając kontrolę EL między chunkami.
 * Zapobiega blokowaniu event loop przez długie operacje synchroniczne.
 */
export async function processInChunks<T, R>(
  items: T[],
  processor: (item: T) => R,
  chunkSize = 100
): Promise<R[]> {
  const results: R[] = [];
  for (let i = 0; i < items.length; i += chunkSize) {
    const chunk = items.slice(i, i + chunkSize);
    results.push(...chunk.map(processor));
    // Oddaj kontrolę event loop między chunkami
    await setImmediatePromise();
  }
  return results;
}

// ─────────────────────────────────────────────────────────
// 5. WORKER THREADS — CPU-intensive tasks poza EL
// ─────────────────────────────────────────────────────────
import { Worker, isMainThread, parentPort, workerData } from 'worker_threads';
import { cpus } from 'os';

/**
 * Uruchamia CPU-intensive zadanie w Worker Thread.
 * Nie blokuje głównego Event Loop.
 */
export function runInWorker<T>(workerScript: string, data: any): Promise<T> {
  return new Promise((resolve, reject) => {
    const worker = new Worker(workerScript, { workerData: data });
    worker.on('message', resolve);
    worker.on('error', reject);
    worker.on('exit', (code) => {
      if (code !== 0) reject(new Error(`Worker exited with code ${code}`));
    });
  });
}

// ─────────────────────────────────────────────────────────
// 6. CLUSTER MODE — wykorzystaj wszystkie CPU cores
// ─────────────────────────────────────────────────────────
import cluster from 'cluster';

export function startWithCluster(workerFn: () => void) {
  const numCPUs = cpus().length;

  if (cluster.isPrimary) {
    console.log(`[Cluster] Primary ${process.pid} uruchomiony`);
    console.log(`[Cluster] Uruchamiam ${numCPUs} workerów...`);

    for (let i = 0; i < numCPUs; i++) {
      cluster.fork();
    }

    cluster.on('exit', (worker, code, signal) => {
      console.warn(`[Cluster] Worker ${worker.process.pid} zakończył (${signal || code}). Restartuję...`);
      cluster.fork(); // Auto-restart
    });

    // Graceful shutdown
    process.on('SIGTERM', () => {
      console.log('[Cluster] SIGTERM — zamykam workerów...');
      for (const id in cluster.workers) {
        cluster.workers[id]?.kill('SIGTERM');
      }
    });
  } else {
    console.log(`[Cluster] Worker ${process.pid} uruchomiony`);
    workerFn();
  }
}

// ─────────────────────────────────────────────────────────
// 7. RESPONSE CACHING — zmniejsza obciążenie EL
// ─────────────────────────────────────────────────────────
import { Request, Response, NextFunction } from 'express';

const cache = new Map<string, { data: any; expires: number }>();

export function cacheMiddleware(ttlMs = 5000) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (req.method !== 'GET') return next();

    const key = req.originalUrl;
    const cached = cache.get(key);

    if (cached && cached.expires > Date.now()) {
      res.setHeader('X-Cache', 'HIT');
      res.setHeader('X-Cache-TTL', Math.round((cached.expires - Date.now()) / 1000) + 's');
      return res.json(cached.data);
    }

    // Intercept response
    const originalJson = res.json.bind(res);
    res.json = (data: any) => {
      cache.set(key, { data, expires: Date.now() + ttlMs });
      res.setHeader('X-Cache', 'MISS');
      return originalJson(data);
    };

    next();
  };
}

// Wyczyść wygasłe wpisy co 60s
setInterval(() => {
  const now = Date.now();
  for (const [key, val] of cache.entries()) {
    if (val.expires < now) cache.delete(key);
  }
}, 60000);

// ─────────────────────────────────────────────────────────
// 8. HEAP DUMP — diagnostyka przy wysokim heap
// ─────────────────────────────────────────────────────────
export async function takeHeapSnapshotIfNeeded(thresholdPct = 85) {
  const mem = process.memoryUsage();
  const heapPct = (mem.heapUsed / mem.heapTotal) * 100;

  if (heapPct > thresholdPct) {
    console.warn(`[Heap] ⚠️  Heap ${heapPct.toFixed(1)}% > ${thresholdPct}% — rozważ heap dump`);

    // Ręczny GC jeśli dostępny (--expose-gc)
    if (typeof (global as any).gc === 'function') {
      (global as any).gc();
      const after = process.memoryUsage();
      const afterPct = (after.heapUsed / after.heapTotal) * 100;
      console.log(`[Heap] Po GC: ${afterPct.toFixed(1)}%`);
    }
  }
}

// Sprawdzaj heap co 30s
setInterval(() => takeHeapSnapshotIfNeeded(85), 30000);

// ─────────────────────────────────────────────────────────
// 9. OPTYMALIZACJE PRISMA — zmniejsz czas zapytań
// ─────────────────────────────────────────────────────────
/*
  W backend/src/config/database.ts:

  export const prisma = new PrismaClient({
    log: process.env.NODE_ENV === 'development'
      ? ['warn', 'error']  // Nie loguj query w dev (blokuje EL)
      : ['error'],
    datasources: {
      db: {
        url: process.env.DATABASE_URL,
      },
    },
  });

  // Connection pool optimization
  // DATABASE_URL="postgresql://...?connection_limit=10&pool_timeout=20"
*/

// ─────────────────────────────────────────────────────────
// 10. UŻYCIE W index.ts
// ─────────────────────────────────────────────────────────
/*
  import { startEventLoopMonitor, cacheMiddleware } from './el-optimization';

  // Po utworzeniu io:
  startEventLoopMonitor(io);

  // Cache dla statycznych endpointów:
  app.use('/api/vehicles', cacheMiddleware(10000));  // 10s cache
  app.use('/api/drivers',  cacheMiddleware(10000));

  // Cluster mode (opcjonalnie, dla produkcji):
  // startWithCluster(() => { ... kod serwera ... });
*/

// ─────────────────────────────────────────────────────────
// WYNIKI OPTYMALIZACJI (oczekiwane)
// ─────────────────────────────────────────────────────────
/*
  Metryka              Przed    Po fix   Po optymalizacji
  ─────────────────────────────────────────────────────
  EL Lag current       19ms     1.58ms   <1ms
  EL Lag max           869ms    35ms     <20ms
  EL Lag p99           24.8ms   29.9ms   <10ms
  Heap usage           93.8%    91.1%    <70%
  /health latency      404      2.28ms   <1ms
  /api latency         862ms    2.5ms    <2ms
  GC Minor             5×       26×      ~15× (zdrowszy)
  RSS                  60MB     63MB     ~55MB (cluster)
*/