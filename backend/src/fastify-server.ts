import Fastify from "fastify";
import fastifyHelmet from "@fastify/helmet";
import fastifyCors from "@fastify/cors";
import fastifyRateLimit from "@fastify/rate-limit";
import fastifyCompress from "@fastify/compress";
import fastifySocketIO from "fastify-socket.io";
import v8 from "node:v8";
import { register } from "./metrics.js";
import { getWorkerPool } from "./worker-pool.js";
import { attachSocketBridge, publishSocketEvent } from "./redis-broadcast.js";

export async function startFastifyServer(port = Number(process.env.PORT || 3001)) {
  const fastify = Fastify({
    logger: true,
    bodyLimit: 1048576,
    keepAliveTimeout: 65000,
    connectionTimeout: 10000,
    requestTimeout: 30000,
    ignoreTrailingSlash: true
  });

  await fastify.register(fastifyHelmet, { contentSecurityPolicy: false });
  await fastify.register(fastifyCors, {
    origin: ["http://localhost:5173", "http://localhost:5174"],
    credentials: true
  });
  await fastify.register(fastifyCompress);
  await fastify.register(fastifyRateLimit, { max: 100, timeWindow: "15 minutes" });
  await fastify.register(fastifySocketIO, {
    cors: {
      origin: ["http://localhost:5173", "http://localhost:5174"],
      credentials: true
    },
    transports: ["websocket", "polling"],
    maxHttpBufferSize: 100000
  });

  const pool = getWorkerPool();

  fastify.get("/health", async () => ({
    status: "ok",
    service: "fastify",
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  }));

  fastify.post("/api/system/gc", async () => {
    if (typeof (global as any).gc === "function") {
      (global as any).gc();
      return { status: "gc-invoked" };
    }
    return { status: "gc-unavailable" };
  });

  fastify.get("/metrics", async (_request, reply) => {
    reply.type(register.contentType);
    return register.metrics();
  });

  fastify.get("/api", async () => ({
    status: "API READY",
    mode: "fastify"
  }));

  fastify.get("/api/system/heap", async () => {
    const mem = process.memoryUsage();
    return {
      heap: {
        used_mb: +(mem.heapUsed / 1024 / 1024).toFixed(2),
        total_mb: +(mem.heapTotal / 1024 / 1024).toFixed(2),
        pct: +((mem.heapUsed / mem.heapTotal) * 100).toFixed(1)
      },
      spaces: v8.getHeapSpaceStatistics().map((s) => ({
        name: s.space_name,
        used_kb: Math.round(s.space_used_size / 1024),
        total_kb: Math.round(s.space_size / 1024)
      }))
    };
  });

  fastify.get("/api/system/workers", async () => ({
    status: "ok",
    clusterWorkers: Number(process.env.CLUSTER_WORKERS || 1),
    workerPool: pool.getStats()
  }));

  fastify.get("/api/routes-placeholder", async () => ({
    note: "Jeśli routes/index.js jest Expressem, przenieś route’y do natywnego Fastify albo użyj @fastify/express bridge"
  }));

  await fastify.ready();
  await attachSocketBridge(fastify.io);

  fastify.io.on("connection", (socket) => {
    socket.emit("system:status", {
      uptime: Math.floor(process.uptime()),
      memory: process.memoryUsage(),
      timestamp: new Date().toISOString()
    });

    socket.on("subscribe:vehicle", (vehicleId) => {
      socket.join(`vehicle:${vehicleId}`);
    });

    socket.on("subscribe:alerts", () => {
      socket.join("alerts");
    });

    socket.on("ping", () => {
      socket.emit("pong", { ts: Date.now() });
    });
  });

  setInterval(async () => {
    await publishSocketEvent("system:status", {
      uptime: Math.floor(process.uptime()),
      memory: process.memoryUsage(),
      timestamp: new Date().toISOString()
    });
  }, 5000);

  await fastify.listen({ port, host: "0.0.0.0" });
  console.log(`⚡ FASTIFY READY : http://localhost:${port}`);
  return fastify;
}
