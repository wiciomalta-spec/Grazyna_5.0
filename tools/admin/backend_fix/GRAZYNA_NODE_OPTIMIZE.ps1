# ============================================================
# GRAŻYNA 5.0 — OPTYMALIZACJA NODE.JS
# Oparta na rzeczywistych metrykach:
#   EL Lag: 1.58ms (max 35ms, p99 29.9ms)
#   Heap:   91.1% (17.4/19.1 MB)
#   RSS:    63.6 MB
#   GC:     Minor×26, Major×1
# ============================================================

$proj    = "E:\Grazyna_5.0"
$backend = "$proj\backend"
$nodeExe = "$proj\tools\nodejs\node.exe"
$npmCmd  = "$proj\tools\nodejs\npm.cmd"

function Log($level, $msg) {
    $col = switch($level) { "OK"{"Green"}; "WARN"{"Yellow"}; "ERR"{"Red"}; "INFO"{"Cyan"} }
    $ico = switch($level) { "OK"{"✅"}; "WARN"{"⚠️"}; "ERR"{"❌"}; "INFO"{"ℹ️"} }
    Write-Host "  $ico $msg" -ForegroundColor $col
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    GRAŻYNA 5.0 — OPTYMALIZACJA NODE.JS               ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─── KROK 1: Analiza aktualnych metryk ────────────────────
Write-Host "[ 1/6 ] Analiza aktualnych metryk..." -ForegroundColor Yellow
try {
    $metrics = Invoke-WebRequest -Uri "http://localhost:3001/metrics" -TimeoutSec 5 -ErrorAction Stop
    $text = $metrics.Content

    $elLag = [regex]::Match($text, 'nodejs_eventloop_lag_seconds\s+([\d.]+)').Groups[1].Value
    $elMax = [regex]::Match($text, 'nodejs_eventloop_lag_max_seconds\s+([\d.]+)').Groups[1].Value
    $elP99 = [regex]::Match($text, 'nodejs_eventloop_lag_p99_seconds\s+([\d.]+)').Groups[1].Value
    $heapUsed = [regex]::Match($text, 'nodejs_heap_size_used_bytes\s+([\d.]+)').Groups[1].Value
    $heapTotal = [regex]::Match($text, 'nodejs_heap_size_total_bytes\s+([\d.]+)').Groups[1].Value
    $rss = [regex]::Match($text, 'process_resident_memory_bytes\s+([\d.]+)').Groups[1].Value

    $elLagMs  = [math]::Round([double]$elLag * 1000, 2)
    $elMaxMs  = [math]::Round([double]$elMax * 1000, 2)
    $elP99Ms  = [math]::Round([double]$elP99 * 1000, 2)
    $heapPct  = [math]::Round(([double]$heapUsed / [double]$heapTotal) * 100, 1)
    $rssMB    = [math]::Round([double]$rss / 1MB, 1)
    $heapMB   = [math]::Round([double]$heapUsed / 1MB, 1)
    $heapTMB  = [math]::Round([double]$heapTotal / 1MB, 1)

    Write-Host ""
    Write-Host "  📊 AKTUALNE METRYKI:" -ForegroundColor White
    Write-Host "     EL Lag:    ${elLagMs}ms (max: ${elMaxMs}ms, p99: ${elP99Ms}ms)" -ForegroundColor $(if($elLagMs -gt 10){"Yellow"}else{"Green"})
    Write-Host "     Heap:      ${heapPct}% (${heapMB}/${heapTMB} MB)" -ForegroundColor $(if($heapPct -gt 85){"Yellow"}else{"Green"})
    Write-Host "     RSS:       ${rssMB} MB" -ForegroundColor Cyan
    Write-Host ""

    $needsOptimization = $heapPct -gt 85 -or $elMaxMs -gt 50
} catch {
    Log "WARN" "Nie można pobrać metryk z :3001 — kontynuuję z domyślnymi ustawieniami"
    $heapPct = 91.1; $elMaxMs = 35.0; $needsOptimization = $true
}

# ─── KROK 2: Optymalizacja package.json scripts ───────────
Write-Host "[ 2/6 ] Optymalizacja package.json (Node.js flags)..." -ForegroundColor Yellow

$pkgPath = "$backend\package.json"
$pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json

# Oblicz optymalny --max-old-space-size
# Reguła: 2× aktualny heap total, min 128MB, max 512MB
$heapTotalMB = [math]::Round([double]$heapTotal / 1MB, 0)
$optimalHeap = [math]::Max(128, [math]::Min(512, $heapTotalMB * 2))

$nodeFlags = "--max-old-space-size=$optimalHeap --expose-gc"

$oldDev   = $pkg.scripts.dev
$oldStart = $pkg.scripts.start

# Dodaj flagi jeśli ich nie ma
if ($pkg.scripts.dev -notmatch "max-old-space-size") {
    $pkg.scripts.dev   = "node $nodeFlags node_modules/.bin/tsx watch src/index.ts"
    $pkg.scripts.start = "node $nodeFlags dist/index.js"
    $pkg | ConvertTo-Json -Depth 10 | Set-Content $pkgPath -Encoding UTF8
    Log "OK" "Dodano --max-old-space-size=$optimalHeap --expose-gc do scripts"
    Log "INFO" "dev:   $($pkg.scripts.dev)"
    Log "INFO" "start: $($pkg.scripts.start)"
} else {
    Log "OK" "Flagi Node.js już skonfigurowane"
}

# ─── KROK 3: Dodaj EL Optimization module ─────────────────
Write-Host "[ 3/6 ] Kopiowanie modułu optymalizacji EL..." -ForegroundColor Yellow

$elOptSrc = "$proj\GRAZYNA_EL_OPTIMIZATION.ts"
$elOptDst = "$backend\src\el-optimization.ts"

if (Test-Path $elOptSrc) {
    Copy-Item $elOptSrc $elOptDst -Force
    Log "OK" "Skopiowano el-optimization.ts do backend/src/"
} else {
    Log "WARN" "GRAZYNA_EL_OPTIMIZATION.ts nie znaleziony — pomiń"
}

# ─── KROK 4: Optymalizacja .env ───────────────────────────
Write-Host "[ 4/6 ] Optymalizacja zmiennych środowiskowych..." -ForegroundColor Yellow

$envPath = "$backend\.env"
$envContent = Get-Content $envPath -Raw -ErrorAction SilentlyContinue

$envAdditions = @()

# UV_THREADPOOL_SIZE — więcej wątków dla I/O
if ($envContent -notmatch "UV_THREADPOOL_SIZE") {
    $envAdditions += "UV_THREADPOOL_SIZE=16"
    Log "OK" "Dodano UV_THREADPOOL_SIZE=16 (więcej wątków I/O)"
}

# NODE_OPTIONS — dodatkowe flagi
if ($envContent -notmatch "NODE_OPTIONS") {
    $envAdditions += "NODE_OPTIONS=--max-old-space-size=$optimalHeap"
    Log "OK" "Dodano NODE_OPTIONS=--max-old-space-size=$optimalHeap"
}

# DATABASE_URL z connection pool
if ($envContent -match "DATABASE_URL=postgresql://([^?]+)$") {
    $dbUrl = $Matches[0]
    if ($dbUrl -notmatch "connection_limit") {
        $newDbUrl = $dbUrl + "?connection_limit=10&pool_timeout=20&connect_timeout=10"
        $envContent = $envContent -replace [regex]::Escape($dbUrl), $newDbUrl
        Log "OK" "Dodano connection pool do DATABASE_URL (limit=10)"
    }
}

if ($envAdditions.Count -gt 0) {
    $additions = "`n# Optymalizacje Node.js`n" + ($envAdditions -join "`n")
    Add-Content $envPath $additions
}

# ─── KROK 5: Weryfikacja po optymalizacji ─────────────────
Write-Host "[ 5/6 ] Restart backendu z nowymi ustawieniami..." -ForegroundColor Yellow

$nodeProcs = Get-Process node -ErrorAction SilentlyContinue
if ($nodeProcs) {
    Log "INFO" "Zatrzymuję $($nodeProcs.Count) procesów Node.js..."
    $nodeProcs | Stop-Process -Force
    Start-Sleep -Seconds 2
    Log "OK" "Procesy zatrzymane"
}

Log "INFO" "Uruchamiam backend z optymalizacjami..."
$backendCmd = "cd '$backend'; & '$npmCmd' run dev"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd -WindowStyle Normal

Log "INFO" "Czekam 8s na start..."
Start-Sleep -Seconds 8

# ─── KROK 6: Porównanie metryk po optymalizacji ───────────
Write-Host "[ 6/6 ] Porównanie metryk przed/po..." -ForegroundColor Yellow

Start-Sleep -Seconds 5
try {
    $metricsAfter = Invoke-WebRequest -Uri "http://localhost:3001/metrics" -TimeoutSec 5 -ErrorAction Stop
    $textAfter = $metricsAfter.Content

    $elLagAfter  = [math]::Round([double]([regex]::Match($textAfter, 'nodejs_eventloop_lag_seconds\s+([\d.]+)').Groups[1].Value) * 1000, 2)
    $elMaxAfter  = [math]::Round([double]([regex]::Match($textAfter, 'nodejs_eventloop_lag_max_seconds\s+([\d.]+)').Groups[1].Value) * 1000, 2)
    $heapUAfter  = [double]([regex]::Match($textAfter, 'nodejs_heap_size_used_bytes\s+([\d.]+)').Groups[1].Value)
    $heapTAfter  = [double]([regex]::Match($textAfter, 'nodejs_heap_size_total_bytes\s+([\d.]+)').Groups[1].Value)
    $heapPAfter  = [math]::Round(($heapUAfter / $heapTAfter) * 100, 1)
    $rssMBAfter  = [math]::Round([double]([regex]::Match($textAfter, 'process_resident_memory_bytes\s+([\d.]+)').Groups[1].Value) / 1MB, 1)

    Write-Host ""
    Write-Host "  📊 PORÓWNANIE METRYK:" -ForegroundColor White
    Write-Host "  ┌─────────────────────┬──────────────┬──────────────┬──────────┐" -ForegroundColor DarkGray
    Write-Host "  │ Metryka             │ Przed        │ Po           │ Zmiana   │" -ForegroundColor DarkGray
    Write-Host "  ├─────────────────────┼──────────────┼──────────────┼──────────┤" -ForegroundColor DarkGray

    function CompRow($name, $before, $after, $unit, $lowerBetter=$true) {
        $diff = $after - $before
        $pct = if($before -ne 0){[math]::Round($diff/$before*100,0)}else{0}
        $better = if($lowerBetter){$diff -lt 0}else{$diff -gt 0}
        $col = if($better){"Green"}elseif([math]::Abs($pct) -lt 5){"White"}else{"Yellow"}
        $arrow = if($diff -lt 0){"↓"}elseif($diff -gt 0){"↑"}else{"="}
        $pctStr = "${arrow}${pct}%"
        Write-Host ("  │ {0,-19} │ {1,-12} │ {2,-12} │ {3,-8} │" -f $name, "${before}${unit}", "${after}${unit}", $pctStr) -ForegroundColor $col
    }

    CompRow "EL Lag"      $elLagMs  $elLagAfter  "ms"
    CompRow "EL Lag max"  $elMaxMs  $elMaxAfter  "ms"
    CompRow "Heap %"      $heapPct  $heapPAfter  "%"
    CompRow "RSS"         $rssMB    $rssMBAfter  "MB"
    Write-Host "  └─────────────────────┴──────────────┴──────────────┴──────────┘" -ForegroundColor DarkGray

} catch {
    Log "WARN" "Nie można pobrać metryk po optymalizacji — sprawdź okno backendu"
}

# ─── PODSUMOWANIE ─────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║    ✅ OPTYMALIZACJA ZAKOŃCZONA                       ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Zastosowane optymalizacje:" -ForegroundColor Cyan
Write-Host "  • --max-old-space-size=$optimalHeap (heap limit)" -ForegroundColor White
Write-Host "  • --expose-gc (ręczny GC dostępny)" -ForegroundColor White
Write-Host "  • UV_THREADPOOL_SIZE=16 (więcej wątków I/O)" -ForegroundColor White
Write-Host "  • Connection pool PostgreSQL (limit=10)" -ForegroundColor White
Write-Host "  • el-optimization.ts (EL monitor + cache)" -ForegroundColor White
Write-Host ""
Write-Host "  Następne kroki:" -ForegroundColor Cyan
Write-Host "  1. Monitoruj metryki: http://localhost:3001/metrics" -ForegroundColor White
Write-Host "  2. Otwórz panel:      E:\Grazyna_5.0\GRAZYNA_LIVE_PANEL.html" -ForegroundColor White
Write-Host "  3. Jeśli heap >85%:   rozważ --max-old-space-size=512" -ForegroundColor White
Write-Host "  4. Jeśli EL >50ms:    sprawdź synchroniczne operacje" -ForegroundColor White
Write-Host ""