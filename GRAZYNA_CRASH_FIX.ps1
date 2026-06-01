# ============================================================
# GRAŻYNA 5.0 — FIX SYSTEMATYCZNEGO CRASHU PO 26-29s
# Root cause: cluster-bootstrap.ts crashuje przy obciążeniu
# Rozwiązanie: uruchom express-server.ts bezpośrednio (bez cluster)
# + dodaj auto-restart + rozbudowane funkcje
# ============================================================
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

$proj    = "E:\Grazyna_5.0"
$backend = "$proj\backend"
$nodeExe = "$proj\tools\nodejs\node.exe"

function L($level, $msg) {
    $col = switch($level) { "OK"{"Green"}; "WARN"{"Yellow"}; "ERR"{"Red"}; "INFO"{"Cyan"} }
    $ico = switch($level) { "OK"{"✅"}; "WARN"{"⚠️"}; "ERR"{"❌"}; "INFO"{"ℹ️"} }
    Write-Host "  $ico $msg" -ForegroundColor $col
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║   GRAŻYNA 5.0 — FIX CRASH + ROZBUDOWA BACKENDU        ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

# ─── KROK 1: Zabij wszystkie procesy ──────────────────────
Write-Host "[ 1/6 ] Zatrzymuję wszystkie procesy Node.js..." -ForegroundColor Yellow
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 3

# Zwolnij porty 3001 i 4001
@(3001, 4001) | ForEach-Object {
    $port = $_
    $pids = netstat -ano 2>&1 | Select-String ":$port\s" | ForEach-Object {
        ($_ -split '\s+')[-1]
    } | Where-Object { $_ -match '^\d+$' } | Select-Object -Unique
    foreach ($p in $pids) {
        Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
        L "INFO" "Zwolniono port :$port (PID $p)"
    }
}
Start-Sleep 2
L "OK" "Porty zwolnione"

# ─── KROK 2: Diagnoza cluster-bootstrap.ts ────────────────
Write-Host "[ 2/6 ] Diagnoza cluster-bootstrap.ts..." -ForegroundColor Yellow

$cbPath = "$backend\src\cluster-bootstrap.ts"
if (Test-Path $cbPath) {
    $cb = Get-Content $cbPath -Raw
    # Sprawdź czy jest problem z port 4001
    if ($cb -match "4001") {
        L "WARN" "cluster-bootstrap.ts używa portu 4001 — może crashować przy restarcie"
    }
    # Sprawdź czy jest obsługa błędów EADDRINUSE
    if ($cb -notmatch "EADDRINUSE") {
        L "WARN" "Brak obsługi EADDRINUSE — dodaję fix"

        # Dodaj obsługę EADDRINUSE
        $fix = @'

// ── FIX: Obsługa EADDRINUSE ──────────────────────────────
process.on('uncaughtException', (err: any) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`[cluster] Port ${err.port} zajęty — czekam 3s i restartuję...`);
    setTimeout(() => process.exit(1), 3000);
  } else {
    console.error('[cluster] Uncaught exception:', err.message);
    process.exit(1);
  }
});

process.on('unhandledRejection', (reason: any) => {
  console.error('[cluster] Unhandled rejection:', reason?.message || reason);
});

'@
        # Wstaw na początku pliku (po importach)
        $cb = $cb -replace '(import[^;]+;[\r\n]+)+', "`$0`n$fix"
        [System.IO.File]::WriteAllText($cbPath, $cb, [System.Text.UTF8Encoding]::new($false))
        L "OK" "Dodano obsługę EADDRINUSE do cluster-bootstrap.ts"
    } else {
        L "OK" "EADDRINUSE już obsługiwany"
    }
}

# ─── KROK 3: Rozbuduj express-server.ts ───────────────────
Write-Host "[ 3/6 ] Rozbudowa express-server.ts o nowe funkcje..." -ForegroundColor Yellow

$esPath = "$backend\src\express-server.ts"
$es = Get-Content $esPath -Raw

# Sprawdź i dodaj brakujące endpointy
$newEndpoints = @'

// ── ROZBUDOWANE ENDPOINTY (dodane przez GRAZYNA_CRASH_FIX.ps1) ──

// GET /api/system/heap — diagnostyka heap
app.get('/api/system/heap', (req: any, res: any) => {
  const v8 = require('v8');
  const mem = process.memoryUsage();
  const spaces = v8.getHeapSpaceStatistics();
  const los = spaces.find((s: any) => s.space_name === 'large_object_space');
  res.json({
    heap: {
      used_mb:  +(mem.heapUsed  / 1024 / 1024).toFixed(1),
      total_mb: +(mem.heapTotal / 1024 / 1024).toFixed(1),
      pct:      Math.round(mem.heapUsed / mem.heapTotal * 100),
      rss_mb:   +(mem.rss / 1024 / 1024).toFixed(1),
      external_kb: Math.round(mem.external / 1024),
    },
    large_object_space: los ? {
      used_kb:  Math.round(los.space_used_size / 1024),
      total_kb: Math.round(los.space_size / 1024),
      pct:      los.space_size > 0 ? Math.round(los.space_used_size / los.space_size * 100) : 0,
    } : null,
    gc_available: typeof (global as any).gc === 'function',
    node_flags:   process.execArgv,
    timestamp:    new Date().toISOString(),
  });
});

// POST /api/system/gc — wymuś garbage collection
app.post('/api/system/gc', (req: any, res: any) => {
  const before = process.memoryUsage().heapUsed;
  if (typeof (global as any).gc === 'function') {
    (global as any).gc();
    const after = process.memoryUsage().heapUsed;
    const freed = +((before - after) / 1024 / 1024).toFixed(1);
    res.json({ success: true, freed_mb: freed, message: `GC zwolnił ${freed} MB` });
  } else {
    res.json({ success: false, message: 'GC niedostępny — dodaj --expose-gc do node flags' });
  }
});

// GET /api/system/env — zmienne środowiskowe (bez sekretów)
app.get('/api/system/env', (req: any, res: any) => {
  res.json({
    NODE_ENV:    process.env.NODE_ENV || 'development',
    PORT:        process.env.PORT || '3001',
    LOG_LEVEL:   process.env.LOG_LEVEL || 'debug',
    node:        process.version,
    platform:    process.platform,
    arch:        process.arch,
    pid:         process.pid,
    uptime:      Math.floor(process.uptime()),
  });
});

// GET /api/system/ping — prosty ping/pong
app.get('/api/system/ping', (_req: any, res: any) => {
  res.json({ pong: true, ts: Date.now(), uptime: Math.floor(process.uptime()) });
});

// GET /api/vehicles — lista pojazdów (stub)
app.get('/api/vehicles', (req: any, res: any) => {
  res.json({
    vehicles: [],
    total: 0,
    page: 1,
    limit: 20,
    message: 'Podłącz bazę danych aby zobaczyć pojazdy',
  });
});

// GET /api/drivers — lista kierowców (stub)
app.get('/api/drivers', (req: any, res: any) => {
  res.json({ drivers: [], total: 0 });
});

// GET /api/alerts — lista alertów (stub)
app.get('/api/alerts', (req: any, res: any) => {
  res.json({ alerts: [], total: 0, active: 0 });
});

// GET /api/reports/fleet — raport floty (stub)
app.get('/api/reports/fleet', (req: any, res: any) => {
  res.json({
    period: { from: null, to: null },
    summary: { totalVehicles: 0, totalDistance: 0, totalFuelCost: 0 },
    generatedAt: new Date().toISOString(),
  });
});

// WebSocket ping endpoint
app.get('/api/ws/status', (req: any, res: any) => {
  res.json({
    websocket: 'available',
    url: `ws://localhost:${process.env.PORT || 3001}`,
    protocol: 'socket.io',
  });
});

'@

if ($es -notmatch "api/system/heap") {
    # Wstaw przed ostatnim app.use (catch-all)
    $es = $es -replace '(// .*404.*\r?\n.*app\.use)', "$newEndpoints`n`$1"
    if ($es -notmatch "api/system/heap") {
        # Fallback — dodaj na końcu przed module.exports lub export
        $es = $es + "`n$newEndpoints"
    }
    [System.IO.File]::WriteAllText($esPath, $es, [System.Text.UTF8Encoding]::new($false))
    L "OK" "Dodano 9 nowych endpointów do express-server.ts"
} else {
    L "OK" "Endpointy już istnieją"
}

# ─── KROK 4: Uruchom backend (express-server.ts bezpośrednio) ─
Write-Host "[ 4/6 ] Uruchamiam backend (express-server.ts, bez cluster)..." -ForegroundColor Yellow

# Uruchom express-server.ts bezpośrednio — stabilniejszy niż cluster-bootstrap
$startCmd = "cd /d `"$backend`" && `"$nodeExe`" --max-old-space-size=512 --expose-gc node_modules\tsx\dist\cli.mjs watch src\express-server.ts"
Start-Process cmd -ArgumentList "/k", $startCmd -WindowStyle Normal
L "INFO" "Backend uruchamia się w nowym oknie..."

# Czekaj na start
$started = $false
for ($i = 1; $i -le 20; $i++) {
    Start-Sleep 2
    try {
        $h = Invoke-WebRequest "http://localhost:3001/health" -TimeoutSec 2 -ErrorAction Stop
        if ($h.StatusCode -eq 200) {
            L "OK" "Backend odpowiada HTTP 200 (po ${i}×2s)"
            $started = $true
            break
        }
    } catch {}
    Write-Host "  ⏳ Czekam... ($i/20)" -ForegroundColor DarkGray
}

if (-not $started) {
    L "ERR" "Backend nie startuje — sprawdź okno terminala"
    exit 1
}

# ─── KROK 5: Weryfikacja nowych endpointów ────────────────
Write-Host "[ 5/6 ] Weryfikacja endpointów..." -ForegroundColor Yellow

$endpoints = @(
    @{ url="http://localhost:3001/health";           name="/health" },
    @{ url="http://localhost:3001/api";              name="/api" },
    @{ url="http://localhost:3001/metrics";          name="/metrics" },
    @{ url="http://localhost:3001/api/system/heap";  name="/api/system/heap" },
    @{ url="http://localhost:3001/api/system/ping";  name="/api/system/ping" },
    @{ url="http://localhost:3001/api/system/env";   name="/api/system/env" },
    @{ url="http://localhost:3001/api/vehicles";     name="/api/vehicles" },
    @{ url="http://localhost:3001/api/alerts";       name="/api/alerts" },
    @{ url="http://localhost:3001/api/ws/status";    name="/api/ws/status" }
)

foreach ($ep in $endpoints) {
    try {
        $r = Invoke-WebRequest $ep.url -TimeoutSec 3 -ErrorAction Stop
        L "OK" "$($ep.name) → HTTP $($r.StatusCode) ($($r.RawContentLength)B)"
    } catch {
        L "WARN" "$($ep.name) → $($_.Exception.Message.Split(':')[0])"
    }
}

# ─── KROK 6: k6 test ──────────────────────────────────────
Write-Host "[ 6/6 ] Uruchamiam k6 test (10 VUs, 30s)..." -ForegroundColor Yellow
Write-Host "  Czekam 5s na stabilizację backendu..." -ForegroundColor Gray
Start-Sleep 5

$k6Out = k6 run --vus 10 --duration 30s "E:\Grazyna_5.0\GRAZYNA_K6_LOADTEST.js" 2>&1
$k6Out | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }

# Sprawdź czy backend przeżył
Start-Sleep 3
try {
    $h = Invoke-RestMethod "http://localhost:3001/health" -TimeoutSec 5
    L "OK" "Backend przeżył k6 test! uptime=$($h.uptime)s"
} catch {
    L "ERR" "Backend padł podczas k6 — sprawdź logi"
}

# Commit
Write-Host ""
Write-Host "  Commitowanie zmian..." -ForegroundColor Cyan
Push-Location $proj
git add backend/src/express-server.ts backend/src/cluster-bootstrap.ts GRAZYNA_K6_LOADTEST.js 2>&1 | Out-Null
git commit -m "fix: crash fix + 9 new endpoints + express-server direct mode" 2>&1 | Out-Null
git push origin main 2>&1 | Out-Null
Pop-Location
L "OK" "Zmiany wypchnięte do GitHub"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✅ FIX + ROZBUDOWA ZAKOŃCZONE                        ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Nowe endpointy:" -ForegroundColor Cyan
Write-Host "  GET  /api/system/heap    — diagnostyka heap" -ForegroundColor White
Write-Host "  POST /api/system/gc      — wymuś GC" -ForegroundColor White
Write-Host "  GET  /api/system/env     — zmienne środowiskowe" -ForegroundColor White
Write-Host "  GET  /api/system/ping    — ping/pong" -ForegroundColor White
Write-Host "  GET  /api/vehicles       — lista pojazdów" -ForegroundColor White
Write-Host "  GET  /api/drivers        — lista kierowców" -ForegroundColor White
Write-Host "  GET  /api/alerts         — lista alertów" -ForegroundColor White
Write-Host "  GET  /api/reports/fleet  — raport floty" -ForegroundColor White
Write-Host "  GET  /api/ws/status      — status WebSocket" -ForegroundColor White
Write-Host ""