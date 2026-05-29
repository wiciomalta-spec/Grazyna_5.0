import { Router } from 'express';
import { login, register, me } from '../controllers/auth.controller.js';
import {
  getAllVehicles,
  getVehicleById,
  createVehicle,
  updateVehicle,
  deleteVehicle,
  getVehicleStats,
} from '../controllers/vehicle.controller.js';
import { authenticateToken, requireRole } from '../middleware/auth.js';
import { getKernelProfile, getKernelBlueprint, getKernelDrivers, adaptKernel } from '../controllers/kernel.controller.js';

const router = Router();

// ════════════════════════════════════════════
// Health & Status
// ════════════════════════════════════════════
router.get('/health', (_req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '5.0.0',
    uptime: process.uptime()
  });
});

router.get('/status', (_req, res) => {
  res.json({
    system: 'GRAŻYNA 5.0',
    status: 'operational',
    timestamp: new Date().toISOString()
  });
});

// ════════════════════════════════════════════
// Auth routes (publiczne)
// ════════════════════════════════════════════
router.post('/auth/login', login);
router.post('/auth/register', register);
router.get('/auth/me', authenticateToken, me);

// ════════════════════════════════════════════
// Vehicle routes (wymagają autoryzacji)
// ════════════════════════════════════════════
router.get('/vehicles', authenticateToken, getAllVehicles);
router.get('/vehicles/stats/summary', authenticateToken, getVehicleStats);
router.get('/vehicles/:id', authenticateToken, getVehicleById);
router.post('/vehicles', authenticateToken, requireRole('ADMIN', 'MANAGER'), createVehicle);
router.patch('/vehicles/:id', authenticateToken, requireRole('ADMIN', 'MANAGER', 'OPERATOR'), updateVehicle);
router.delete('/vehicles/:id', authenticateToken, requireRole('ADMIN'), deleteVehicle);

// ════════════════════════════════════════════
// Kernel routes
// ════════════════════════════════════════════
router.get('/kernel/profile', getKernelProfile);
router.get('/kernel/blueprint', getKernelBlueprint);
router.get('/kernel/drivers', getKernelDrivers);
router.post('/kernel/adapt', authenticateToken, requireRole('ADMIN', 'MANAGER', 'OPERATOR'), adaptKernel);

export default router;