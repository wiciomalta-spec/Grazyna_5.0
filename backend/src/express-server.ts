import express from "express";
import http from "http";
import { publishSocketEvent } from "./redis-broadcast";

export async function startExpressServer() {
  const app = express();

// ── HEALTH ENDPOINT ──────────────────────────────────────
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    version: '5.0.0',
    uptime: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
    memory: {
      heapUsed: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
      heapTotal: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
    },
    node: process.version,
  });
});

app.get('/metrics-json', (req, res) => {
  const mem = process.memoryUsage();
  res.json({
    heap_pct: Math.round(mem.heapUsed / mem.heapTotal * 100),
    rss_mb: Math.round(mem.rss / 1024 / 1024),
    uptime: Math.floor(process.uptime()),
  });
});


  app.get("/", (_req, res) => {
    res.send("OK");
  });

  const server = http.createServer(app);

  const PORT = Number(process.env.PORT || 3001);

  server.listen(PORT, () => {
    console.log(`⚡ EXPRESS READY : http://localhost:${PORT}`);
  });

  // ✅ SAFE INTERVAL (NO CRASH)
  setInterval(() => {
    try {
      // 🔥 kluczowa zmiana: NO await
      void publishSocketEvent("heartbeat", {
        ts: Date.now(),
      });
    } catch (err) {
      console.warn("[express] publish skipped", err);
    }
  }, 3000);

  // ✅ Graceful shutdown (PRO)
  process.on("SIGINT", async () => {
    console.log("Shutting down...");
    server.close();
    process.exit(0);
  });

  process.on("SIGTERM", async () => {
    server.close();
    process.exit(0);
  });
}
