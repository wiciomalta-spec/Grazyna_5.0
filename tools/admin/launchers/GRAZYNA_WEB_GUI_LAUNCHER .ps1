# ============================================================
# GRAŻYNA 5.0 — FIX Worker Thread ".ts" extension error
# Problem: Worker nie może załadować .ts — brak tsx w workerze
# Rozwiązanie: Użyj --require tsx/cjs lub skompiluj worker do .js
# ============================================================

$proj    = "E:\Grazyna_5.0"
$backend = "$proj\backend"
$nodeExe = "$proj\tools\nodejs\node.exe"
$npmCmd  = "$proj\tools\nodejs\npm.cmd"
$src     = "$backend\src"

function Log($level, $msg) {
    $col = switch($level) { "OK"{"Green"}; "WARN"{"Yellow"}; "ERR"{"Red"}; "INFO"{"Cyan"} }
    $ico = switch($level) { "OK"{"✅"}; "WARN"{"⚠️"}; "ERR"{"❌"}; "INFO"{"ℹ️"} }
    Write-Host "  $ico $msg" -ForegroundColor $col
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║  GRAŻYNA 5.0 — FIX Worker Thread .ts Extension       ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""
Write-Host "  Problem: Worker nie może załadować .ts bez tsx" -ForegroundColor Yellow
Write-Host "  Fix:     Przepisz worker na .js (CommonJS)" -ForegroundColor Cyan
Write-Host ""

# ─── KROK 1: Utwórz katalog workers ──────────────────────
Write-Host "[ 1/4 ] Tworzenie katalogu workers..." -ForegroundColor Yellow
$workersDir = "$src\workers"
if (-not (Test-Path $workersDir)) {
    New-Item -ItemType Directory $workersDir -Force | Out-Null
}
Log "OK" "Katalog: $workersDir"

# ─── KROK 2: Zapisz tasks.worker.js (CommonJS, nie .ts) ──
Write-Host "[ 2/4 ] Tworzenie tasks.worker.js (CommonJS)..." -ForegroundColor Yellow

$workerJs = @'
// ============================================================
// GRAŻYNA 5.0 — tasks.worker.js (CommonJS — działa w Worker)
// NIE używaj .ts — Worker Threads nie mają dostępu do tsx
// ============================================================
'use strict';

const { parentPort } = require('worker_threads');
const crypto = require('crypto');

if (!parentPort) throw new Error('Not a worker thread');

// Lazy-load bcryptjs (tylko gdy potrzebny)
let bcrypt = null;
function getBcrypt() {
  if (!bcrypt) bcrypt = require('bcryptjs');
  return bcrypt;
}

parentPort.on('message', async ({ id, type, data }) => {
  try {
    let result;

    switch (type) {

      // ── BCRYPT ──────────────────────────────────────────
      case 'bcrypt:hash':
        result = await getBcrypt().hash(data.password, data.rounds || 12);
        break;

      case 'bcrypt:compare':
        result = await getBcrypt().compare(data.password, data.hash);
        break;

      // ── RAPORT FLOTY ────────────────────────────────────
      case 'report:fleet': {
        const vehicles = data.vehicles || [];
        const stats = vehicles.reduce((acc, v) => {
          acc.totalMileage  += v.mileage   || 0;
          acc.totalFuelCost += v.fuelCost  || 0;
          acc.byStatus[v.status] = (acc.byStatus[v.status] || 0) + 1;
          return acc;
        }, { totalMileage: 0, totalFuelCost: 0, byStatus: {} });

        result = {
          period:        data.period,
          totalVehicles: vehicles.length,
          ...stats,
          avgMileage:    vehicles.length > 0 ? stats.totalMileage / vehicles.length : 0,
          generatedAt:   new Date().toISOString(),
        };
        break;
      }

      // ── AGREGACJA GPS ────────────────────────────────────
      case 'gps:aggregate': {
        const points   = data.points || [];
        const interval = (data.intervalMinutes || 5) * 60000;
        const buckets  = new Map();

        for (const pt of points) {
          const bucket = Math.floor(pt.timestamp / interval);
          if (!buckets.has(bucket)) buckets.set(bucket, []);
          buckets.get(bucket).push(pt);
        }

        result = Array.from(buckets.entries()).map(([bucket, pts]) => ({
          timestamp: bucket * interval,
          avgLat:    pts.reduce((s, p) => s + p.lat,         0) / pts.length,
          avgLng:    pts.reduce((s, p) => s + p.lng,         0) / pts.length,
          avgSpeed:  pts.reduce((s, p) => s + (p.speed || 0), 0) / pts.length,
          count:     pts.length,
        }));
        break;
      }

      // ── HASH SHA256 ──────────────────────────────────────
      case 'hash:sha256':
        result = crypto.createHash('sha256').update(String(data.input)).digest('hex');
        break;

      // ── ANALIZA STATYSTYCZNA ─────────────────────────────
      case 'stats:analyze': {
        const metrics = data.metrics || [];
        if (metrics.length === 0) { result = {}; break; }
        const sorted = [...metrics].sort((a, b) => a - b);
        const n    = sorted.length;
        const mean = metrics.reduce((a, b) => a + b, 0) / n;
        const variance = metrics.reduce((s, v) => s + (v - mean) ** 2, 0) / n;
        result = {
          count: n,
          mean:  +mean.toFixed(3),
          std:   +Math.sqrt(variance).toFixed(3),
          min:   sorted[0],
          max:   sorted[n - 1],
          p50:   sorted[Math.floor(n * 0.50)],
          p90:   sorted[Math.floor(n * 0.90)],
          p99:   sorted[Math.floor(n * 0.99)],
        };
        break;
      }

      // ── KOMPRESJA JSON ───────────────────────────────────
      case 'json:compress': {
        const buf = Buffer.from(JSON.stringify(data.payload));
        result = { compressed: buf.toString('base64'), originalSize: buf.length };
        break;
      }

      // ── PING (test) ──────────────────────────────────────
      case 'ping':
        result = { pong: true, ts: Date.now(), pid: process.pid };
        break;

      default:
        throw new Error(`Unknown task type: ${type}`);
    }

    parentPort.postMessage({ id, data: result });

  } catch (err) {
    parentPort.postMessage({ id, error: err.message || String(err) });
  }
});

// Sygnał gotowości
parentPort.postMessage({ id: '__ready__', data: { pid: process.pid } });
'@

$workerJs | Out-File "$workersDir\tasks.worker.js" -Encoding UTF8
Log "OK" "Zapisano: src\workers\tasks.worker.js"

# ─── KROK 3: Napraw worker-pool.ts — wskaż .js ───────────
Write-Host "[ 3/4 ] Naprawa worker-pool.ts (ścieżka do .js)..." -ForegroundColor Yellow

$workerPoolPath = "$src\worker-pool.ts"
if (Test-Path $workerPoolPath) {
    $content = Get-Content $workerPoolPath -Raw

    # Zamień ścieżkę .ts na .js
    $fixed = $content `
        -replace "tasks\.worker\.ts", "tasks.worker.js" `
        -replace "workers/tasks\.worker'", "workers/tasks.worker.js'" `
        -replace 'workers/tasks\.worker"', 'workers/tasks.worker.js"' `
        -replace "__dirname.*tasks\.worker\b", "__dirname, 'workers', 'tasks.worker.js'" `
        -replace "path\.join\(__dirname,\s*['""]workers['""],\s*['""]tasks\.worker['""]", "path.join(__dirname, 'workers', 'tasks.worker.js'"

    # Jeśli nie znaleziono — dodaj komentarz z instrukcją
    if ($fixed -eq $content) {
        Log "WARN" "Nie znaleziono ścieżki do tasks.worker — sprawdź ręcznie"
        Log "INFO" "Szukaj w worker-pool.ts: new Worker(...) i zmień na tasks.worker.js"
    } else {
        $fixed | Out-File $workerPoolPath -Encoding UTF8
        Log "OK" "Naprawiono ścieżkę w worker-pool.ts"
    }
} else {
    Log "WARN" "worker-pool.ts nie znaleziony — tworzę nowy"
}

# ─── KROK 4: Zapisz poprawny worker-pool.ts ───────────────
Write-Host "[ 4/4 ] Zapisuję poprawny worker-pool.ts..." -ForegroundColor Yellow

$workerPoolTs = @'
// ============================================================
// GRAŻYNA 5.0 — worker-pool.ts
// WAŻNE: Worker ładuje .js (nie .ts) — tsx nie działa w workerach
// ============================================================
import { Worker } from 'worker_threads';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

// ── ŚCIEŻKA DO WORKERA (.js — nie .ts!) ──────────────────
// W dev (tsx): __dirname = src/ → src/workers/tasks.worker.js
// W prod (tsc): __dirname = dist/ → dist/workers/tasks.worker.js
const WORKER_SCRIPT = path.join(__dirname, 'workers', 'tasks.worker.js');

interface PendingTask {
  resolve: (v: any) => void;
  reject:  (e: Error) => void;
  timeout: ReturnType<typeof setTimeout>;
}

interface PoolWorker {
  worker:    Worker;
  busy:      boolean;
  taskCount: number;
}

export class WorkerPool {
  private workers:  PoolWorker[] = [];
  private pending:  Map<string, PendingTask> = new Map();
  private queue:    Array<{ id: string; type: string; data: any }> = [];
  private counter = 0;
  private readonly size: number;

  constructor(size = 2) {
    this.size = size;
    for (let i = 0; i < size; i++) this.spawnWorker();
    console.log(`[WorkerPool] started ${size} workers → ${WORKER_SCRIPT}`);
  }

  private spawnWorker(): void {
    const pw: PoolWorker = {
      worker:    new Worker(WORKER_SCRIPT),
      busy:      false,
      taskCount: 0,
    };

    pw.worker.on('message', (msg: { id: string; data?: any; error?: string }) => {
      if (msg.id === '__ready__') return; // worker gotowy

      const task = this.pending.get(msg.id);
      if (!task) return;

      clearTimeout(task.timeout);
      this.pending.delete(msg.id);
      pw.busy = false;
      pw.taskCount++;

      if (msg.error) task.reject(new Error(msg.error));
      else           task.resolve(msg.data);

      this.drainQueue(pw);
    });

    pw.worker.on('error', (err) => {
      console.error(`[WorkerPool] worker error: ${err.message}`);
      this.replaceWorker(pw);
    });

    pw.worker.on('exit', (code) => {
      if (code !== 0) {
        console.warn(`[WorkerPool] worker exited ${code} — restarting`);
        this.replaceWorker(pw);
      }
    });

    this.workers.push(pw);
  }

  private replaceWorker(old: PoolWorker): void {
    const idx = this.workers.indexOf(old);
    if (idx !== -1) this.workers.splice(idx, 1);
    old.worker.terminate().catch(() => {});
    this.spawnWorker();
  }

  private drainQueue(pw: PoolWorker): void {
    if (this.queue.length === 0 || pw.busy) return;
    const task = this.queue.shift()!;
    this.dispatch(pw, task.id, task.type, task.data);
  }

  private dispatch(pw: PoolWorker, id: string, type: string, data: any): void {
    pw.busy = true;
    pw.worker.postMessage({ id, type, data });
  }

  run<T = any>(type: string, data: any, timeoutMs = 30_000): Promise<T> {
    return new Promise((resolve, reject) => {
      const id = `${type}-${++this.counter}-${Date.now()}`;

      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`WorkerPool timeout: ${type} after ${timeoutMs}ms`));
      }, timeoutMs);

      this.pending.set(id, { resolve, reject, timeout });

      const free = this.workers.find(w => !w.busy);
      if (free) {
        this.dispatch(free, id, type, data);
      } else {
        this.queue.push({ id, type, data });
      }
    });
  }

  stats() {
    return {
      workers:    this.workers.length,
      busy:       this.workers.filter(w => w.busy).length,
      queued:     this.queue.length,
      pending:    this.pending.size,
      totalTasks: this.workers.reduce((s, w) => s + w.taskCount, 0),
      script:     WORKER_SCRIPT,
    };
  }

  async shutdown(): Promise<void> {
    await Promise.all(this.workers.map(w => w.worker.terminate()));
    this.workers = [];
    console.log('[WorkerPool] shutdown');
  }
}

// ── SINGLETON ─────────────────────────────────────────────
let _pool: WorkerPool | null = null;
export function getWorkerPool(): WorkerPool {
  if (!_pool) _pool = new WorkerPool(2);
  return _pool;
}

// ── HELPER FUNCTIONS ──────────────────────────────────────
export const hashPassword    = (pw: string, rounds = 12) =>
  getWorkerPool().run<string>('bcrypt:hash',    { password: pw, rounds });

export const comparePassword = (pw: string, hash: string) =>
  getWorkerPool().run<boolean>('bcrypt:compare', { password: pw, hash });

export const fleetReport     = (vehicles: any[], period: string) =>
  getWorkerPool().run('report:fleet', { vehicles, period });

export const aggregateGPS    = (points: any[], intervalMinutes = 5) =>
  getWorkerPool().run('gps:aggregate', { points, intervalMinutes });

export const analyzeMetrics  = (metrics: number[]) =>
  getWorkerPool().run('stats:analyze', { metrics });

export const pingWorker      = () =>
  getWorkerPool().run('ping', {});
'@

$workerPoolTs | Out-File "$src\worker-pool.ts" -Encoding UTF8
Log "OK" "Zapisano: src\worker-pool.ts (wskazuje na .js)"

# ─── PODSUMOWANIE ─────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║    ✅ FIX ZAKOŃCZONY — restart backendu              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Pliki naprawione:" -ForegroundColor Cyan
Write-Host "  • src\workers\tasks.worker.js  (CommonJS, nie .ts)" -ForegroundColor White
Write-Host "  • src\worker-pool.ts           (wskazuje na .js)" -ForegroundColor White
Write-Host ""
Write-Host "  Uruchom backend:" -ForegroundColor Cyan
Write-Host "  npm run dev" -ForegroundColor White
Write-Host ""
Write-Host "  Oczekiwany output:" -ForegroundColor Cyan
Write-Host "  [WorkerPool] started 2 workers → .../tasks.worker.js" -ForegroundColor Gray
Write-Host "  ⚡ EXPRESS READY : http://localhost:3001" -ForegroundColor Gray
Write-Host ""
Write-Host "  Test workera:" -ForegroundColor Cyan
Write-Host "  curl http://localhost:3001/api/system/workers" -ForegroundColor White
Write-Host ""