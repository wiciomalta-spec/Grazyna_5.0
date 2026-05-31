import cluster from "node:cluster";
import os from "node:os";
import process from "node:process";

const cpuCount = os.cpus().length;
const desiredWorkers = Math.max(
  1,
  Math.min(Number(process.env.CLUSTER_WORKERS || Math.max(1, cpuCount - 1)), cpuCount)
);

if (cluster.isPrimary) {
  console.log(`[cluster] primary ${process.pid} — workers: ${desiredWorkers}`);

  for (let i = 0; i < desiredWorkers; i++) {
    cluster.fork();
  }

  cluster.on("exit", (worker, code, signal) => {
    console.warn(`[cluster] worker ${worker.process.pid} exited code=${code} signal=${signal}; replacing`);
    cluster.fork();
  });

} else {
  process.env.CLUSTER_WORKERS = String(desiredWorkers);

  const useFastify = process.env.USE_FASTIFY === "true";
  if (useFastify) {
    const { startFastifyServer } = await import("./fastify-server.js");
    await startFastifyServer();
  } else {
    const { startExpressServer } = await import("./express-server.js");
    await startExpressServer();
  }
}
