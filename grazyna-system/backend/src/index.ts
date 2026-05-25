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

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minut
  max: 100, // 100 requestów na okno
  message: 'Zbyt wiele żądań, spróbuj ponownie później',
});
app.use('/api/', limiter);

// Request logging (development)
if (process.env.NODE_ENV !== 'production') {
  app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
    next();
  });
}

// ════════════════════════════════════════════
// Routes
// ════════════════════════════════════════════
app.use('/api', apiRoutes);

// Root
app.get('/', (req, res) => {
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

      vehicles.forEach((vehicle) => {
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

app.use((err: any, req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('❌ Error:', err.stack);
  res.status(err.status || 500).json({
    error: process.env.NODE_ENV === 'production' ? 'Błąd serwera' : err.message
  });
});

// ════════════════════════════════════════════
// Server startup
// ════════════════════════════════════════════
const PORT = process.env.PORT || 3001;

httpServer.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🦞  GRAŻYNA 5.0 Backend Server                             ║
║                                                               ║
║   Status:       RUNNING ✓                                     ║
║   Port:         ${PORT}                                            ║
║   Environment:  ${(process.env.NODE_ENV || 'development').padEnd(11)}                                  ║
║   Database:     ${(process.env.DATABASE_URL ? 'Connected' : 'Not configured').padEnd(15)}                              ║
║   WebSocket:    ENABLED                                       ║
║   Rate Limit:   100 req/15min                                 ║
║                                                               ║
║   API:          http://localhost:${PORT}/api                       ║
║   Health:       http://localhost:${PORT}/api/health                ║
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
