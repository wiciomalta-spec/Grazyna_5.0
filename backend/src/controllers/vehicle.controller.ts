import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../config/database.js";

const createVehicleSchema = z.object({
  name: z.string().min(1),
  licensePlate: z.string().min(1),
  vin: z.string().optional(),
  type: z.enum(["STANDARD", "HEAVY", "LIGHT", "DRONE", "SPECIAL"]).default("STANDARD"),
  battery: z.number().int().min(0).max(100).optional(),
});

const updateVehicleSchema = z.object({
  name: z.string().min(1).optional(),
  licensePlate: z.string().min(1).optional(),
  status: z.enum(["IDLE", "ACTIVE", "CHARGING", "MAINTENANCE", "OFFLINE", "ERROR"]).optional(),
  battery: z.number().int().min(0).max(100).optional(),
  speed: z.number().min(0).optional(),
  lat: z.number().optional(),
  lng: z.number().optional(),
});

export const getAllVehicles = async (req: Request, res: Response): Promise<void> => {
  try {
    const where: Record<string, unknown> = {};
    if (typeof req.query.status === "string") where.status = req.query.status;
    if (typeof req.query.type === "string") where.type = req.query.type;
    const vehicles = await prisma.vehicle.findMany({
      where,
      orderBy: { createdAt: "desc" },
      include: { missions: { where: { status: { in: ["IN_PROGRESS", "SCHEDULED"] } }, select: { id: true, name: true, status: true } } }
    });
    res.json({ success: true, count: vehicles.length, data: vehicles });
  } catch (error) {
    console.error("Get vehicles error:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
};

export const getVehicleById = async (req: Request, res: Response): Promise<void> => {
  try {
    const vehicle = await prisma.vehicle.findUnique({
      where: { id: req.params.id },
      include: {
        missions: { orderBy: { createdAt: "desc" }, take: 10 },
        telemetry: { orderBy: { timestamp: "desc" }, take: 50 },
        events: { orderBy: { createdAt: "desc" }, take: 20 }
      }
    });
    if (!vehicle) { res.status(404).json({ error: "Pojazd nie znaleziony" }); return; }
    res.json({ success: true, data: vehicle });
  } catch (error) {
    console.error("Get vehicle error:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
};

export const createVehicle = async (req: Request, res: Response): Promise<void> => {
  const validation = createVehicleSchema.safeParse(req.body);
  if (!validation.success) { res.status(400).json({ error: "Błąd walidacji", details: validation.error.flatten() }); return; }
  try {
    const vehicle = await prisma.vehicle.create({ data: validation.data });
    await prisma.event.create({
      data: { type: "VEHICLE", severity: "INFO", message: `Dodano pojazd: ${vehicle.name}`, vehicleId: vehicle.id }
    });
    res.status(201).json({ success: true, data: vehicle });
  } catch (error) {
    console.error("Create vehicle error:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
};

export const updateVehicle = async (req: Request, res: Response): Promise<void> => {
  const validation = updateVehicleSchema.safeParse(req.body);
  if (!validation.success) { res.status(400).json({ error: "Błąd walidacji", details: validation.error.flatten() }); return; }
  try {
    const vehicle = await prisma.vehicle.update({ where: { id: req.params.id }, data: validation.data });
    res.json({ success: true, data: vehicle });
  } catch (error) {
    console.error("Update vehicle error:", error);
    res.status(500).json({ error: "Błąd serwera lub pojazd nie znaleziony" });
  }
};

export const deleteVehicle = async (req: Request, res: Response): Promise<void> => {
  try {
    await prisma.vehicle.delete({ where: { id: req.params.id } });
    res.json({ success: true });
  } catch (error) {
    console.error("Delete vehicle error:", error);
    res.status(500).json({ error: "Błąd serwera lub pojazd nie znaleziony" });
  }
};

export const getVehicleStats = async (_req: Request, res: Response): Promise<void> => {
  try {
    const [total, active, charging, maintenance, avg] = await Promise.all([
      prisma.vehicle.count(),
      prisma.vehicle.count({ where: { status: "ACTIVE" } }),
      prisma.vehicle.count({ where: { status: "CHARGING" } }),
      prisma.vehicle.count({ where: { status: "MAINTENANCE" } }),
      prisma.vehicle.aggregate({ _avg: { battery: true } })
    ]);
    res.json({ success: true, data: { total, active, charging, maintenance, avgBattery: Math.round(avg._avg.battery || 0), utilization: total ? Math.round(active / total * 100) : 0 } });
  } catch (error) {
    console.error("Vehicle stats error:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
};