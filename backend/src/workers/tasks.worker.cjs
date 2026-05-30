// ============================================================
// GRAŻYNA 5.0 — tasks.worker.js (CommonJS — działa w Worker)
// NIE używaj .ts — Worker Threads nie mają dostępu do tsx
// ============================================================
'use strict';

const { parentPort } = require('worker_threads');
const crypto = require('crypto');

if (!parentPort) throw new Error('Not a worker thread');

// Lazy-load bcryptjs (tylko gdy potrzebny)
let bcrypt = null;
function getBcrypt() {
  if (!bcrypt) bcrypt = require('bcryptjs');
  return bcrypt;
}

parentPort.on('message', async ({ id, type, data }) => {
  try {
    let result;

    switch (type) {

      // ── BCRYPT ──────────────────────────────────────────
      case 'bcrypt:hash':
        result = await getBcrypt().hash(data.password, data.rounds || 12);
        break;

      case 'bcrypt:compare':
        result = await getBcrypt().compare(data.password, data.hash);
        break;

      // ── RAPORT FLOTY ────────────────────────────────────
      case 'report:fleet': {
        const vehicles = data.vehicles || [];
        const stats = vehicles.reduce((acc, v) => {
          acc.totalMileage  += v.mileage   || 0;
          acc.totalFuelCost += v.fuelCost  || 0;
          acc.byStatus[v.status] = (acc.byStatus[v.status] || 0) + 1;
          return acc;
        }, { totalMileage: 0, totalFuelCost: 0, byStatus: {} });

        result = {
          period:        data.period,
          totalVehicles: vehicles.length,
          ...stats,
          avgMileage:    vehicles.length > 0 ? stats.totalMileage / vehicles.length : 0,
          generatedAt:   new Date().toISOString(),
        };
        break;
      }

      // ── AGREGACJA GPS ────────────────────────────────────
      case 'gps:aggregate': {
        const points   = data.points || [];
        const interval = (data.intervalMinutes || 5) * 60000;
        const buckets  = new Map();

        for (const pt of points) {
          const bucket = Math.floor(pt.timestamp / interval);
          if (!buckets.has(bucket)) buckets.set(bucket, []);
          buckets.get(bucket).push(pt);
        }

        result = Array.from(buckets.entries()).map(([bucket, pts]) => ({
          timestamp: bucket * interval,
          avgLat:    pts.reduce((s, p) => s + p.lat,         0) / pts.length,
          avgLng:    pts.reduce((s, p) => s + p.lng,         0) / pts.length,
          avgSpeed:  pts.reduce((s, p) => s + (p.speed || 0), 0) / pts.length,
          count:     pts.length,
        }));
        break;
      }

      // ── HASH SHA256 ──────────────────────────────────────
      case 'hash:sha256':
        result = crypto.createHash('sha256').update(String(data.input)).digest('hex');
        break;

      // ── ANALIZA STATYSTYCZNA ─────────────────────────────
      case 'stats:analyze': {
        const metrics = data.metrics || [];
        if (metrics.length === 0) { result = {}; break; }
        const sorted = [...metrics].sort((a, b) => a - b);
        const n    = sorted.length;
        const mean = metrics.reduce((a, b) => a + b, 0) / n;
        const variance = metrics.reduce((s, v) => s + (v - mean) ** 2, 0) / n;
        result = {
          count: n,
          mean:  +mean.toFixed(3),
          std:   +Math.sqrt(variance).toFixed(3),
          min:   sorted[0],
          max:   sorted[n - 1],
          p50:   sorted[Math.floor(n * 0.50)],
          p90:   sorted[Math.floor(n * 0.90)],
          p99:   sorted[Math.floor(n * 0.99)],
        };
        break;
      }

      // ── KOMPRESJA JSON ───────────────────────────────────
      case 'json:compress': {
        const buf = Buffer.from(JSON.stringify(data.payload));
        result = { compressed: buf.toString('base64'), originalSize: buf.length };
        break;
      }

      // ── PING (test) ──────────────────────────────────────
      case 'ping':
        result = { pong: true, ts: Date.now(), pid: process.pid };
        break;

      default:
        throw new Error(`Unknown task type: ${type}`);
    }

    parentPort.postMessage({ id, data: result });

  } catch (err) {
    parentPort.postMessage({ id, error: err.message || String(err) });
  }
});

// Sygnał gotowości
parentPort.postMessage({ id: '__ready__', data: { pid: process.pid } });
