// ============================================================
// GRAŻYNA 5.0 — FIX BACKENDU
// Problem: /health i /api zwracają 404
// Przyczyna: routes nie są zarejestrowane przed catch-all
// 
// INSTRUKCJA: Zastąp zawartość backend/src/index.ts tym plikiem
// LUB dodaj brakujące fragmenty do istniejącego index.ts
// ============================================================

import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import * as promClient from 'prom-client';

const app = express();
const httpServer = createServer(app);

// ─── PROMETHEUS METRICS ────────────────────────────────────
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

// ─── SOCKET.IO ─────────────────────────────────────────────
const io = new SocketIOServer(httpServer, {
  cors: {
    origin: process.env.CORS_ORIGIN || 'http://localhost:5173',
    methods: ['GET', 'POST'],
  },
  transports: ['websocket', 'polling'],
});

// ─── MIDDLEWARE ────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());
app.use(cors({
  origin: [
    process.env.CORS_ORIGIN || 'http://localhost:5173',
    'http://localhost:5174',  // FIX: dodaj port 5174
    'http://localhost:3000',
  ],
  credentials: true,
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('combined'));

// ─── METRICS MIDDLEWARE ────────────────────────────────────
app.use((req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route?.path || req.path;
    httpRequestsTotal.inc({ method: req.method, route, status: String(res.statusCode) });
    httpDuration.observe({ method: req.method, route, status: String(res.statusCode) }, duration);
  });
  next();
});

// ─── FIX: HEALTH ENDPOINT (MUSI BYĆ PRZED ROUTERAMI) ──────
// PROBLEM BYŁ TUTAJ: /health było rejestrowane po catch-all lub w złej kolejności
app.get('/health', (req: Request, res: Response) => {
  const uptime = process.uptime();
  res.status(200).json({
    status: 'ok',
    version: '5.0.0',
    uptime: Math.floor(uptime),
    uptimeHuman: `${Math.floor(uptime/3600)}h ${Math.floor((uptime%3600)/60)}m ${Math.floor(uptime%60)}s`,
    timestamp: new Date().toISOString(),
    memory: {
      rss: Math.round(process.memoryUsage().rss / 1024 / 1024),
      heapUsed: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
      heapTotal: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
    },
    node: process.version,
    env: process.env.NODE_ENV || 'development',
  });
});

// ─── METRICS ENDPOINT ──────────────────────────────────────
app.get('/metrics', async (req: Request, res: Response) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// ─── FIX: API ROUTER ───────────────────────────────────────
// PROBLEM BYŁ TUTAJ: router był importowany ale nie podpięty lub podpięty po catch-all
import router from './routes/index';
app.use('/api', router);

// ─── API ROOT (zwraca listę endpointów) ────────────────────
app.get('/api', (req: Request, res: Response) => {
  res.json({
    name: 'GRAŻYNA 5.0 API',
    version: '5.0.0',
    endpoints: {
      health:   'GET /health',
      metrics:  'GET /metrics',
      auth:     ['POST /api/auth/login', 'POST /api/auth/register'],
      vehicles: ['GET /api/vehicles', 'POST /api/vehicles'],
      drivers:  ['GET /api/drivers', 'POST /api/drivers'],
      alerts:   ['GET /api/alerts', 'POST /api/alerts'],
      reports:  ['GET /api/reports/fleet', 'GET /api/reports/drivers'],
      system:   ['GET /api/system/status', 'GET /api/system/metrics'],
    },
    docs: 'http://localhost:3001/api',
    timestamp: new Date().toISOString(),
  });
});

// ─── WEBSOCKET HANDLERS ────────────────────────────────────
io.on('connection', (socket) => {
  console.log(`[WS] Client connected: ${socket.id}`);

  // Wyślij aktualny status po połączeniu
  socket.emit('system:status', getSystemStatus());

  // Subskrypcja pojazdu
  socket.on('subscribe:vehicle', ({ vehicleId }) => {
    socket.join(`vehicle:${vehicleId}`);
    socket.emit('subscribed', { vehicleId });
  });

  // Subskrypcja alertów
  socket.on('subscribe:alerts', () => {
    socket.join('alerts');
    socket.emit('subscribed', { channel: 'alerts' });
  });

  // Ping/Pong
  socket.on('ping', () => socket.emit('pong', { ts: Date.now() }));

  socket.on('disconnect', () => {
    console.log(`[WS] Client disconnected: ${socket.id}`);
  });
});

// ─── SYSTEM STATUS BROADCAST (co 5s) ──────────────────────
function getSystemStatus() {
  const mem = process.memoryUsage();
  return {
    uptime: Math.floor(process.uptime()),
    memory: {
      rss: Math.round(mem.rss / 1024 / 1024),
      heapUsed: Math.round(mem.heapUsed / 1024 / 1024),
      heapTotal: Math.round(mem.heapTotal / 1024 / 1024),
      heapPct: Math.round((mem.heapUsed / mem.heapTotal) * 100),
    },
    timestamp: new Date().toISOString(),
  };
}

setInterval(() => {
  io.emit('system:status', getSystemStatus());
}, 5000);

// ─── 404 HANDLER (MUSI BYĆ NA KOŃCU!) ─────────────────────
app.use((req: Request, res: Response) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path,
    method: req.method,
    hint: 'Sprawdź dostępne endpointy: GET /api',
  });
});

// ─── ERROR HANDLER ─────────────────────────────────────────
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error('[ERROR]', err.message);
  res.status(500).json({ error: 'Internal Server Error', message: err.message });
});

// ─── START ─────────────────────────────────────────────────
const PORT = parseInt(process.env.PORT || '3001');
httpServer.listen(PORT, () => {
  console.log(`\n⚡ GRAŻYNA 5.0 Backend uruchomiony`);
  console.log(`   http://localhost:${PORT}/health`);
  console.log(`   http://localhost:${PORT}/metrics`);
  console.log(`   http://localhost:${PORT}/api`);
  console.log(`   WebSocket: ws://localhost:${PORT}\n`);
});

export { app, io, httpServer };