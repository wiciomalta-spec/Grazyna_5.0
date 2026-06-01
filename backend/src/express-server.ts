import express from 'express';
import http from 'node:http';
import { publishSocketEvent } from './redis-broadcast.js';

export async function startExpressServer() {
  const app = express();
  app.use(express.json());

  // ── HEALTH ────────────────────────────────────────────────
  app.get('/health', (_req, res) => {
    res.status(200).json({
      status: 'ok', version: '5.0.0',
      uptime: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
      memory: {
        heapUsed:  Math.round(process.memoryUsage().heapUsed  / 1024 / 1024),
        heapTotal: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
      },
      node: process.version,
    });
  });

  // ── METRICS JSON ──────────────────────────────────────────
  app.get('/metrics-json', (_req, res) => {
    const mem = process.memoryUsage();
    res.json({
      heap_pct: Math.round(mem.heapUsed / mem.heapTotal * 100),
      rss_mb:   Math.round(mem.rss / 1024 / 1024),
      uptime:   Math.floor(process.uptime()),
    });
  });

  // ── API ROOT ──────────────────────────────────────────────
  app.get('/api', (_req, res) => {
    res.json({ status: 'API READY', mode: 'express', version: '5.0.0' });
  });

  // ── SYSTEM ENDPOINTS ──────────────────────────────────────
  app.get('/api/system/heap', (_req, res) => {
    const v8 = require('v8');
    const mem = process.memoryUsage();
    const spaces = v8.getHeapSpaceStatistics();
    const los = spaces.find((s: any) => s.space_name === 'large_object_space');
    res.json({
      heap: {
        used_mb:  +(mem.heapUsed  / 1024 / 1024).toFixed(1),
        total_mb: +(mem.heapTotal / 1024 / 1024).toFixed(1),
        pct:      Math.round(mem.heapUsed / mem.heapTotal * 100),
        rss_mb:   +(mem.rss / 1024 / 1024).toFixed(1),
        external_kb: Math.round(mem.external / 1024),
      },
      large_object_space: los ? {
        used_kb:  Math.round(los.space_used_size / 1024),
        total_kb: Math.round(los.space_size / 1024),
        pct:      los.space_size > 0 ? Math.round(los.space_used_size / los.space_size * 100) : 0,
      } : null,
      gc_available: typeof (global as any).gc === 'function',
      node_flags:   process.execArgv,
      timestamp:    new Date().toISOString(),
    });
  });

  app.post('/api/system/gc', (_req, res) => {
    const before = process.memoryUsage().heapUsed;
    if (typeof (global as any).gc === 'function') {
      (global as any).gc();
      const freed = +((before - process.memoryUsage().heapUsed) / 1024 / 1024).toFixed(1);
      res.json({ success: true, freed_mb: freed, message: `GC zwolnil ${freed} MB` });
    } else {
      res.json({ success: false, message: 'Dodaj --expose-gc do node flags' });
    }
  });

  app.get('/api/system/ping', (_req, res) => {
    res.json({ pong: true, ts: Date.now(), uptime: Math.floor(process.uptime()) });
  });

  app.get('/api/system/env', (_req, res) => {
    res.json({
      NODE_ENV: process.env.NODE_ENV || 'development',
      PORT:     process.env.PORT || '3001',
      node:     process.version,
      platform: process.platform,
      pid:      process.pid,
      uptime:   Math.floor(process.uptime()),
    });
  });

  // ── FLEET ENDPOINTS ───────────────────────────────────────
  app.get('/api/vehicles',     (_req, res) => res.json({ vehicles: [], total: 0 }));
  app.get('/api/drivers',      (_req, res) => res.json({ drivers:  [], total: 0 }));
  app.get('/api/alerts',       (_req, res) => res.json({ alerts:   [], total: 0, active: 0 }));
  app.get('/api/reports/fleet',(_req, res) => res.json({ period: {}, summary: { totalVehicles: 0 }, generatedAt: new Date().toISOString() }));
  app.get('/api/ws/status',    (_req, res) => res.json({ websocket: 'available', url: `ws://localhost:${process.env.PORT || 3001}` }));

  // ── ROOT ──────────────────────────────────────────────────
  app.get('/', (_req, res) => res.send('OK'));

  // ── START SERVER ──────────────────────────────────────────
  const server = http.createServer(app);
  const PORT = Number(process.env.PORT || 3001);

  server.listen(PORT, () => {
    console.log(`\u26A1 EXPRESS READY : http://localhost:${PORT}`);
  });

  // Heartbeat
  setInterval(() => {
    try { void publishSocketEvent('heartbeat', { ts: Date.now() }); }
    catch (err) { console.warn('[express] publish skipped', err); }
  }, 3000);

  process.on('SIGINT',  async () => { server.close(); process.exit(0); });
  process.on('SIGTERM', async () => { server.close(); process.exit(0); });
}