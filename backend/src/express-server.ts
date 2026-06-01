import express from "express";
import http from "http";
import { publishSocketEvent } from "./redis-broadcast";

export async function startExpressServer() {
  const app = express();

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
