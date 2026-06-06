# ============================================================
# GRAŻYNA 5.0 — Uruchom k6 + Analiza wyników + IsoForest Live
# Wklej do PowerShell i uruchom
# ============================================================
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

$proj    = "E:\Grazyna_5.0"
$k6File  = "$proj\GRAZYNA_K6_LOADTEST.js"
$results = "$proj\logs\k6_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$report  = "$proj\logs\k6_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

if (-not (Test-Path "$proj\logs")) { New-Item -ItemType Directory "$proj\logs" -Force | Out-Null }

function L($level, $msg) {
    $col = switch($level) { "OK"{"Green"}; "WARN"{"Yellow"}; "ERR"{"Red"}; "INFO"{"Cyan"} }
    $ico = switch($level) { "OK"{"✅"}; "WARN"{"⚠️"}; "ERR"{"❌"}; "INFO"{"ℹ️"} }
    Write-Host "  $ico $msg" -ForegroundColor $col
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   GRAŻYNA 5.0 — k6 Load Test + Analiza                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─── KROK 1: Sprawdź k6 ───────────────────────────────────
Write-Host "[ 1/5 ] Sprawdzam k6..." -ForegroundColor Yellow
$k6Path = Get-Command k6 -ErrorAction SilentlyContinue
if (-not $k6Path) {
    L "WARN" "k6 nie znaleziony — instaluję..."
    winget install k6 --source winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    $k6Path = Get-Command k6 -ErrorAction SilentlyContinue
    if (-not $k6Path) {
        L "ERR" "k6 instalacja nieudana. Zainstaluj ręcznie: winget install k6"
        L "INFO" "Lub pobierz z: https://k6.io/docs/get-started/installation/"
        exit 1
    }
}
$k6Ver = k6 version 2>&1
L "OK" "k6 dostępny: $k6Ver"

# ─── KROK 2: Sprawdź backend ──────────────────────────────
Write-Host "[ 2/5 ] Sprawdzam backend..." -ForegroundColor Yellow
try {
    $h = Invoke-RestMethod "http://localhost:3001/health" -TimeoutSec 5
    L "OK" "Backend: status=$($h.status) uptime=$($h.uptime)"
} catch {
    L "ERR" "Backend nie odpowiada na :3001!"
    L "INFO" "Uruchom: cmd /k `"cd /d E:\Grazyna_5.0\backend && node --max-old-space-size=256 node_modules\tsx\dist\cli.mjs watch src\cluster-bootstrap.ts`""
    exit 1
}

# ─── KROK 3: Pobierz metryki PRZED testem ─────────────────
Write-Host "[ 3/5 ] Metryki przed testem..." -ForegroundColor Yellow
function Get-Metrics {
    try {
        $r = Invoke-WebRequest "http://localhost:3001/metrics" -TimeoutSec 4 -ErrorAction Stop
        $t = $r.Content
        function PM($p) { $m=[regex]::Match($t,$p); if($m.Success){return [double]$m.Groups[1].Value}; return 0.0 }
        $hu = PM 'nodejs_heap_size_used_bytes\s+([\d.]+)'
        $ht = PM 'nodejs_heap_size_total_bytes\s+([\d.]+)'
        return @{
            heapPct = if($ht-gt 0){[math]::Round($hu/$ht*100,1)}else{0}
            rssMB   = [math]::Round((PM 'process_resident_memory_bytes\s+([\d.]+)')/1MB,1)
            elMs    = [math]::Round((PM 'nodejs_eventloop_lag_seconds\s+([\d.]+)')*1000,2)
            elMaxMs = [math]::Round((PM 'nodejs_eventloop_lag_max_seconds\s+([\d.]+)')*1000,1)
        }
    } catch { return @{ heapPct=0; rssMB=0; elMs=0; elMaxMs=0 } }
}

$before = Get-Metrics
Write-Host ("  Heap: {0}% | RSS: {1}MB | EL: {2}ms | EL max: {3}ms" -f `
    $before.heapPct, $before.rssMB, $before.elMs, $before.elMaxMs) -ForegroundColor Cyan

# ─── KROK 4: Uruchom k6 (smoke test najpierw) ─────────────
Write-Host "[ 4/5 ] Uruchamiam k6 (smoke → load)..." -ForegroundColor Yellow
Write-Host "  Czas trwania: ~5 minut (wszystkie scenariusze)" -ForegroundColor Gray
Write-Host "  Ctrl+C aby przerwać" -ForegroundColor Gray
Write-Host ""

# Uruchom k6 z JSON output
$k6Cmd = "k6 run --out json=`"$results`" `"$k6File`" 2>&1"
$k6Output = @()
$k6Process = Start-Process k6 -ArgumentList "run", "--out", "json=`"$results`"", "`"$k6File`"" -PassThru -NoNewWindow -Wait

# Alternatywnie — szybki smoke test (30s)
Write-Host ""
Write-Host "  Uruchamiam szybki smoke test (30s, 5 VUs)..." -ForegroundColor Cyan
$smokeOut = k6 run --vus 5 --duration 30s $k6File 2>&1
$smokeOut | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

# ─── KROK 5: Pobierz metryki PO teście i analiza ──────────
Write-Host ""
Write-Host "[ 5/5 ] Analiza wyników..." -ForegroundColor Yellow

$after = Get-Metrics
Write-Host ""
Write-Host "  📊 PORÓWNANIE METRYK PRZED/PO k6:" -ForegroundColor White
Write-Host ("  Heap:   {0}% → {1}%  ({2:+0.1f}pp)" -f $before.heapPct, $after.heapPct, ($after.heapPct - $before.heapPct)) -ForegroundColor $(if(($after.heapPct-$before.heapPct) -gt 5){"Yellow"}else{"Green"})
Write-Host ("  RSS:    {0}MB → {1}MB  ({2:+0.1f}MB)" -f $before.rssMB, $after.rssMB, ($after.rssMB - $before.rssMB)) -ForegroundColor Cyan
Write-Host ("  EL Lag: {0}ms → {1}ms" -f $before.elMs, $after.elMs) -ForegroundColor $(if($after.elMs -gt 50){"Yellow"}else{"Green"})
Write-Host ("  EL Max: {0}ms → {1}ms" -f $before.elMaxMs, $after.elMaxMs) -ForegroundColor $(if($after.elMaxMs -gt 200){"Red"}elseif($after.elMaxMs -gt 100){"Yellow"}else{"Green"})

# Parsuj wyniki k6 z output
$k6Summary = $smokeOut | Select-String "http_req_duration|http_reqs|error_rate|checks"
Write-Host ""
Write-Host "  📈 k6 METRYKI:" -ForegroundColor White
$k6Summary | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }

# Zapisz raport
$reportContent = @"
GRAŻYNA 5.0 — k6 Load Test Report
$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

METRYKI PRZED TESTEM:
  Heap:   $($before.heapPct)%
  RSS:    $($before.rssMB) MB
  EL Lag: $($before.elMs) ms
  EL Max: $($before.elMaxMs) ms

METRYKI PO TEŚCIE:
  Heap:   $($after.heapPct)%
  RSS:    $($after.rssMB) MB
  EL Lag: $($after.elMs) ms
  EL Max: $($after.elMaxMs) ms

k6 OUTPUT:
$($smokeOut -join "`n")
"@
$reportContent | Out-File $report -Encoding UTF8
L "OK" "Raport zapisany: $report"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✅ k6 TEST ZAKOŃCZONY                                  ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Następne kroki:" -ForegroundColor Cyan
Write-Host "  1. Uruchom IsoForest vs EWMA live:" -ForegroundColor White
Write-Host "     Start-Process powershell -ArgumentList '-File E:\Grazyna_5.0\GRAZYNA_ISOFOREST_VS_EWMA_LIVE.ps1'" -ForegroundColor Gray
Write-Host "  2. Pełny test (wszystkie scenariusze ~6min):" -ForegroundColor White
Write-Host "     k6 run E:\Grazyna_5.0\GRAZYNA_K6_LOADTEST.js" -ForegroundColor Gray
Write-Host "  3. Stress test:" -ForegroundColor White
Write-Host "     k6 run --vus 100 --duration 60s E:\Grazyna_5.0\GRAZYNA_K6_LOADTEST.js" -ForegroundColor Gray
Write-Host ""