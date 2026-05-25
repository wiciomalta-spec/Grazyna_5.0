import { Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../config/database.js';

// ════════════════════════════════════════════
// Schemy walidacji
// ════════════════════════════════════════════
const createVehicleSchema = z.object({
  name: z.string().min(1),
  vin: z.string().optional(),
  type: z.enum(['STANDARD', 'HEAVY', 'LIGHT', 'DRONE', 'SPECIAL']).default('STANDARD'),
  maxSpeed: z.number().positive().optional(),
  maxRange: z.number().positive().optional(),
});

const updateVehicleSchema = z.object({
  name: z.string().optional(),
  status: z.enum(['IDLE', 'ACTIVE', 'CHARGING', 'MAINTENANCE', 'OFFLINE', 'ERROR']).optional(),
  battery: z.number().min(0).max(100).optional(),
  speed: z.number().min(0).optional(),
  latitude: z.number().optional(),
  longitude: z.number().optional(),
});

// ════════════════════════════════════════════
// GET /api/vehicles
// ════════════════════════════════════════════
export const getAllVehicles = async (req: Request, res: Response): Promise<void> => {
  try {
    const { status, type } = req.query;
    
    const where: any = {};
    if (status) where.status = status;
    if (type) where.type = type;

    const vehicles = await prisma.vehicle.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        missions: {
          where: { status: { in: ['IN_PROGRESS', 'SCHEDULED'] } },
          select: { id: true, name: true, status: true }
        }
      }
    });

    res.json({ 
      success: true, 
      count: vehicles.length,
      data: vehicles 
    });
  } catch (error) {
    console.error('Get vehicles error:', error);
    res.status(500).json({ error: 'Błąd serwera' });
  }
};

// ════════════════════════════════════════════
// GET /api/vehicles/:id
// ════════════════════════════════════════════
export const getVehicleById = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    
    const vehicle = await prisma.vehicle.findUnique({
      where: { id },
      include: {
        missions: { orderBy: { createdAt: 'desc' }, take: 10 },
        telemetry: { orderBy: { timestamp: 'desc' }, take: 50 },
        events: { orderBy: { createdAt: 'desc' }, take: 20 }
      }
    });

    if (!vehicle) {
      res.status(404).json({ error: 'Pojazd nie znaleziony' });
      return;
    }

    res.json({ success: true, data: vehicle });
  } catch (error) {
    res.status(500).json({ error: 'Błąd serwera' });
  }
};

// ════════════════════════════════════════════
// POST /api/vehicles
// ════════════════════════════════════════════
export const createVehicle = async (req: Request, res: Response): Promise<void> => {
  try {
    const validation = createVehicleSchema.safeParse(req.body);
    if (!validation.success) {
      res.status(400).json({ error: 'Błąd walidacji', details: validation.error.errors });
      return;
    }

    const vehicle = await prisma.vehicle.create({
      data: validation.data
    });

    // Loguj zdarzenie
    await prisma.event.create({
      data: {
        type: 'VEHICLE',
        severity: 'INFO',
        title: `Dodano pojazd: ${vehicle.name}`,
        vehicleId: vehicle.id,
      }
    });

    res.status(201).json({ success: true, data: vehicle });
  } catch (error) {
    res.status(500).json({ error: 'Błąd serwera' });
  }
};

// ════════════════════════════════════════════
// PATCH /api/vehicles/:id
// ════════════════════════════════════════════
export const updateVehicle = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const validation = updateVehicleSchema.safeParse(req.body);
    
    if (!validation.success) {
      res.status(400).json({ error: 'Błąd walidacji', details: validation.error.errors });
      return;
    }

    const vehicle = await prisma.vehicle.update({
      where: { id },
      data: { ...validation.data, lastUpdate: new Date() }
    });

    res.json({ success: true, data: vehicle });
  } catch (error) {
    res.status(500).json({ error: 'Błąd serwera lub pojazd nie znaleziony' });
  }
};

// ════════════════════════════════════════════
// DELETE /api/vehicles/:id
// ════════════════════════════════════════════
export const deleteVehicle = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    
    await prisma.vehicle.delete({ where: { id } });
    
    res.json({ success: true, message: 'Pojazd usunięty' });
  } catch (error) {
    res.status(500).json({ error: 'Błąd serwera lub pojazd nie znaleziony' });
  }
};

// ════════════════════════════════════════════
// GET /api/vehicles/stats/summary
// ════════════════════════════════════════════
export const getVehicleStats = async (req: Request, res: Response): Promise<void> => {
  try {
    const [total, active, charging, maintenance] = await Promise.all([
      prisma.vehicle.count(),
      prisma.vehicle.count({ where: { status: 'ACTIVE' } }),
      prisma.vehicle.count({ where: { status: 'CHARGING' } }),
      prisma.vehicle.count({ where: { status: 'MAINTENANCE' } }),
    ]);

    const avgBattery = await prisma.vehicle.aggregate({
      _avg: { battery: true }
    });

    res.json({
      success: true,
      data: {
        total,
        active,
        charging,
        maintenance,
        avgBattery: Math.round(avgBattery._avg.battery || 0),
        utilization: total > 0 ? Math.round((active / total) * 100) : 0
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Błąd serwera' });
  }
};
