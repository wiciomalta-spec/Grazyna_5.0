import cluster from "node:cluster";
import os from "node:os";
import { startFastifyServer } from "./fastify-server";

if (cluster.isPrimary) {
  const cpus = Math.max(1, os.cpus().length - 1);
  for (let i = 0; i < cpus; i++) cluster.fork();
} else {
  // worker: start server and keep process alive
  startFastifyServer().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
