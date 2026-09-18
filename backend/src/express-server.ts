import express from "express";
import http from "node:http";
import { initDatabase, closeDatabase } from "./config/database.js";
import router from "./routes/index.js";

export async function startExpressServer() {
  await initDatabase();

  const app = express();
  app.disable("x-powered-by");
  app.use(express.json({ limit: "1mb" }));

  app.use((req, res, next) => {
    const allowed = (process.env.CORS_ORIGIN || "http://localhost:5173")
      .split(",")
      .map(v => v.trim())
      .filter(Boolean);
    const origin = req.headers.origin;
    if (origin && allowed.includes(origin)) {
      res.setHeader("Access-Control-Allow-Origin", origin);
      res.setHeader("Vary", "Origin");
    }
    res.setHeader("Access-Control-Allow-Credentials", "true");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.setHeader("Access-Control-Allow-Methods", "GET,POST,PATCH,DELETE,OPTIONS");
    if (req.method === "OPTIONS") return res.sendStatus(204);
    next();
  });

  app.get("/", (_req, res) => res.json({ service: "GRAŻYNA 5.0", status: "ok" }));
  app.get("/health", (_req, res) => res.status(200).json({
    status: "ok",
    service: "grazyna-backend",
    version: "5.0.1",
    uptime: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
    node: process.version
  }));

  app.get("/metrics-json", (_req, res) => {
    const m = process.memoryUsage();
    res.json({
      heap_pct: m.heapTotal > 0 ? Math.round(m.heapUsed / m.heapTotal * 100) : 0,
      rss_mb: Math.round(m.rss / 1024 / 1024),
      uptime: Math.floor(process.uptime())
    });
  });

  app.use("/api", router);

  const PORT = Number(process.env.PORT || 3001);
  const server = http.createServer(app);

  const shutdown = async (signal: string) => {
    console.log(`[shutdown] ${signal}`);
    server.close(async () => {
      await closeDatabase();
      process.exit(0);
    });
  };

  process.once("SIGINT", () => void shutdown("SIGINT"));
  process.once("SIGTERM", () => void shutdown("SIGTERM"));

  await new Promise<void>((resolve) => server.listen(PORT, "0.0.0.0", () => resolve()));
  console.log(`EXPRESS READY : http://localhost:${PORT}`);
  return server;
}
