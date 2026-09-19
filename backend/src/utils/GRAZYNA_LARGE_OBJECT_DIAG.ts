/**
 * GRAŻYNA — Large Object / Heap Diagnostics
 *
 * Read-only diagnostics utility. No process mutation and no forced GC.
 */

export interface LargeObjectDiagnostics {
  timestamp: string;
  pid: number;
  rss: number;
  heapTotal: number;
  heapUsed: number;
  external: number;
  arrayBuffers: number;
  heapUtilization: number;
}

export function collectLargeObjectDiagnostics(): LargeObjectDiagnostics {
  const m = process.memoryUsage();
  return {
    timestamp: new Date().toISOString(),
    pid: process.pid,
    rss: m.rss,
    heapTotal: m.heapTotal,
    heapUsed: m.heapUsed,
    external: m.external,
    arrayBuffers: m.arrayBuffers,
    heapUtilization: m.heapTotal > 0 ? m.heapUsed / m.heapTotal : 0,
  };
}

export function formatLargeObjectDiagnostics(
  diagnostics: LargeObjectDiagnostics = collectLargeObjectDiagnostics(),
): string {
  return JSON.stringify(diagnostics);
}

export default collectLargeObjectDiagnostics;
