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
// W dev (tsx): __dirname = src/ → src/workers/tasks.worker.cjs
// W prod (tsc): __dirname = dist/ → dist/workers/tasks.worker.cjs
const WORKER_SCRIPT = path.join(__dirname, 'workers', 'tasks.worker.cjs');

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


