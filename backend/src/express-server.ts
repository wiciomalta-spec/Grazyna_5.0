import express from 'express';
import http from 'node:http';
import { publishSocketEvent } from './redis-broadcast.js';

export async function startExpressServer() {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.status(200).json({ status: 'ok', version: '5.0.0', uptime: Math.floor(process.uptime()), timestamp: new Date().toISOString(), memory: { heapUsed: Math.round(process.memoryUsage().heapUsed/1024/1024), heapTotal: Math.round(process.memoryUsage().heapTotal/1024/1024) }, node: process.version });
  });
  app.get('/metrics-json', (_req, res) => { const m=process.memoryUsage(); res.json({ heap_pct: Math.round(m.heapUsed/m.heapTotal*100), rss_mb: Math.round(m.rss/1024/1024), uptime: Math.floor(process.uptime()) }); });
  app.get('/api', (_req, res) => res.json({ status: 'API READY', mode: 'express', version: '5.0.0' }));
  app.get('/api/system/heap', (_req, res) => { const v8=require('v8'); const m=process.memoryUsage(); const sp=v8.getHeapSpaceStatistics(); const los=sp.find((s)=>s.space_name==='large_object_space'); res.json({ heap: { used_mb: +(m.heapUsed/1024/1024).toFixed(1), total_mb: +(m.heapTotal/1024/1024).toFixed(1), pct: Math.round(m.heapUsed/m.heapTotal*100), rss_mb: +(m.rss/1024/1024).toFixed(1) }, large_object_space: los?{ used_kb: Math.round(los.space_used_size/1024), pct: los.space_size>0?Math.round(los.space_used_size/los.space_size*100):0 }:null, gc_available: typeof global.gc==='function', timestamp: new Date().toISOString() }); });
  app.post('/api/system/gc', (_req, res) => { const b=process.memoryUsage().heapUsed; if(typeof global.gc==='function'){ global.gc(); const f=+((b-process.memoryUsage().heapUsed)/1024/1024).toFixed(1); res.json({ success:true, freed_mb:f }); } else { res.json({ success:false, message:'Dodaj --expose-gc' }); } });
  app.get('/api/system/ping', (_req, res) => res.json({ pong:true, ts:Date.now(), uptime:Math.floor(process.uptime()) }));
  app.get('/api/system/env', (_req, res) => res.json({ NODE_ENV:process.env.NODE_ENV||'development', PORT:process.env.PORT||'3001', node:process.version, pid:process.pid, uptime:Math.floor(process.uptime()) }));
  app.get('/api/vehicles', (_req, res) => res.json({ vehicles:[], total:0 }));
  app.get('/api/drivers', (_req, res) => res.json({ drivers:[], total:0 }));
  app.get('/api/alerts', (_req, res) => res.json({ alerts:[], total:0, active:0 }));
  app.get('/api/reports/fleet', (_req, res) => res.json({ period:{}, summary:{ totalVehicles:0 }, generatedAt:new Date().toISOString() }));
  app.get('/api/ws/status', (_req, res) => res.json({ websocket:'available', url:`ws://localhost:${process.env.PORT||3001}` }));
  app.get('/', (_req, res) => res.send('OK'));

  const server = http.createServer(app);
  const PORT = Number(process.env.PORT || 3001);
  server.listen(PORT, () => { console.log(`\u26A1 EXPRESS READY : http://localhost:${PORT}`); });
  setInterval(() => { try { void publishSocketEvent('heartbeat', { ts:Date.now() }); } catch(e) { console.warn('[express] publish skipped', e); } }, 3000);
  process.on('SIGINT',  async () => { server.close(); process.exit(0); });
  process.on('SIGTERM', async () => { server.close(); process.exit(0); });
}