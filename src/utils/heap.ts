import v8 from 'v8';
import { Request, Response } from 'express';

// ============================================================
// ✅ DIAGNOSTYKA HEAP + LOS
// ============================================================

export function heapDiagnosticsHandler(req: Request, res: Response): void {
  const mem = process.memoryUsage();
  const spaces = v8.getHeapSpaceStatistics();

  const formatted = spaces.map(s => ({
    name: s.space_name,
    used_kb: Math.round(s.space_used_size / 1024),
    total_kb: Math.round(s.space_size / 1024),
    pct: s.space_size > 0
      ? Math.round((s.space_used_size / s.space_size) * 100)
      : 0,
  }));

  const los = formatted.find(s => s.name === 'large_object_space');

  res.json({
    heap_used_mb: (mem.heapUsed / 1024 / 1024).toFixed(1),
    heap_total_mb: (mem.heapTotal / 1024 / 1024).toFixed(1),
    heap_pct: Math.round((mem.heapUsed / mem.heapTotal) * 100),
    external_kb: Math.round(mem.external / 1024),
    large_object_space: los,
  });
}

// ============================================================
// ✅ MONITOR LOS
// ============================================================

export function monitorLargeObjectSpace(io?: any): void {
  setInterval(() => {
    const stats = v8.getHeapSpaceStatistics();
    const los = stats.find(s => s.space_name === 'large_object_space');

    if (!los) return;

    const pct = los.space_size > 0
      ? (los.space_used_size / los.space_size) * 100
      : 0;

    if (pct > 90) {
      console.warn(`[LOS ALERT] ${pct.toFixed(0)}% FULL`);

      if (io) {
        io.emit('alert:new', {
          type: 'memory',
          severity: pct > 98 ? 'critical' : 'high',
          message: `LOS ${pct.toFixed(0)}%`,
          timestamp: new Date().toISOString(),
        });
      }
    }
  }, 30000);
}

// ============================================================
// ✅ FORCED GC
// ============================================================

export function forceGCIfNeeded(threshold = 85): void {
  const mem = process.memoryUsage();
  const pct = (mem.heapUsed / mem.heapTotal) * 100;

  if (pct > threshold && typeof (global as any).gc === 'function') {
    const before = mem.heapUsed;

    (global as any).gc();

    const after = process.memoryUsage().heapUsed;
    const freed = ((before - after) / 1024 / 1024).toFixed(1);

    console.log(`[GC] freed ${freed} MB (heap ${pct.toFixed(0)}%)`);
  }
}