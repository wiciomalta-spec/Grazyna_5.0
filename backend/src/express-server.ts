import express from "express";
import helmet from "helmet";
import cors from "cors";
import compression from "compression";
import { createServer } from "node:http";
import { Server as SocketIOServer } from "socket.io";
import v8 from "node:v8";
import apiRoutes from "./routes/index.js";
import { register } from "./metrics.js";
import { getWorkerPool } from "./worker-pool.js";
import { attachSocketBridge, publishSocketEvent } from "./redis-broadcast.js";

export async function startExpressServer(port = Number(process.env.PORT || 3001)) {
  const app = express();
  const httpServer = createServer(app);
  const io = new SocketIOServer(httpServer, {
    cors: {
      origin: ["http://localhost:5173", "http://localhost:5174"],
      credentials: true
    },
    transports: ["websocket", "polling"],
    maxHttpBufferSize: 100000
  });

  await attachSocketBridge(io);
  const pool = getWorkerPool();

  app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));
  app.use(cors({ origin: ["http://localhost:5173", "http://localhost:5174"], credentials: true }));
  app.use(compression());
  app.use(express.json({ limit: "1mb" }));
  app.use(express.urlencoded({ extended: true, limit: "1mb" }));

  app.get("/health", (_req, res) => {
    res.status(200).json({
      status: "ok",
      service: "express",
      uptime: process.uptime(),
      timestamp: new Date().toISOString()
    });
  });

  app.post("/api/system/gc", (_req, res) => {
    if (typeof (global as any).gc === "function") {
      (global as any).gc();
      return res.status(200).json({ status: "gc-invoked" });
    }
    return res.status(501).json({ status: "gc-unavailable" });
  });

  app.get("/metrics", async (_req, res) => {
    res.setHeader("Content-Type", register.contentType);
    res.end(await register.metrics());
  });

  app.get("/api", (_req, res) => {
    res.status(200).json({ status: "API READY", mode: "express" });
  });

  app.get("/api/system/heap", (_req, res) => {
    const mem = process.memoryUsage();
    res.json({
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
    });
  });

  app.get("/api/system/workers", (_req, res) => {
    res.json({
      status: "ok",
      clusterWorkers: Number(process.env.CLUSTER_WORKERS || 1),
      workerPool: pool.stats()
    });
  });

  app.use("/api", apiRoutes);

  app.use((req, res) => {
    res.status(404).json({ error: "Endpoint not found", path: req.path });
  });

  io.on("connection", (socket) => {
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

  httpServer.on("error", (err: any) => {
    if (err?.code === "EADDRINUSE") {
      console.error(`❌ Port ${port} jest już zajęty.`);
      process.exit(1);
    }
    console.error("❌ Express error:", err);
    process.exit(1);
  });

  await new Promise((resolve) => httpServer.listen(port, resolve));
  console.log(`⚡ EXPRESS READY : http://localhost:${port}`);
  return { app, io, httpServer };
}

