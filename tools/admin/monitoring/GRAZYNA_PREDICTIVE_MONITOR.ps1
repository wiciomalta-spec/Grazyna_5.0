# ============================================================
# GRAŻYNA 5.0 — PREDICTIVE MONITOR Z PREDYKCJĄ AWARII
# Oparty na rzeczywistych metrykach:
#   Heap: 91.1% (old space 94%, code 97%, large_obj 100%)
#   EL Lag: 1.58ms (max 35ms)
#   GC Minor: ×26
# ============================================================

$proj      = "E:\Grazyna_5.0"
$logFile   = "$proj\logs\predict_monitor.log"
$alertFile = "$proj\logs\predictions.json"
$interval  = 10  # sekund

# Upewnij się że katalog logów istnieje
if (-not (Test-Path "$proj\logs")) { New-Item -ItemType Directory "$proj\logs" -Force | Out-Null }

# ─── HISTORIA METRYK ──────────────────────────────────────
$history   = @{}
$WINDOW    = 20
$alerts    = [System.Collections.Generic.List[object]]::new()
$iteration = 0
$startTime = Get-Date

# ─── FUNKCJE POMOCNICZE ───────────────────────────────────
function Log($level, $msg) {
    $ts  = (Get-Date).ToString("HH:mm:ss")
    $col = switch($level) { "OK"{"Green"}; "WARN"{"Yellow"}; "ERR"{"Red"}; "INFO"{"Cyan"}; "PRED"{"Magenta"} }
    $ico = switch($level) { "OK"{"✅"}; "WARN"{"⚠️"}; "ERR"{"❌"}; "INFO"{"ℹ️"}; "PRED"{"🔮"} }
    $line = "[$ts] $ico [$level] $msg"
    Write-Host $line -ForegroundColor $col
    Add-Content $logFile $line -ErrorAction SilentlyContinue
}

function Add-DataPoint($key, $val) {
    if (-not $history.ContainsKey($key)) {
        $history[$key] = [System.Collections.Generic.List[double]]::new()
    }
    $history[$key].Add([double]$val)
    if ($history[$key].Count -gt ($WINDOW * 3)) {
        $history[$key].RemoveAt(0)
    }
}

function Get-LinearTrend($key) {
    $pts = $history[$key]
    if (-not $pts -or $pts.Count -lt 5) { return 0.0 }
    $recent = @($pts | Select-Object -Last $WINDOW)
    $n = $recent.Count
    $xs = 0..($n - 1)
    $sumX  = ($xs | Measure-Object -Sum).Sum
    $sumY  = ($recent | Measure-Object -Sum).Sum
    $sumXY = 0; for ($i = 0; $i -lt $n; $i++) { $sumXY += $xs[$i] * $recent[$i] }
    $sumX2 = ($xs | ForEach-Object { $_ * $_ } | Measure-Object -Sum).Sum
    $denom = $n * $sumX2 - $sumX * $sumX
    if ($denom -eq 0) { return 0.0 }
    return ($n * $sumXY - $sumX * $sumY) / $denom
}

function Get-ZScore($key, $val) {
    $pts = $history[$key]
    if (-not $pts -or $pts.Count -lt 5) { return 0.0 }
    $recent = @($pts | Select-Object -Last $WINDOW)
    $mean = ($recent | Measure-Object -Sum).Sum / $recent.Count
    $variance = ($recent | ForEach-Object { ($_ - $mean) * ($_ - $mean) } | Measure-Object -Sum).Sum / $recent.Count
    $std = [math]::Sqrt($variance)
    if ($std -eq 0) { return 0.0 }
    return ($val - $mean) / $std
}

function Get-TimeToThreshold($key, $threshold) {
    $pts = $history[$key]
    if (-not $pts -or $pts.Count -lt 5) { return "N/A" }
    $current = $pts[$pts.Count - 1]
    $trend   = Get-LinearTrend $key
    if ($trend -le 0.001) { return "∞ (stabilny)" }
    $stepsNeeded = ($threshold - $current) / $trend
    if ($stepsNeeded -le 0) { return "JUŻ PRZEKROCZONY" }
    $seconds = [math]::Round($stepsNeeded * $interval)
    if ($seconds -lt 60)   { return "${seconds}s" }
    if ($seconds -lt 3600) { return "$([math]::Round($seconds/60))min" }
    return "$([math]::Round($seconds/3600,1))h"
}

function Get-Prediction($key, $stepsAhead = 6) {
    $pts = $history[$key]
    if (-not $pts -or $pts.Count -lt 10) { return $null }
    $recent = @($pts | Select-Object -Last $WINDOW)
    $n = $recent.Count
    $trend = Get-LinearTrend $key
    $lastVal = $recent[$n - 1]
    return [math]::Round($lastVal + $trend * $stepsAhead, 2)
}

function Get-TrendIcon($trend) {
    if ($trend -gt 0.5)  { return "↗↗" }
    if ($trend -gt 0.1)  { return "↗" }
    if ($trend -lt -0.5) { return "↘↘" }
    if ($trend -lt -0.1) { return "↘" }
    return "→"
}

# ─── POBIERZ METRYKI Z /metrics ───────────────────────────
function Get-BackendMetrics {
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:3001/metrics" -TimeoutSec 4 -ErrorAction Stop
        $t = $r.Content

        function ParseMetric($pattern) {
            $m = [regex]::Match($t, $pattern)
            if ($m.Success) { return [double]$m.Groups[1].Value }
            return 0.0
        }

        return @{
            ok             = $true
            heap_used      = ParseMetric 'nodejs_heap_size_used_bytes\s+([\d.]+)'
            heap_total     = ParseMetric 'nodejs_heap_size_total_bytes\s+([\d.]+)'
            rss            = ParseMetric 'process_resident_memory_bytes\s+([\d.]+)'
            el_lag         = ParseMetric 'nodejs_eventloop_lag_seconds\s+([\d.]+)'
            el_max         = ParseMetric 'nodejs_eventloop_lag_max_seconds\s+([\d.]+)'
            el_p99         = ParseMetric 'nodejs_eventloop_lag_p99_seconds\s+([\d.]+)'
            el_mean        = ParseMetric 'nodejs_eventloop_lag_mean_seconds\s+([\d.]+)'
            cpu_user       = ParseMetric 'process_cpu_user_seconds_total\s+([\d.]+)'
            cpu_sys        = ParseMetric 'process_cpu_system_seconds_total\s+([\d.]+)'
            external       = ParseMetric 'nodejs_external_memory_bytes\s+([\d.]+)'
            gc_minor_count = ParseMetric 'nodejs_gc_duration_seconds_count\{[^}]*kind="minor"[^}]*\}\s+([\d.]+)'
            gc_major_count = ParseMetric 'nodejs_gc_duration_seconds_count\{[^}]*kind="major"[^}]*\}\s+([\d.]+)'
            old_used       = ParseMetric 'nodejs_heap_space_size_used_bytes\{space="old"\}\s+([\d.]+)'
            old_total      = ParseMetric 'nodejs_heap_space_size_total_bytes\{space="old"\}\s+([\d.]+)'
            code_used      = ParseMetric 'nodejs_heap_space_size_used_bytes\{space="code"\}\s+([\d.]+)'
            code_total     = ParseMetric 'nodejs_heap_space_size_total_bytes\{space="code"\}\s+([\d.]+)'
            large_used     = ParseMetric 'nodejs_heap_space_size_used_bytes\{space="large_object"\}\s+([\d.]+)'
            large_total    = ParseMetric 'nodejs_heap_space_size_total_bytes\{space="large_object"\}\s+([\d.]+)'
        }
    } catch {
        return @{ ok = $false }
    }
}

# ─── REGUŁY PREDYKCJI AWARII ──────────────────────────────
$RULES = @(
    @{ name="Heap OOM";         key="heap_pct";    threshold=95;  severity="CRITICAL"; action="Wymuś GC lub restart backendu" }
    @{ name="Old Space Full";   key="old_pct";     threshold=98;  severity="CRITICAL"; action="Zwiększ --max-old-space-size=512" }
    @{ name="EL Lag spike";     key="el_max_ms";   threshold=200; severity="HIGH";     action="Sprawdź synchroniczne operacje" }
    @{ name="RSS leak";         key="rss_mb";      threshold=200; severity="HIGH";     action="Sprawdź wycieki pamięci (--inspect)" }
    @{ name="GC pressure";      key="gc_minor";    threshold=50;  severity="MEDIUM";   action="Zwiększ heap lub zoptymalizuj alokacje" }
    @{ name="EL Lag p99 high";  key="el_p99_ms";   threshold=50;  severity="MEDIUM";   action="Sprawdź middleware blokujące EL" }
)

# ─── GŁÓWNA PĘTLA ─────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║    🔮 GRAŻYNA 5.0 — PREDICTIVE MONITOR                   ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "  Próbkowanie co ${interval}s | Okno: $WINDOW próbek | Ctrl+C aby zatrzymać" -ForegroundColor Gray
Write-Host ""

$prevGcMinor = 0
$prevGcMajor = 0

while ($true) {
    $iteration++
    $ts = (Get-Date).ToString("HH:mm:ss")
    $uptime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)

    $m = Get-BackendMetrics

    if (-not $m.ok) {
        Write-Host ""
        Write-Host "[$ts] ❌ Backend niedostępny — sprawdź czy działa na :3001" -ForegroundColor Red
        Write-Host "  Uruchom: cmd /k `"cd /d E:\Grazyna_5.0\backend && E:\Grazyna_5.0\tools\nodejs\node.exe dist\index.js`"" -ForegroundColor Yellow
        Start-Sleep $interval
        continue
    }

    # Oblicz pochodne metryki
    $heapPct   = if ($m.heap_total -gt 0) { [math]::Round($m.heap_used / $m.heap_total * 100, 1) } else { 0 }
    $oldPct    = if ($m.old_total -gt 0)  { [math]::Round($m.old_used  / $m.old_total  * 100, 1) } else { 0 }
    $codePct   = if ($m.code_total -gt 0) { [math]::Round($m.code_used / $m.code_total * 100, 1) } else { 0 }
    $largePct  = if ($m.large_total -gt 0){ [math]::Round($m.large_used/ $m.large_total* 100, 1) } else { 0 }
    $rssMB     = [math]::Round($m.rss / 1MB, 1)
    $elMs      = [math]::Round($m.el_lag * 1000, 2)
    $elMaxMs   = [math]::Round($m.el_max * 1000, 1)
    $elP99Ms   = [math]::Round($m.el_p99 * 1000, 1)
    $gcMinorNew = [math]::Max(0, $m.gc_minor_count - $prevGcMinor)
    $gcMajorNew = [math]::Max(0, $m.gc_major_count - $prevGcMajor)
    $prevGcMinor = $m.gc_minor_count
    $prevGcMajor = $m.gc_major_count

    # Dodaj do historii
    Add-DataPoint "heap_pct"  $heapPct
    Add-DataPoint "old_pct"   $oldPct
    Add-DataPoint "rss_mb"    $rssMB
    Add-DataPoint "el_lag_ms" $elMs
    Add-DataPoint "el_max_ms" $elMaxMs
    Add-DataPoint "el_p99_ms" $elP99Ms
    Add-DataPoint "gc_minor"  $m.gc_minor_count

    # Trendy
    $heapTrend = Get-LinearTrend "heap_pct"
    $elTrend   = Get-LinearTrend "el_max_ms"
    $rssTrend  = Get-LinearTrend "rss_mb"

    # Predykcje (za 60s = 6 próbek)
    $heapPred  = Get-Prediction "heap_pct"
    $elPred    = Get-Prediction "el_max_ms"

    # Z-scores (anomalie)
    $heapZ = Get-ZScore "heap_pct"  $heapPct
    $elZ   = Get-ZScore "el_max_ms" $elMaxMs

    # TTT (Time To Threshold)
    $heapTTT = Get-TimeToThreshold "heap_pct"  95
    $oldTTT  = Get-TimeToThreshold "old_pct"   98
    $rssTTT  = Get-TimeToThreshold "rss_mb"    200

    # ─── WYŚWIETL DASHBOARD ───────────────────────────────
    Write-Host ""
    Write-Host "─── #$iteration @ $ts (uptime: ${uptime}min) ─────────────────────────" -ForegroundColor DarkCyan

    # Heap
    $heapCol = if($heapPct -gt 93){"Red"}elseif($heapPct -gt 88){"Yellow"}else{"Green"}
    $heapTrendIcon = Get-TrendIcon $heapTrend
    $heapPredStr = if($heapPred){"→ pred: ${heapPred}%"}else{""}
    Write-Host ("  🧠 Heap:     {0,5}%  {1}  TTT→95%: {2,-12} {3}" -f $heapPct, $heapTrendIcon, $heapTTT, $heapPredStr) -ForegroundColor $heapCol

    # Heap spaces
    $oldCol  = if($oldPct  -gt 95){"Red"}elseif($oldPct  -gt 90){"Yellow"}else{"Green"}
    $codeCol = if($codePct -gt 95){"Red"}elseif($codePct -gt 90){"Yellow"}else{"Green"}
    Write-Host ("  📦 Old:      {0,5}%  TTT→98%: {1,-12}" -f $oldPct, $oldTTT) -ForegroundColor $oldCol
    Write-Host ("  💻 Code:     {0,5}%  Large: {1}%" -f $codePct, $largePct) -ForegroundColor $codeCol

    # EL Lag
    $elCol = if($elMaxMs -gt 100){"Red"}elseif($elMaxMs -gt 50){"Yellow"}else{"Green"}
    $elTrendIcon = Get-TrendIcon $elTrend
    $elPredStr = if($elPred){"→ pred: ${elPred}ms"}else{""}
    Write-Host ("  🔄 EL Lag:   {0,5}ms  max: {1}ms  p99: {2}ms  {3}  {4}" -f $elMs, $elMaxMs, $elP99Ms, $elTrendIcon, $elPredStr) -ForegroundColor $elCol

    # RSS
    $rssCol = if($rssMB -gt 150){"Red"}elseif($rssMB -gt 100){"Yellow"}else{"Green"}
    $rssTrendIcon = Get-TrendIcon $rssTrend
    Write-Host ("  💾 RSS:      {0,5}MB  {1}  TTT→200MB: {2}" -f $rssMB, $rssTrendIcon, $rssTTT) -ForegroundColor $rssCol

    # GC
    $gcStr = "Minor: $([int]$m.gc_minor_count)× (+$gcMinorNew)  Major: $([int]$m.gc_major_count)×"
    if ($gcMajorNew -gt 0) {
        Write-Host "  🗑️  GC:       $gcStr" -ForegroundColor Yellow
    } else {
        Write-Host "  🗑️  GC:       $gcStr" -ForegroundColor Gray
    }

    # Anomalie (Z-score)
    if ([math]::Abs($heapZ) -gt 2.5) {
        Write-Host "  🚨 ANOMALIA: Heap Z-score=$([math]::Round($heapZ,1)) — niezwykły skok!" -ForegroundColor Red
    }
    if ([math]::Abs($elZ) -gt 2.5) {
        Write-Host "  🚨 ANOMALIA: EL Lag Z-score=$([math]::Round($elZ,1)) — spike!" -ForegroundColor Red
    }

    # ─── SPRAWDŹ REGUŁY PREDYKCJI ─────────────────────────
    $currentAlerts = @()
    foreach ($rule in $RULES) {
        $val = switch($rule.key) {
            "heap_pct"  { $heapPct }
            "old_pct"   { $oldPct }
            "el_max_ms" { $elMaxMs }
            "rss_mb"    { $rssMB }
            "gc_minor"  { $m.gc_minor_count }
            "el_p99_ms" { $elP99Ms }
            default     { 0 }
        }

        if ($val -ge $rule.threshold) {
            $alertCol = if($rule.severity -eq "CRITICAL"){"Red"}elseif($rule.severity -eq "HIGH"){"Yellow"}else{"DarkYellow"}
            Write-Host "  🔴 [$($rule.severity)] $($rule.name): $val >= $($rule.threshold)" -ForegroundColor $alertCol
            Write-Host "     Akcja: $($rule.action)" -ForegroundColor Gray
            $currentAlerts += $rule.name
        } else {
            # Predykcja — czy zbliżamy się do progu?
            $ttt = Get-TimeToThreshold $rule.key $rule.threshold
            if ($ttt -ne "N/A" -and $ttt -ne "∞ (stabilny)" -and $ttt -ne "JUŻ PRZEKROCZONY") {
                # Parsuj TTT do sekund
                $tttSec = 9999
                if ($ttt -match "^(\d+)s$")   { $tttSec = [int]$Matches[1] }
                if ($ttt -match "^(\d+)min$")  { $tttSec = [int]$Matches[1] * 60 }
                if ($tttSec -lt 300) {  # < 5 minut
                    Write-Host "  🔮 PREDYKCJA: $($rule.name) przekroczy próg za $ttt!" -ForegroundColor Magenta
                    Write-Host "     Akcja prewencyjna: $($rule.action)" -ForegroundColor Gray
                }
            }
        }
    }

    # ─── REKOMENDACJE ─────────────────────────────────────
    if ($heapPct -gt 90 -and $iteration -eq 1) {
        Write-Host ""
        Write-Host "  💡 REKOMENDACJE (jednorazowe):" -ForegroundColor Cyan
        Write-Host "     1. Dodaj --max-old-space-size=256 do node flags" -ForegroundColor White
        Write-Host "     2. Sprawdź Large Object Space (100% pełny)" -ForegroundColor White
        Write-Host "     3. Rozważ lazy loading Prisma client" -ForegroundColor White
    }

    # ─── ZAPISZ PREDYKCJE DO JSON ─────────────────────────
    if ($iteration % 6 -eq 0) {  # co 60s
        $prediction = @{
            timestamp  = (Get-Date -Format "o")
            iteration  = $iteration
            current    = @{ heap_pct=$heapPct; el_max_ms=$elMaxMs; rss_mb=$rssMB }
            predicted  = @{ heap_pct=$heapPred; el_max_ms=$elPred }
            ttt        = @{ heap_95=$heapTTT; old_98=$oldTTT; rss_200=$rssTTT }
            alerts     = $currentAlerts
        }
        $prediction | ConvertTo-Json | Set-Content $alertFile -ErrorAction SilentlyContinue
        Write-Host "  💾 Predykcje zapisane do logs/predictions.json" -ForegroundColor DarkGray
    }

    Start-Sleep $interval
}