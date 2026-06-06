// ============================================================
// GRAŻYNA 5.0 — CLEAN BACKEND (AI + CLUSTER + REDIS + WS)
// ============================================================

import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import * as promClient from 'prom-client';
import cluster from 'node:cluster';
import filemapRouter from "./routes/filemap";
app.use("/api", filemapRouter);

// ✅ AI (Redis + Isolation Forest)
import {
  incrementWorkerRequestCounter,
  DistributedIsolationForest
} from './redis-isolation-forest.js';

// ✅ ROUTER
import router from './routes/index.js';

const app = express();
app.use('/api', filemapRouter);
const httpServer = createServer(app);

// ─────────────────────────────────────────
// PROMETHEUS
// ─────────────────────────────────────────
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP Requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

const httpDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
  registers: [register],
});

// ─────────────────────────────────────────
// SOCKET.IO
// ─────────────────────────────────────────
const io = new SocketIOServer(httpServer, {
  cors: {
    origin: process.env.CORS_ORIGIN || 'http://localhost:5173',
    methods: ['GET', 'POST'],
  },
  transports: ['websocket', 'polling'],
});

// ─────────────────────────────────────────
// MIDDLEWARE
// ─────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());
app.use(cors({
  origin: [
    process.env.CORS_ORIGIN || 'http://localhost:5173',
    'http://localhost:5174',
    'http://localhost:3000',
  ],
  credentials: true,
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('combined'));

// ✅ REQUEST COUNTER (dla AI)
app.use((req: Request, res: Response, next: NextFunction) => {
  incrementWorkerRequestCounter(cluster.worker?.id || 0).catch(() => {});
  next();
});

// ✅ METRICS
app.use((req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route?.path || req.path;

    httpRequestsTotal.inc({
      method: req.method,
      route,
      status: String(res.statusCode)
    });

    httpDuration.observe(
      { method: req.method, route, status: String(res.statusCode) },
      duration
    );
  });

  next();
});

// ─────────────────────────────────────────
// HEALTH
// ─────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    uptime: Math.floor(process.uptime()),
    worker: cluster.worker?.id || 0,
    timestamp: new Date().toISOString(),
  });
});

// ─────────────────────────────────────────
// METRICS ENDPOINT
// ─────────────────────────────────────────
app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// ─────────────────────────────────────────
// API ROUTER
// ─────────────────────────────────────────
app.use('/api', router);

// ─────────────────────────────────────────
// API ROOT
// ─────────────────────────────────────────
app.get('/api', (_req, res) => {
  res.json({
    name: 'GRAŻYNA API',
    version: '5.0.0',
    endpoints: {
      health: '/health',
      metrics: '/metrics',
      ai: '/api/system/isolation-forest'
    }
  });
});

// ─────────────────────────────────────────
// WEBSOCKET
// ─────────────────────────────────────────
io.on('connection', (socket) => {
  console.log('[WS] connected:', socket.id);

  socket.emit('system:status', getSystemStatus());

  socket.on('subscribe:alerts', () => {
    socket.join('alerts');
  });

  socket.on('ping', () => {
    socket.emit('pong', { ts: Date.now() });
  });

  socket.on('disconnect', () => {
    console.log('[WS] disconnected:', socket.id);
  });
});

// ─────────────────────────────────────────
// AI ALERTY (Redis → WS)
// ─────────────────────────────────────────
const forest = new DistributedIsolationForest();

(async () => {
  try {
    await forest.init();

    await forest.subscribeAlerts((alert) => {
      console.log('[ALERT]', alert.message);
      io.to('alerts').emit('system:alert', alert);
    });

  } catch {
    console.warn('[AI] disabled (no Redis)');
  }
})();

// ─────────────────────────────────────────
// SYSTEM STATUS
// ─────────────────────────────────────────
function getSystemStatus() {
  const mem = process.memoryUsage();

  return {
    uptime: Math.floor(process.uptime()),
    memory: {
      rss: Math.round(mem.rss / 1024 / 1024),
      heapUsed: Math.round(mem.heapUsed / 1024 / 1024),
    },
    worker: cluster.worker?.id || 0,
    timestamp: new Date().toISOString(),
  };
}

// broadcast co 5s
setInterval(() => {
  io.emit('system:status', getSystemStatus());
}, 5000);

// ─────────────────────────────────────────
// 404
// ─────────────────────────────────────────
app.use((req: Request, res: Response) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path,
  });
});

// ─────────────────────────────────────────
// ERROR HANDLER
// ─────────────────────────────────────────
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('[ERROR]', err.message);

  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message
  });
});

// ─────────────────────────────────────────
// START
// ─────────────────────────────────────────
const PORT = parseInt(process.env.PORT || '3001');

httpServer.listen(PORT, () => {
  console.log('\n⚡ GRAŻYNA READY');
  console.log(`http://localhost:${PORT}/health`);
  console.log(`http://localhost:${PORT}/api\n`);
});

// EXPORTS
export { app, io, httpServer };import filemapRouter from "../tools/mapa/filemap_api";
app.use("/api", filemapRouter);




