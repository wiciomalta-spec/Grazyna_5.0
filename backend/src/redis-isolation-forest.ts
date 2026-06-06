// ============================================================
// GRAŻYNA 5.0 — ISOLATION FOREST + REDIS
// Distributed anomaly detection dla klastra workerów
// Każdy worker wysyła metryki do Redis → Primary agreguje
// i uruchamia Isolation Forest na danych ze wszystkich workerów
// ============================================================

import { createClient, RedisClientType } from 'redis';
import type { Request, Response } from 'express';

// ─────────────────────────────────────────────────────────
// 1. REDIS KEYS SCHEMA
// ─────────────────────────────────────────────────────────
export const KEYS = {
  // Metryki per worker (TTL: 30s)
  workerMetrics: (workerId: number) => `grazyna:worker:${workerId}:metrics`,
  // Historia metryk klastra (lista, max 100 wpisów)
  clusterHistory: 'grazyna:cluster:history',
  // Wyniki Isolation Forest
  isoForestResult: 'grazyna:isoforest:result',
  // Alerty
  alerts: 'grazyna:alerts',
  // Licznik requestów per worker (okno 60s)
  reqCount: (workerId: number) => `grazyna:worker:${workerId}:requests`,
  // Pub/Sub channel dla alertów
  alertChannel: 'grazyna:alerts:channel',
  // Shared state klastra
  clusterState: 'grazyna:cluster:state',
} as const;

// ─────────────────────────────────────────────────────────
// 2. TYPY DANYCH
// ─────────────────────────────────────────────────────────
export interface WorkerMetrics {
  workerId: number;
  pid: number;
  timestamp: number;
  heapPct: number;
  rssMB: number;
  elLagMs: number;
  elMaxMs: number;
  gcMinor: number;
  gcMajor: number;
  reqPerSec: number;
  workersBusy: number;
}

export interface IsolationForestResult {
  timestamp: number;
  anomalies: number[]; // worker IDs z anomaliami
  scores: Record<number, number>; // score per worker
  clusterScore: number; // agregowany score klastra
  isAnomaly: boolean;
  details: string;
}

// Pozwala nadpisać metryki, jeśli chcesz podpiąć realne perf_hooks/GC itp.
export interface WorkerMetricsOverrides {
  elLagMs?: number;
  elMaxMs?: number;
  gcMinor?: number;
  gcMajor?: number;
  workersBusy?: number;
}

// ─────────────────────────────────────────────────────────
// 3. REDIS CLIENT (singleton) + osobny subscriber
// ─────────────────────────────────────────────────────────
let redisClient: RedisClientType | null = null;

export async function getRedisClient(): Promise<RedisClientType | null> {
  if (redisClient?.isReady) return redisClient;

  try {
    redisClient = createClient({
      url: process.env.REDIS_URL || 'redis://127.0.0.1:6379',
      socket: {
        connectTimeout: 3000,
        reconnectStrategy: (retries) => Math.min(retries * 100, 3000),
      },
    }) as RedisClientType;

    redisClient.on('error', (err) => {
      if (!err.message.includes('ECONNREFUSED')) {
        console.error('[Redis] Error:', err.message);
      }
    });

    await redisClient.connect();
    console.log('[Redis] Connected for Isolation Forest');
    return redisClient;
  } catch {
    console.warn('[Redis] Unavailable — Isolation Forest in local mode');
    redisClient = null;
    return null;
  }
}

export async function getRedisSubscriber(): Promise<RedisClientType | null> {
  const client = await getRedisClient();
  if (!client) return null;

  const sub = client.duplicate() as RedisClientType;

  sub.on('error', (err) => {
    if (!err.message.includes('ECONNREFUSED')) {
      console.error('[Redis:SUB] Error:', err.message);
    }
  });

  await sub.connect();
  return sub;
}

// ─────────────────────────────────────────────────────────
// 4. HTTP REQUEST COUNTER — wywołuj z middleware HTTP
//    np. na każdym request:
//    incrementWorkerRequestCounter(cluster.worker?.id || 0)
// ─────────────────────────────────────────────────────────
export async function incrementWorkerRequestCounter(workerId: number): Promise<void> {
  const redis = await getRedisClient();
  if (!redis) return;

  try {
    await redis.incr(KEYS.reqCount(workerId));
    await redis.expire(KEYS.reqCount(workerId), 60);
  } catch {
    // cicho ignoruj błędy Redis
  }
}

// ─────────────────────────────────────────────────────────
// 5. WORKER — wysyła metryki do Redis co 5s
//    reqPerSec liczone z licznika requestów z ostatnich 60s
// ─────────────────────────────────────────────────────────
export async function publishWorkerMetrics(
  workerId: number,
  overrides: WorkerMetricsOverrides = {}
): Promise<void> {
  const redis = await getRedisClient();
  if (!redis) return;

  const mem = process.memoryUsage();

  let reqPerSec = 0;
  try {
    const reqCountRaw = await redis.get(KEYS.reqCount(workerId));
    const reqCount = Number(reqCountRaw || 0);
    // Średnia z ostatnich 60s
    reqPerSec = Math.round((reqCount / 60) * 10) / 10;
  } catch {
    reqPerSec = 0;
  }

  const metrics: WorkerMetrics = {
    workerId,
    pid: process.pid,
    timestamp: Date.now(),
    heapPct: Math.round((mem.heapUsed / Math.max(mem.heapTotal, 1)) * 1000) / 10,
    rssMB: Math.round((mem.rss / 1024 / 1024) * 10) / 10,
    elLagMs: overrides.elLagMs ?? 0,
    elMaxMs: overrides.elMaxMs ?? 0,
    gcMinor: overrides.gcMinor ?? 0,
    gcMajor: overrides.gcMajor ?? 0,
    reqPerSec,
    workersBusy: overrides.workersBusy ?? 0,
  };

  try {
    // Zapisz metryki workera z TTL 30s
    await redis.setEx(KEYS.workerMetrics(workerId), 30, JSON.stringify(metrics));

    // Dodaj do historii klastra (max 100 wpisów)
    await redis.lPush(KEYS.clusterHistory, JSON.stringify(metrics));
    await redis.lTrim(KEYS.clusterHistory, 0, 99);
  } catch {
    // cicho ignoruj błędy Redis
  }
}

// ─────────────────────────────────────────────────────────
// 6. ISOLATION TREE
// ─────────────────────────────────────────────────────────
class IsolationTree {
  private splitFeature = 0;
  private splitValue = 0;
  private left: IsolationTree | null = null;
  private right: IsolationTree | null = null;
  private size = 0;
  private isLeaf = false;

  fit(data: number[][], depth: number, maxDepth: number): void {
    this.size = data.length;

    if (data.length <= 1 || depth >= maxDepth) {
      this.isLeaf = true;
      return;
    }

    const numFeatures = data[0]?.length ?? 0;
    if (numFeatures === 0) {
      this.isLeaf = true;
      return;
    }

    this.splitFeature = Math.floor(Math.random() * numFeatures);

    const vals = data.map((d) => d[this.splitFeature]);
    const min = Math.min(...vals);
    const max = Math.max(...vals);

    if (min === max) {
      this.isLeaf = true;
      return;
    }

    this.splitValue = min + Math.random() * (max - min);

    const leftData = data.filter((d) => d[this.splitFeature] < this.splitValue);
    const rightData = data.filter((d) => d[this.splitFeature] >= this.splitValue);

    if (leftData.length === 0 || rightData.length === 0) {
      this.isLeaf = true;
      return;
    }

    this.left = new IsolationTree();
    this.right = new IsolationTree();
    this.left.fit(leftData, depth + 1, maxDepth);
    this.right.fit(rightData, depth + 1, maxDepth);
  }

  pathLength(point: number[], depth = 0): number {
    if (this.isLeaf || !this.left || !this.right) {
      return depth + this.averagePathLength(this.size);
    }

    if (point[this.splitFeature] < this.splitValue) {
      return this.left.pathLength(point, depth + 1);
    }

    return this.right.pathLength(point, depth + 1);
  }

  private averagePathLength(n: number): number {
    if (n <= 1) return 0;
    if (n === 2) return 1;
    return 2 * (Math.log(n - 1) + 0.5772156649) - (2 * (n - 1)) / n;
  }
}

// ─────────────────────────────────────────────────────────
// 7. ISOLATION FOREST
// ─────────────────────────────────────────────────────────
export class IsolationForest {
  private trees: IsolationTree[] = [];
  private readonly numTrees: number;
  private readonly sampleSize: number;
  private readonly maxDepth: number;
  private trained = false;
  private effectiveSampleSize = 2;

  constructor(numTrees = 100, sampleSize = 256) {
    this.numTrees = numTrees;
    this.sampleSize = sampleSize;
    this.maxDepth = Math.ceil(Math.log2(sampleSize));
  }

  fit(data: number[][]): void {
    if (data.length < 5) return;

    this.trees = [];
    this.effectiveSampleSize = Math.max(2, Math.min(this.sampleSize, data.length));

    for (let t = 0; t < this.numTrees; t++) {
      const sample = this.randomSample(data, this.effectiveSampleSize);
      const tree = new IsolationTree();
      tree.fit(sample, 0, this.maxDepth);
      this.trees.push(tree);
    }

    this.trained = this.trees.length > 0;
  }

  private randomSample(data: number[][], size: number): number[][] {
    const shuffled = [...data].sort(() => Math.random() - 0.5);
    return shuffled.slice(0, size);
  }

  private averagePathLength(n: number): number {
    if (n <= 1) return 0;
    if (n === 2) return 1;
    return 2 * (Math.log(n - 1) + 0.5772156649) - (2 * (n - 1)) / n;
  }

  anomalyScore(point: number[]): number {
    if (!this.trained || this.trees.length === 0) return 0;

    const avgPath =
      this.trees.reduce((sum, tree) => sum + tree.pathLength(point), 0) / this.trees.length;

    const c = this.averagePathLength(this.effectiveSampleSize || 2);
    if (c <= 0) return 0;

    return Math.pow(2, -avgPath / c);
  }

  isAnomaly(point: number[], threshold = 0.65): boolean {
    return this.anomalyScore(point) > threshold;
  }
}

// ─────────────────────────────────────────────────────────
// 8. DISTRIBUTED ISOLATION FOREST — PRIMARY PROCESS
// ─────────────────────────────────────────────────────────
export class DistributedIsolationForest {
  private forest: IsolationForest;
  private redis: RedisClientType | null = null;
  private publisher: RedisClientType | null = null;
  private history: number[][] = [];
  private readonly MAX_HISTORY = 200;
  private analyzeCount = 0;
  private readonly maxWorkers = parseInt(process.env.WORKER_COUNT || '4', 10);

  constructor() {
    this.forest = new IsolationForest(100, 64);
  }

  async init(): Promise<void> {
    this.redis = await getRedisClient();
    this.publisher = this.redis;
  }

  // Normalizacja metryk do wektora cech [0,1]
  private normalize(m: WorkerMetrics): number[] {
    return [
      Math.min(m.heapPct / 100, 1.0),     // heap %
      Math.min(m.elMaxMs / 500, 1.0),     // event loop lag max
      Math.min(m.rssMB / 300, 1.0),       // RSS
      Math.min(m.gcMinor / 50, 1.0),      // GC minor rate
      Math.min(m.gcMajor / 5, 1.0),       // GC major rate
      Math.min(m.reqPerSec / 1000, 1.0),  // req/s
      Math.min(m.workersBusy / Math.max(this.maxWorkers, 1), 1.0), // busy workers
    ];
  }

  async analyzeCluster(): Promise<IsolationForestResult | null> {
    if (!this.redis) return null;

    try {
      const workerMetrics: WorkerMetrics[] = [];

      // Obsługuje zarówno workerId=0 (single/local), jak i cluster workerId=1..N
      for (let i = 0; i <= this.maxWorkers; i++) {
        const raw = await this.redis.get(KEYS.workerMetrics(i));
        if (!raw) continue;

        const m = JSON.parse(raw) as WorkerMetrics;

        // Tylko świeże metryki (< 30s)
        if (Date.now() - m.timestamp < 30000) {
          workerMetrics.push(m);
        }
      }

      if (workerMetrics.length === 0) return null;

      // Normalizacja do wektorów cech
      const featureVectors = workerMetrics.map((m) => this.normalize(m));

      // Historia treningowa
      this.history.push(...featureVectors);
      if (this.history.length > this.MAX_HISTORY) {
        this.history = this.history.slice(-this.MAX_HISTORY);
      }

      // Retraining co 10 analiz po uzbieraniu sensownej historii
      this.analyzeCount++;
      if (this.history.length >= 20 && this.analyzeCount % 10 === 0) {
        this.forest.fit(this.history);
      }

      const scores: Record<number, number> = {};
      const anomalies: number[] = [];

      for (const m of workerMetrics) {
        const vec = this.normalize(m);
        const score = this.forest.anomalyScore(vec);
        const rounded = Math.round(score * 1000) / 1000;
        scores[m.workerId] = rounded;

        if (score > 0.65) {
          anomalies.push(m.workerId);
        }
      }

      const scoreValues = Object.values(scores);
      const clusterScore = scoreValues.length > 0 ? Math.max(...scoreValues) : 0;
      const isAnomaly = clusterScore > 0.65;

      let details = '';
      if (anomalies.length > 0) {
        const anomWorkers = anomalies.map((id) => {
          const m = workerMetrics.find((w) => w.workerId === id);
          if (!m) return `Worker${id}`;
          return `Worker${id}(heap=${m.heapPct}%,el=${m.elMaxMs}ms,rps=${m.reqPerSec})`;
        });
        details = `Anomalie: ${anomWorkers.join(', ')}`;
      } else {
        details = `Klaster normalny (${workerMetrics.length} workerów)`;
      }

      const result: IsolationForestResult = {
        timestamp: Date.now(),
        anomalies,
        scores,
        clusterScore: Math.round(clusterScore * 1000) / 1000,
        isAnomaly,
        details,
      };

      // Zapisz wynik do Redis
      await this.redis.setEx(KEYS.isoForestResult, 60, JSON.stringify(result));

      // Opublikuj alert jeśli anomalia
      if (isAnomaly && this.publisher) {
        const alert = {
          type: 'isolation_forest',
          severity: clusterScore > 0.8 ? 'critical' : 'high',
          message: `Isolation Forest: ${details}`,
          score: Math.round(clusterScore * 1000) / 1000,
          timestamp: new Date().toISOString(),
        };

        await this.publisher.publish(KEYS.alertChannel, JSON.stringify(alert));
        await this.publisher.lPush(KEYS.alerts, JSON.stringify(alert));
        await this.publisher.lTrim(KEYS.alerts, 0, 99);
      }

      return result;
    } catch (err: any) {
      console.error('[IsoForest] Error:', err?.message || err);
      return null;
    }
  }

  // Subskrypcja alertów (frontend/monitoring) — osobny klient Redis!
  async subscribeAlerts(callback: (alert: any) => void): Promise<void> {
    const sub = await getRedisSubscriber();
    if (!sub) return;

    await sub.subscribe(KEYS.alertChannel, (message) => {
      try {
        callback(JSON.parse(message));
      } catch {
        // ignore bad payload
      }
    });
  }
}

// ─────────────────────────────────────────────────────────
// 9. ENDPOINT: GET /api/system/isolation-forest
// ─────────────────────────────────────────────────────────
let distForest: DistributedIsolationForest | null = null;

export async function getIsolationForestHandler(req: Request, res: Response): Promise<void> {
  if (!distForest) {
    distForest = new DistributedIsolationForest();
    await distForest.init();
  }

  const result = await distForest.analyzeCluster();

  if (!result) {
    res.json({
      status: 'no_data',
      message: 'Brak danych z workerów lub Redis niedostępny',
      redis: (await getRedisClient())?.isReady ?? false,
    });
    return;
  }

  res.json({
    status: result.isAnomaly ? 'anomaly' : 'normal',
    clusterScore: result.clusterScore,
    threshold: 0.65,
    anomalies: result.anomalies,
    scores: result.scores,
    details: result.details,
    timestamp: new Date(result.timestamp).toISOString(),
    interpretation: {
      score_0_0_5: 'Normalny',
      score_0_5_0_65: 'Podejrzany',
      score_0_65_0_8: 'Anomalia',
      score_0_8_1_0: 'Krytyczna anomalia',
    },
  });
}

// ─────────────────────────────────────────────────────────
// 10. INTEGRACJA — PRZYKŁADY
// ─────────────────────────────────────────────────────────
/*
  A) W backend/src/routes/index.ts albo innym routerze:

  import { Router } from 'express';
  import { getIsolationForestHandler } from '../redis-isolation-forest';

  const router = Router();

  router.get('/system/isolation-forest', getIsolationForestHandler);

  export default router;


  B) W cluster-bootstrap.ts (primary process):

  import cluster from 'cluster';
  import { DistributedIsolationForest } from './redis-isolation-forest';

  if (cluster.isPrimary) {
    const forest = new DistributedIsolationForest();
    await forest.init();

    setInterval(async () => {
      const result = await forest.analyzeCluster();
      if (result?.isAnomaly) {
        console.warn('[IsoForest] ANOMALIA:', result.details);
      }
    }, 15000);
  }


  C) W każdym workerze — publikacja metryk co 5s:

  import cluster from 'cluster';
  import { publishWorkerMetrics } from './redis-isolation-forest';

  setInterval(() => {
    publishWorkerMetrics(cluster.worker?.id || 0).catch(() => {});
  }, 5000);


  D) W middleware HTTP — licznik requestów per worker:

  import cluster from 'cluster';
  import { incrementWorkerRequestCounter } from './redis-isolation-forest';

  app.use((req, res, next) => {
    incrementWorkerRequestCounter(cluster.worker?.id || 0).catch(() => {});
    next();
  });


  E) Jeśli masz realne metryki event loop / GC, możesz je przekazać tak:

  publishWorkerMetrics(cluster.worker?.id || 0, {
    elLagMs: currentLag,
    elMaxMs: maxLag,
    gcMinor: gcMinorCount,
    gcMajor: gcMajorCount,
    workersBusy: busyWorkers,
  });
*/