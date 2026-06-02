# 🔴 GRAŻYNA 5.0 — Głęboka Analiza Crashu Klastra

## Symptomy (zaobserwowane)

```
Crash po: ~26-29s pod obciążeniem k6 (10 VUs)
Błąd 1:   EADDRINUSE :4001 (cluster-control port)
Błąd 2:   connection refused :3001 po crashu
Pattern:  ZAWSZE po ~26-29s — deterministyczny!
Watchdog: 5 prób restartu → MAX retry → stop
```

---

## Root Cause Analysis (RCA)

### Przyczyna #1: Port 4001 nie jest zwalniany (GŁÓWNA)

```typescript
// cluster-bootstrap.ts:127
const controlServer = http.createServer(controlApp);
controlServer.listen(4001);  // ← BEZ obsługi błędów!

// Gdy cluster worker crashuje → primary restartuje
// Ale port 4001 jest nadal zajęty przez poprzedni proces
// → EADDRINUSE → cały primary crashuje → wszystkie workery padają
```

**Fix:**
```typescript
controlServer.on('error', (err: any) => {
  if (err.code === 'EADDRINUSE') {
    console.warn('[cluster] Port 4001 zajęty — pomijam control server');
    // Nie crashuj — kontynuuj bez control server
  }
});
```

### Przyczyna #2: Brak graceful shutdown workerów

```typescript
// Gdy worker crashuje pod obciążeniem:
// 1. Worker dostaje SIGTERM
// 2. Worker nie kończy aktywnych requestów
// 3. Primary fork()uje nowego workera
// 4. Nowy worker próbuje nasłuchiwać na :4001
// 5. EADDRINUSE → crash kaskadowy
```

### Przyczyna #3: tsx watch + cluster = niestabilne

```
tsx watch restartuje cały proces przy zmianie pliku
W cluster mode: primary + 3 workers = 4 procesy
tsx watch może restartować primary podczas gdy workery działają
→ Orphaned workers + port conflicts
```

### Przyczyna #4: Memory pressure pod k6

```
k6 10 VUs × iteracja co ~1s = ~10 req/s
Każdy request: bcrypt login (~100ms CPU) × 10 = 1000ms CPU/s
Cluster 3 workers × heap 93% = heap pressure
→ GC pause → EL lag spike → timeout → crash
```

---

## Cluster vs Single-Process — Porównanie Stabilności

### Wyniki testów (Twoje dane)

| Scenariusz | Cluster (3w) | Single Process | Zwycięzca |
|---|---|---|---|
| **Stabilność** | ❌ Crash po 26s | ✅ 2.2h uptime | Single |
| **EL Lag** | 1.58ms | 2.12ms | Cluster |
| **EL Max** | 35ms | 69ms | Cluster |
| **Heap %** | 83.6% | 93.2% | Cluster |
| **RSS** | 86.4MB | 66.1MB | Single |
| **k6 errors** | 100% (crash) | TBD | Single |
| **Restart** | Kaskadowy | Prosty | Single |
| **CPU usage** | 0.10% | 0.10% | Remis |

### Kiedy używać czego

```
DEVELOPMENT (teraz):
  → Single Process (express-server.ts)
  → Stabilny, prosty debug, szybki restart
  → Wystarczający dla dev/test

PRODUKCJA (Hetzner):
  → Cluster z PM2 (nie tsx watch!)
  → PM2 zarządza workerami profesjonalnie
  → Graceful reload, log management, monitoring
```

### PM2 vs tsx watch w cluster mode

```
tsx watch:  Dev tool, nie production-ready
            Restartuje przy każdej zmianie pliku
            Brak graceful shutdown
            Brak log rotation

PM2:        Production process manager
            Graceful reload (zero downtime)
            Log rotation wbudowany
            Monitoring dashboard
            Auto-restart z backoff
            Cluster mode stabilny
```

---

## Plan Monitoringu Crashów Produkcyjnych

### Poziomy monitoringu

```
Poziom 1: Process (Node.js)
  → PM2 monitoring (wbudowany)
  → Heap/EL lag co 5s
  → Auto-restart przy crash

Poziom 2: Application (Express)
  → /health endpoint co 30s
  → Error rate z Prometheus
  → Response time p95/p99

Poziom 3: Infrastructure (Hetzner)
  → CPU/RAM/Disk co 1min
  → Network I/O
  → Docker container health

Poziom 4: Business (GRAŻYNA)
  → Aktywne pojazdy
  → Misje w toku
  → Alerty nierozwiązane
```

### Implementacja alertów

```typescript
// backend/src/crash-monitor.ts

import { EventEmitter } from 'events';

interface CrashEvent {
  type:      'oom' | 'el_lag' | 'gc_pressure' | 'port_conflict' | 'unhandled';
  severity:  'warning' | 'critical';
  message:   string;
  metrics:   Record<string, number>;
  timestamp: string;
  pid:       number;
}

class CrashMonitor extends EventEmitter {
  private heapHistory:  number[] = [];
  private elHistory:    number[] = [];
  private crashCount:   number = 0;
  private lastCrash:    Date | null = null;

  start(): void {
    // Monitor heap co 5s
    setInterval(() => this.checkHeap(), 5000);

    // Monitor EL lag
    const { monitorEventLoopDelay } = require('perf_hooks');
    const h = monitorEventLoopDelay({ resolution: 10 });
    h.enable();
    setInterval(() => {
      const lagMs = h.mean / 1e6;
      this.checkELLag(lagMs);
      h.reset();
    }, 5000);

    // Obsługa uncaught errors
    process.on('uncaughtException', (err) => this.handleCrash('unhandled', err));
    process.on('unhandledRejection', (r) => this.handleCrash('unhandled', r as Error));

    console.log('[CrashMonitor] Started');
  }

  private checkHeap(): void {
    const mem = process.memoryUsage();
    const pct = (mem.heapUsed / mem.heapTotal) * 100;
    this.heapHistory.push(pct);
    if (this.heapHistory.length > 12) this.heapHistory.shift(); // 1 minuta

    if (pct > 95) {
      this.emit('crash_risk', {
        type: 'oom', severity: 'critical',
        message: `Heap ${pct.toFixed(1)}% — OOM imminent!`,
        metrics: { heap_pct: pct, rss_mb: mem.rss / 1024 / 1024 },
        timestamp: new Date().toISOString(), pid: process.pid,
      } as CrashEvent);

      // Wymuś GC jeśli dostępny
      if (typeof (global as any).gc === 'function') {
        (global as any).gc();
      }
    }
  }

  private checkELLag(lagMs: number): void {
    this.elHistory.push(lagMs);
    if (this.elHistory.length > 12) this.elHistory.shift();

    if (lagMs > 500) {
      this.emit('crash_risk', {
        type: 'el_lag', severity: 'critical',
        message: `EL Lag ${lagMs.toFixed(0)}ms — process blocked!`,
        metrics: { el_lag_ms: lagMs },
        timestamp: new Date().toISOString(), pid: process.pid,
      } as CrashEvent);
    }
  }

  private handleCrash(type: string, err: Error): void {
    this.crashCount++;
    this.lastCrash = new Date();

    const event: CrashEvent = {
      type: type as any, severity: 'critical',
      message: err?.message || String(err),
      metrics: { crash_count: this.crashCount },
      timestamp: new Date().toISOString(), pid: process.pid,
    };

    this.emit('crash', event);
    console.error('[CrashMonitor] CRASH:', event);

    // Graceful shutdown zamiast nagłego crashu
    setTimeout(() => process.exit(1), 1000);
  }

  getStats() {
    return {
      crashCount: this.crashCount,
      lastCrash:  this.lastCrash?.toISOString() || null,
      heapTrend:  this.heapHistory.slice(-3),
      elTrend:    this.elHistory.slice(-3),
    };
  }
}

export const crashMonitor = new CrashMonitor();
```

---

## Skrypt PM2 dla Produkcji

```javascript
// ecosystem.config.js (E:\Grazyna_5.0\backend\ecosystem.config.js)
module.exports = {
  apps: [{
    name:         'grazyna-backend',
    script:       'dist/express-server.js',
    instances:    'max',        // liczba CPU cores
    exec_mode:    'cluster',    // PM2 cluster (stabilny!)
    max_memory_restart: '400M', // restart gdy >400MB RAM
    node_args:    '--max-old-space-size=512 --expose-gc',
    env: {
      NODE_ENV: 'production',
      PORT:     3001,
    },
    // Crash recovery
    restart_delay:    3000,   // 3s przed restartem
    max_restarts:     10,     // max 10 restartów
    min_uptime:       '10s',  // min 10s uptime = "stabilny"
    // Logging
    log_file:         'logs/pm2-combined.log',
    error_file:       'logs/pm2-error.log',
    out_file:         'logs/pm2-out.log',
    log_date_format:  'YYYY-MM-DD HH:mm:ss',
    // Monitoring
    pmx:              true,   // PM2 Plus monitoring
  }],
};
```

```powershell
# Instalacja PM2 i uruchomienie
cmd /c "cd /d E:\Grazyna_5.0\backend && E:\Grazyna_5.0\tools\nodejs\npm.cmd install -g pm2"
cmd /c "cd /d E:\Grazyna_5.0\backend && E:\Grazyna_5.0\tools\nodejs\npm.cmd run build"
cmd /c "cd /d E:\Grazyna_5.0\backend && pm2 start ecosystem.config.js"
cmd /c "pm2 status"
cmd /c "pm2 logs grazyna-backend --lines 20"
```

---

## Natychmiastowe Fixy (wklej do PowerShell)

```powershell
# Fix 1: Uruchom single process (stabilny)
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3
Start-Process cmd -ArgumentList "/k", "cd /d E:\Grazyna_5.0\backend && E:\Grazyna_5.0\tools\nodejs\node.exe --max-old-space-size=512 --expose-gc node_modules\tsx\dist\cli.mjs src\express-server.ts"
Start-Sleep 10
Invoke-RestMethod http://localhost:3001/health

# Fix 2: k6 test po naprawie
k6 run --vus 5 --duration 30s E:\Grazyna_5.0\GRAZYNA_K6_LOADTEST.js

# Fix 3: Napraw node.exe hardlink (jako Admin)
& "E:\Grazyna_5.0\GRAZYNA_FIX_NODELINK.ps1"
```

---

## Podsumowanie

| Problem | Status | Fix |
|---|---|---|
| Crash klastra po 26s | 🔴 Aktywny | Użyj single process lub PM2 |
| EADDRINUSE :4001 | 🔴 Aktywny | Dodaj error handler |
| tsx watch w cluster | 🔴 Aktywny | Użyj PM2 na produkcji |
| node.exe hardlink | ⚠️ Ostrzeżenie | GRAZYNA_FIX_NODELINK.ps1 |
| Heap 93% | ⚠️ Monitoruj | --max-old-space-size=512 |
| 3 panele HTML | ✅ OK | Użyj GRAZYNA_MEGA_PANEL.html |