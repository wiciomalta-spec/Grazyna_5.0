import { Request, Response } from 'express';
import { z } from 'zod';
import { kernelService } from '../services/kernel.service.js';

const adaptSchema = z.object({
  mode: z.enum(['minimal', 'balanced', 'turbo', 'portable', 'autonomous']).optional(),
});

export const getKernelProfile = async (_req: Request, res: Response): Promise<void> => {
  res.json({ success: true, data: kernelService.getRuntimeProfile() });
};

export const getKernelBlueprint = async (_req: Request, res: Response): Promise<void> => {
  res.json({ success: true, data: kernelService.getBlueprint() });
};

export const getKernelDrivers = async (_req: Request, res: Response): Promise<void> => {
  res.json({ success: true, data: kernelService.getDrivers() });
};

export const adaptKernel = async (req: Request, res: Response): Promise<void> => {
  const parsed = adaptSchema.safeParse(req.body || {});
  if (!parsed.success) {
    res.status(400).json({ error: 'Błąd walidacji', details: parsed.error.errors });
    return;
  }

  const result = kernelService.adapt(parsed.data.mode);
  res.json({ success: true, data: result });
};
