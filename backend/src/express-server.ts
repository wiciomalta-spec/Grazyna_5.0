import express from 'express';
import http from 'node:http';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

export async function startExpressServer() {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.status(200).json({ status: 'ok', version: '5.0.0', uptime: Math.floor(process.uptime()), timestamp: new Date().toISOString(), memory: { heapUsed: Math.round(process.memoryUsage().heapUsed/1024/1024), heapTotal: Math.round(process.memoryUsage().heapTotal/1024/1024) }, node: process.version });
  });
  app.get('/metrics-json', (_req, res) => { const m=process.memoryUsage(); res.json({ heap_pct: Math.round(m.heapUsed/m.heapTotal*100), rss_mb: Math.round(m.rss/1024/1024), uptime: Math.floor(process.uptime()) }); });
  app.get('/metrics', (_req, res) => { const m=process.memoryUsage(); const now=Math.floor(Date.now()/1000); const start=now-Math.floor(process.uptime()); res.type('text/plain').send([`# HELP nodejs_heap_size_used_bytes Process heap used`,`# TYPE nodejs_heap_size_used_bytes gauge`,`nodejs_heap_size_used_bytes ${m.heapUsed}`,`# HELP nodejs_heap_size_total_bytes Process heap total`,`# TYPE nodejs_heap_size_total_bytes gauge`,`nodejs_heap_size_total_bytes ${m.heapTotal}`,`# HELP process_resident_memory_bytes Process RSS`,`# TYPE process_resident_memory_bytes gauge`,`process_resident_memory_bytes ${m.rss}`,`# HELP nodejs_eventloop_lag_seconds Event loop lag (compatibility metric)`,`# TYPE nodejs_eventloop_lag_seconds gauge`,`nodejs_eventloop_lag_seconds 0`,`# HELP nodejs_eventloop_lag_max_seconds Event loop lag maximum (compatibility metric)`,`# TYPE nodejs_eventloop_lag_max_seconds gauge`,`nodejs_eventloop_lag_max_seconds 0`,`# HELP process_start_time_seconds Process start time`,`# TYPE process_start_time_seconds gauge`,`process_start_time_seconds ${start}`].join('\\n')+'\\n'); });
  app.get('/api', (_req, res) => res.json({ status: 'API READY', mode: 'express', version: '5.0.0' }));
  app.get('/api/system/heap', (_req, res) => { const v8=require('v8'); const m=process.memoryUsage(); const sp=v8.getHeapSpaceStatistics(); const los=sp.find((s: any)=>s.space_name==='large_object_space'); res.json({ heap: { used_mb: +(m.heapUsed/1024/1024).toFixed(1), total_mb: +(m.heapTotal/1024/1024).toFixed(1), pct: Math.round(m.heapUsed/m.heapTotal*100), rss_mb: +(m.rss/1024/1024).toFixed(1) }, large_object_space: los?{ used_kb: Math.round((los as any).space_used_size/1024), pct: (los as any).space_size>0?Math.round((los as any).space_used_size/(los as any).space_size*100):0 }:null, gc_available: typeof (global as any).gc==='function', timestamp: new Date().toISOString() }); });
  app.post('/api/system/gc', (_req, res) => { const b=process.memoryUsage().heapUsed; if(typeof (global as any).gc==='function'){ (global as any).gc(); const f=+((b-process.memoryUsage().heapUsed)/1024/1024).toFixed(1); res.json({ success:true, freed_mb:f }); } else { res.json({ success:false, message:'Dodaj --expose-gc' }); } });
  app.get('/api/system/ping', (_req, res) => res.json({ pong:true, ts:Date.now(), uptime:Math.floor(process.uptime()) }));
  const GRAZYNA_ROOT = process.env.GRAZYNA_ROOT || 'E:\\Grazyna_5.0';
  const UPDATE_SCRIPT = path.join(GRAZYNA_ROOT, 'runtime', 'update', 'GrazynaControlledUpdate.ps1');
  function runUpdateController(action: string, planId?: string) {
    if (!fs.existsSync(UPDATE_SCRIPT)) return { ok:false, error:'UPDATE_CONTROLLER_MISSING', script:UPDATE_SCRIPT };
    const args=['-NoProfile','-File',UPDATE_SCRIPT,'-Action',action];
    if(planId) args.push('-PlanId',planId);
    const r=spawnSync('pwsh.exe',args,{encoding:'utf8',timeout:120000,windowsHide:true});
    return { ok:r.status===0, exitCode:r.status, stdout:r.stdout||'', stderr:r.stderr||'' };
  }
  app.get('/api/system/update/inventory', (_req, res) => {
    const r=runUpdateController('Inventory');
    if(!r.ok) return res.status(500).json(r);
    try{res.json({ok:true,data:JSON.parse(r.stdout)})}catch{res.status(500).json({ok:false,error:'UPDATE_INVENTORY_JSON_INVALID',raw:r.stdout,stderr:r.stderr})}
  });
  app.post('/api/system/update/plan', (_req, res) => {
    const r=runUpdateController('Plan');
    if(!r.ok) return res.status(500).json(r);
    try{res.json({ok:true,plan:JSON.parse(r.stdout)})}catch{res.status(500).json({ok:false,error:'UPDATE_PLAN_JSON_INVALID',raw:r.stdout,stderr:r.stderr})}
  });
  app.post('/api/system/update/apply', (req, res) => {
    if(req.body?.confirm !== 'GRAZYNA-APPLY') return res.status(400).json({ok:false,error:'CONFIRMATION_REQUIRED',required:'GRAZYNA-APPLY'});
    const planId=String(req.body?.plan_id||'');
    if(!planId) return res.status(400).json({ok:false,error:'PLAN_ID_REQUIRED'});
    const r=runUpdateController('Apply',planId);
    res.status(r.ok?200:500).json({ok:r.ok,exitCode:r.exitCode,raw:r.stdout,stderr:r.stderr});
  });
  app.get('/api/system/env', (_req, res) => res.json({ NODE_ENV:process.env.NODE_ENV||'development', PORT:process.env.PORT||'3001', node:process.version, pid:process.pid, uptime:Math.floor(process.uptime()) }));
  app.get('/api/vehicles', (_req, res) => res.json({ vehicles:[], total:0 }));
  app.get('/api/drivers', (_req, res) => res.json({ drivers:[], total:0 }));
  app.get('/api/alerts', (_req, res) => res.json({ alerts:[], total:0, active:0 }));
  app.get('/api/reports/fleet', (_req, res) => res.json({ period:{}, summary:{ totalVehicles:0 }, generatedAt:new Date().toISOString() }));
  app.get('/api/ws/status', (_req, res) => res.json({ websocket:'available', url:`ws://localhost:${process.env.PORT||3001}` }));
  app.get('/', (_req, res) => res.send('OK'));

  const server = http.createServer(app);
  const PORT = Number(process.env.PORT || 3001);
  server.listen(PORT, '127.0.0.1', () => { console.log(`\u26A1 EXPRESS READY : http://127.0.0.1:${PORT}`); });
  process.on('SIGINT',  async () => { server.close(); process.exit(0); });
  process.on('SIGTERM', async () => { server.close(); process.exit(0); });
}

// Auto-start
startExpressServer().catch(console.error);
