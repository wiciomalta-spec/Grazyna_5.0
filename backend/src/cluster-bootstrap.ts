import cluster from "node:cluster";
import os from "node:os";
import process from "node:process";
import http from "node:http";
import { monitorEventLoopDelay } from "node:perf_hooks";



// ── FIX: Obsługa EADDRINUSE ──────────────────────────────
process.on('uncaughtException', (err: any) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`[cluster] Port ${err.port} zajęty — czekam 3s i restartuję...`);
    setTimeout(() => process.exit(1), 3000);
  } else {
    console.error('[cluster] Uncaught exception:', err.message);
    process.exit(1);
  }
});

process.on('unhandledRejection', (reason: any) => {
  console.error('[cluster] Unhandled rejection:', reason?.message || reason);
});
const cpuCount = os.cpus().length;
const minWorkers = 1;
const maxWorkers = Math.max(
  1,
  Math.min(Number(process.env.MAX_CLUSTER_WORKERS || cpuCount), cpuCount)
);

let currentWorkers = Math.max(
  minWorkers,
  Math.min(
    Number(process.env.CLUSTER_WORKERS || Math.max(1, cpuCount - 1)),
    maxWorkers
  )
);

let lagSignals = 0;
let lowLagSignals = 0;

async function startWorkerRuntime() {
  const useFastify = process.env.USE_FASTIFY === "true";

  if (useFastify) {
    const { startFastifyServer } = await import("./fastify-server.js");


// ── FIX: Obsługa EADDRINUSE ──────────────────────────────
process.on('uncaughtException', (err: any) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`[cluster] Port ${err.port} zajęty — czekam 3s i restartuję...`);
    setTimeout(() => process.exit(1), 3000);
  } else {
    console.error('[cluster] Uncaught exception:', err.message);
    process.exit(1);
  }
});

process.on('unhandledRejection', (reason: any) => {
  console.error('[cluster] Unhandled rejection:', reason?.message || reason);
});
    await startFastifyServer();
  } else {
    const { startExpressServer } = await import("./express-server.js");


// ── FIX: Obsługa EADDRINUSE ──────────────────────────────
process.on('uncaughtException', (err: any) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`[cluster] Port ${err.port} zajęty — czekam 3s i restartuję...`);
    setTimeout(() => process.exit(1), 3000);
  } else {
    console.error('[cluster] Uncaught exception:', err.message);
    process.exit(1);
  }
});

process.on('unhandledRejection', (reason: any) => {
  console.error('[cluster] Unhandled rejection:', reason?.message || reason);
});
    await startExpressServer();
  }
}

async function main() {
  if (cluster.isPrimary) {
    console.log(`[cluster] primary ${process.pid} — starting ${currentWorkers} workers`);

    for (let i = 0; i < currentWorkers; i++) {
      cluster.fork();
    }

    cluster.on("exit", (worker, code, signal) => {
      console.warn(
        `[cluster] worker ${worker.process.pid} exited code=${code} signal=${signal}; replacing`
      );
      if (Object.keys(cluster.workers || {}).length < currentWorkers) {
        cluster.fork();
      }
    });

    cluster.on("message", (_worker, msg: any) => {
      if (msg?.type === "lag") {
        const lag = Number(msg.value || 0);

        if (lag > 0.05) {
          lagSignals++;
          lowLagSignals = 0;
        } else if (lag < 0.015) {
          lowLagSignals++;
          if (lagSignals > 0) lagSignals--;
        }
      }
    });

    setInterval(() => {
      if (lagSignals >= 3 && currentWorkers < maxWorkers) {
        console.log(`[AI SCALE] UP -> ${currentWorkers + 1}`);
        cluster.fork();
        currentWorkers++;
        lagSignals = 0;
        return;
      }

      if (lowLagSignals >= 4 && currentWorkers > minWorkers) {
        const workers = Object.values(cluster.workers || {});
        const victim = workers[workers.length - 1];
        if (victim) {
          console.log(`[AI SCALE] DOWN -> ${currentWorkers - 1}`);
          victim.kill();
          currentWorkers--;
          lowLagSignals = 0;
        }
      }
    }, 10000);

    const controlServer = http.createServer((req, res) => {
      const workers = Object.values(cluster.workers || {});

      if (req.url === "/scale-up") {
        if (currentWorkers < maxWorkers) {
          cluster.fork();
          currentWorkers++;
        }
        res.end("SCALED UP -> " + currentWorkers);
        return;
      }

      if (req.url === "/scale-down") {
        if (workers.length > minWorkers) {
          workers[workers.length - 1]?.kill();
          currentWorkers--;
        }
        res.end("SCALED DOWN -> " + Math.max(minWorkers, currentWorkers));
        return;
      }

      if (req.url === "/status") {
        res.setHeader("Content-Type", "application/json");
        res.end(
          JSON.stringify({
            workers: workers.length,
            currentWorkers,
            minWorkers,
            maxWorkers,
            pid: process.pid
          })
        );
        return;
      }

      res.end("OK");
    });

    controlServer.listen(4001, () => {
      console.log("[cluster-control] http://localhost:4001");
    });

    return;
  }

  process.env.CLUSTER_WORKERS = String(currentWorkers);

  const histogram = monitorEventLoopDelay({ resolution: 20 });
  histogram.enable();

  setInterval(() => {
    const p99 = histogram.percentile(99) / 1e9;
    process.send?.({ type: "lag", value: p99 });
    histogram.reset();
  }, 5000);

  await startWorkerRuntime();
}

main().catch((err) => {
  console.error("[cluster-bootstrap] fatal error:", err);
  process.exit(1);
});