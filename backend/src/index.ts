/**
 * GRAŻYNA 5.0 - Backend Server
 * Express + Socket.IO + Prisma + JWT
 */

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { createServer } from 'http';
import { Server } from 'socket.io';
import dotenv from 'dotenv';
import jwt from 'jsonwebtoken';

import apiRoutes from './routes/index.js';
import { prisma } from './config/database.js';
import { register, httpRequests, httpRequestDuration, httpErrors, workerGauge } from './metrics.js';

dotenv.config();

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: process.env.CORS_ORIGIN || 'http://localhost:5173',
    credentials: true
  }
});

const JWT_SECRET = process.env.JWT_SECRET || 'default-secret-change-me';

// ════════════════════════════════════════════
// Middleware
// ════════════════════════════════════════════
app.use(helmet({
  contentSecurityPolicy: false, // disabled for dev
  crossOriginEmbedderPolicy: false,
}));
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:5173',
  credentials: true
}));
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Metrics: request duration + count + errors (per-endpoint)
app.use((req, res, next) => {
  // Prefer router path if available (keeps param placeholders), else fallback to full path
  const route = (req.baseUrl || '') + (((req as any).route && (req as any).route.path) ? (req as any).route.path : req.path);
  const endTimer = httpRequestDuration.startTimer();
  res.on('finish', () => {
    try {
      const labels = { method: req.method, route, status: String(res.statusCode) };
      httpRequests.inc(labels);
      endTimer(labels);
      if (res.statusCode >= 500) {
        httpErrors.inc(labels);
      }
    } catch (e) { /* ignore */ }
  });
  next();
});

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minut
  max: 100, // 100 requestów na okno
  message: 'Zbyt wiele żądań, spróbuj ponownie później',
});
app.use('/api/', limiter);

// Request logging (development)
if (process.env.NODE_ENV !== 'production') {
  app.use((req, _res, next) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
    next();
  });
}

// ════════════════════════════════════════════
// Metrics (Prometheus)
// ════════════════════════════════════════════
app.get('/metrics', async (_req, res) => {
  try {
    res.setHeader('Content-Type', register.contentType);
    let metricsText = await register.metrics();

    // If advanced metrics are missing, append safe zero-value exposition so they exist for scraping
    const ensureMetric = (name: string, exposition: string) => {
      if (!metricsText.includes(name)) {
        metricsText += '\n' + exposition + '\n';
      }
    };

    // Build simple exposition for histogram + buckets
    const histogramExposition = `# HELP http_request_duration_seconds Duration of HTTP requests in seconds\n# TYPE http_request_duration_seconds histogram\nhttp_request_duration_seconds_sum{method="_init",route="/_init",status="0"} 0\nhttp_request_duration_seconds_count{method="_init",route="/_init",status="0"} 0`;
    const errorsExposition = `# HELP http_errors_total Total HTTP errors (status>=500)\n# TYPE http_errors_total counter\nhttp_errors_total{method="_init",route="/_init",status="0"} 0`;
    const workerExposition = `# HELP worker_processes Number of worker processes\n# TYPE worker_processes gauge\nworker_processes 1`;

    ensureMetric('http_request_duration_seconds', histogramExposition);
    ensureMetric('http_errors_total', errorsExposition);
    ensureMetric('worker_processes', workerExposition);

    res.end(metricsText);
  } catch (err) {
    res.status(500).send('Failed to collect metrics');
  }
});

// ════════════════════════════════════════════
// Routes
// ════════════════════════════════════════════
app.use('/api', apiRoutes);

// Root
app.get('/', (_req, res) => {
  res.json({
    name: 'GRAŻYNA 5.0 API',
    version: '5.0.0',
    status: 'running',
    docs: '/api/docs',
    health: '/api/health'
  });
});

// ════════════════════════════════════════════
// WebSocket - Real-time updates
// ════════════════════════════════════════════
io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth.token;
    if (!token) {
      return next(new Error('Brak tokenu autoryzacji'));
    }

    const decoded = jwt.verify(token, JWT_SECRET) as { userId: string };
    const user = await prisma.user.findUnique({ where: { id: decoded.userId } });
    
    if (!user || !user.active) {
      return next(new Error('Nieprawidłowy użytkownik'));
    }

    (socket as any).userId = user.id;
    (socket as any).userRole = user.role;
    next();
  } catch (error) {
    next(new Error('Nieprawidłowy token'));
  }
});

io.on('connection', (socket) => {
  const userId = (socket as any).userId;
  console.log(`🔌 Client connected: ${socket.id} (user: ${userId})`);

  socket.emit('welcome', {
    message: 'Connected to GRAŻYNA 5.0',
    timestamp: new Date().toISOString()
  });

  // Symulacja real-time telemetrii
  const interval = setInterval(async () => {
    try {
      const vehicles = await prisma.vehicle.findMany({
        where: { status: 'ACTIVE' },
        take: 5
      });

      vehicles.forEach((vehicle: any) => {
        socket.emit('vehicle-update', {
          vehicleId: vehicle.id,
          name: vehicle.name,
          battery: vehicle.battery,
          latitude: vehicle.latitude,
          longitude: vehicle.longitude,
          speed: Math.random() * vehicle.maxSpeed,
          timestamp: new Date().toISOString()
        });
      });
    } catch (error) {
      console.error('WebSocket error:', error);
    }
  }, 5000);

  // Subskrypcja na konkretny pojazd
  socket.on('subscribe-vehicle', (vehicleId: string) => {
    socket.join(`vehicle:${vehicleId}`);
    console.log(`Socket ${socket.id} subscribed to vehicle ${vehicleId}`);
  });

  socket.on('unsubscribe-vehicle', (vehicleId: string) => {
    socket.leave(`vehicle:${vehicleId}`);
  });

  socket.on('disconnect', () => {
    console.log(`🔌 Client disconnected: ${socket.id}`);
    clearInterval(interval);
  });
});

// ════════════════════════════════════════════
// Error handling
// ════════════════════════════════════════════
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint nie znaleziony', path: req.path });
});

app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('❌ Error:', err.stack);
  res.status(err.status || 500).json({
    error: process.env.NODE_ENV === 'production' ? 'Błąd serwera' : err.message
  });
});

// ════════════════════════════════════════════
// Server startup
// ════════════════════════════════════════════
const PORT = process.env.PORT || 3001;

workerGauge.set(Number(process.env.WORKER_COUNT || 1));

try {
  // Introspect registered metrics safely
  const rawMetrics = (register as any).getMetricsAsJSON
    ? (register as any).getMetricsAsJSON()
    : [];

  const metricNames = Array.isArray(rawMetrics)
    ? rawMetrics.map((m: any) => m?.name).filter(Boolean)
    : [];

  console.log('Registered metrics at startup:', metricNames);
} catch (e) {
  console.warn('Metrics introspect failed:', e);
}

// Defensive: if advanced metrics missing, register them at runtime using prom-client directly
try {
  const clientLib = await import('prom-client');
  const reg = clientLib.register;
  function makeIfMissing(name: string, creator: () => any) {
    try {
      const existing = (reg as any).getSingleMetric ? (reg as any).getSingleMetric(name) : null;
      if (!existing) {
        const m = creator();
        // register if creator didn't already
        if ((reg as any).registerMetric && m && !((reg as any).getSingleMetric && (reg as any).getSingleMetric(name))) {
          (reg as any).registerMetric(m);
        }
      }
    } catch (e) {
      // ignore
    }
  }

  makeIfMissing('http_requests_total', () => new clientLib.Counter({ name: 'http_requests_total', help: 'Total HTTP Requests', labelNames: ['method','route','status'], registers: [reg] }));
  makeIfMissing('http_request_duration_seconds', () => new clientLib.Histogram({ name: 'http_request_duration_seconds', help: 'Duration of HTTP requests in seconds', labelNames: ['method','route','status'], buckets: [0.005,0.01,0.025,0.05,0.1,0.3,0.5,1,2,5], registers: [reg] }));
  makeIfMissing('http_errors_total', () => new clientLib.Counter({ name: 'http_errors_total', help: 'Total HTTP errors (status>=500)', labelNames: ['method','route','status'], registers: [reg] }));
  makeIfMissing('worker_processes', () => new clientLib.Gauge({ name: 'worker_processes', help: 'Number of worker processes', registers: [reg] }));

  // Zero-init common labels
  try { (reg as any).getSingleMetric('http_requests_total')?.inc?.({method:'_init',route:'/_init',status:'0'},0); } catch(e){}
  try { (reg as any).getSingleMetric('http_request_duration_seconds')?.observe?.({method:'_init',route:'/_init',status:'0'},0); } catch(e){}
  try { (reg as any).getSingleMetric('http_errors_total')?.inc?.({method:'_init',route:'/_init',status:'0'},0); } catch(e){}
  try { (reg as any).getSingleMetric('worker_processes')?.set?.(Number(process.env.WORKER_COUNT||1)); } catch(e){}
} catch(e) {
  console.warn('Runtime metric bootstrap failed:', e);
}

httpServer.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🦞  GRAŻYNA 5.0 Backend Server                              ║
║                                                               ║
║   Status:       RUNNING ✓                                     ║
║   Port:         ${PORT}                                       ║
║   Environment:  ${(process.env.NODE_ENV || 'development').padEnd(11)}          ║
║   Database:     ${(process.env.DATABASE_URL ? 'Configured' : 'Not configured').padEnd(15)}    ║
║   WebSocket:    ENABLED                                       ║
║   Rate Limit:   100 req/15min                                 ║
║                                                               ║
║   API:          http://localhost:${PORT}/api                  ║
║   Health:       http://localhost:${PORT}/api/health           ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
  `);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down...');
  await prisma.$disconnect();
  httpServer.close(() => process.exit(0));
});

export { app, io };
