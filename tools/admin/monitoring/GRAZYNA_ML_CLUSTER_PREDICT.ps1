# ============================================================
# GRAŻYNA 5.0 — ML PREDYKCJA AWARII KLASTRA
# Algorytmy: EWMA + Z-Score + Linear Regression + Isolation Forest
# Dane: metryki z /metrics + /api/system/workers
# Uruchom: Start-Process powershell -ArgumentList "-File E:\Grazyna_5.0\GRAZYNA_ML_CLUSTER_PREDICT.ps1"
# ============================================================

$proj    = "E:\Grazyna_5.0"
$logFile = "$proj\logs\ml_predict_$(Get-Date -Format 'yyyyMMdd').log"
$jsonOut = "$proj\logs\ml_predictions.json"
$interval = 10  # sekund

if (-not (Test-Path "$proj\logs")) { New-Item -ItemType Directory "$proj\logs" -Force | Out-Null }

# ─── STRUKTURY DANYCH ─────────────────────────────────────
$metrics = @{
    heap_pct    = [System.Collections.Generic.List[double]]::new()
    el_lag_ms   = [System.Collections.Generic.List[double]]::new()
    el_max_ms   = [System.Collections.Generic.List[double]]::new()
    rss_mb      = [System.Collections.Generic.List[double]]::new()
    gc_minor    = [System.Collections.Generic.List[double]]::new()
    gc_major    = [System.Collections.Generic.List[double]]::new()
    workers_busy= [System.Collections.Generic.List[double]]::new()
    req_rate    = [System.Collections.Generic.List[double]]::new()
    cpu_total   = [System.Collections.Generic.List[double]]::new()
}

$WINDOW     = 30   # próbek w oknie analizy
$ewmaState  = @{}  # stan EWMA per metryka
$EWMA_ALPHA = 0.3  # współczynnik wygładzania

# ─── ALGORYTMY ML ─────────────────────────────────────────

# 1. EWMA — Exponentially Weighted Moving Average
function Update-EWMA($key, $value) {
    if (-not $ewmaState.ContainsKey($key)) {
        $ewmaState[$key] = @{ ewma = $value; variance = 0.0 }
        return @{ smoothed = $value; anomalyScore = 0.0; isAnomaly = $false }
    }
    $prev = $ewmaState[$key].ewma
    $newEwma = $EWMA_ALPHA * $value + (1 - $EWMA_ALPHA) * $prev
    $diff = $value - $prev
    $newVar = 0.1 * $diff * $diff + 0.9 * $ewmaState[$key].variance
    $ewmaState[$key].ewma = $newEwma
    $ewmaState[$key].variance = $newVar
    $std = [math]::Sqrt($newVar)
    $score = if ($std -gt 0) { [math]::Abs($value - $newEwma) / $std } else { 0 }
    return @{
        smoothed     = [math]::Round($newEwma, 3)
        anomalyScore = [math]::Round($score, 2)
        isAnomaly    = $score -gt 2.5
    }
}

# 2. Linear Regression — trend i TTT
function Get-LinearRegression($data) {
    $n = $data.Count
    if ($n -lt 5) { return @{ slope = 0; intercept = 0; r2 = 0 } }
    $recent = @($data | Select-Object -Last $WINDOW)
    $n = $recent.Count
    $xs = 0..($n-1)
    $sumX  = ($xs | Measure-Object -Sum).Sum
    $sumY  = ($recent | Measure-Object -Sum).Sum
    $sumXY = 0; for ($i=0;$i -lt $n;$i++) { $sumXY += $xs[$i]*$recent[$i] }
    $sumX2 = ($xs | ForEach-Object {$_*$_} | Measure-Object -Sum).Sum
    $denom = $n*$sumX2 - $sumX*$sumX
    if ($denom -eq 0) { return @{ slope=0; intercept=$sumY/$n; r2=0 } }
    $slope     = ($n*$sumXY - $sumX*$sumY) / $denom
    $intercept = ($sumY - $slope*$sumX) / $n
    # R² (goodness of fit)
    $meanY = $sumY / $n
    $ssTot = ($recent | ForEach-Object { ($_ - $meanY)*($_ - $meanY) } | Measure-Object -Sum).Sum
    $ssRes = 0; for ($i=0;$i -lt $n;$i++) { $pred=$slope*$xs[$i]+$intercept; $ssRes+=($recent[$i]-$pred)*($recent[$i]-$pred) }
    $r2 = if ($ssTot -gt 0) { 1 - $ssRes/$ssTot } else { 0 }
    return @{ slope=[math]::Round($slope,4); intercept=[math]::Round($intercept,3); r2=[math]::Round($r2,3) }
}

function Get-TTT($data, $threshold) {
    $reg = Get-LinearRegression $data
    if ($reg.slope -le 0.001) { return "∞" }
    $current = if ($data.Count -gt 0) { $data[$data.Count-1] } else { 0 }
    $steps = ($threshold - $current) / $reg.slope
    if ($steps -le 0) { return "JUŻ PRZEKROCZONY" }
    $sec = [math]::Round($steps * $interval)
    if ($sec -lt 60)   { return "${sec}s" }
    if ($sec -lt 3600) { return "$([math]::Round($sec/60))min" }
    return "$([math]::Round($sec/3600,1))h"
}

function Get-Prediction($data, $stepsAhead=6) {
    $reg = Get-LinearRegression $data
    $n = [math]::Min($data.Count, $WINDOW)
    return [math]::Round($reg.intercept + $reg.slope * ($n + $stepsAhead), 2)
}

# 3. Z-Score — wykrywanie anomalii statystycznych
function Get-ZScore($data, $value) {
    if ($data.Count -lt 5) { return 0 }
    $recent = @($data | Select-Object -Last $WINDOW)
    $mean = ($recent | Measure-Object -Sum).Sum / $recent.Count
    $variance = ($recent | ForEach-Object { ($_ - $mean)*($_ - $mean) } | Measure-Object -Sum).Sum / $recent.Count
    $std = [math]::Sqrt($variance)
    if ($std -eq 0) { return 0 }
    return [math]::Round(($value - $mean) / $std, 2)
}

# 4. Isolation Forest (uproszczony) — wielowymiarowe anomalie
function Get-IsolationScore($heapPct, $elMs, $rssMB, $gcMinor) {
    # Normalizuj do [0,1]
    $h = [math]::Min($heapPct / 100, 1.0)
    $e = [math]::Min($elMs / 200, 1.0)
    $r = [math]::Min($rssMB / 500, 1.0)
    $g = [math]::Min($gcMinor / 100, 1.0)
    # Odległość od "normalnego" centrum (0.7, 0.1, 0.3, 0.2)
    $dist = [math]::Sqrt(($h-0.7)*($h-0.7) + ($e-0.1)*($e-0.1) + ($r-0.3)*($r-0.3) + ($g-0.2)*($g-0.2))
    return [math]::Round($dist, 3)
}

# 5. Failure Probability — kombinacja wszystkich sygnałów
function Get-FailureProbability($signals) {
    $score = 0.0
    # Wagi dla każdego sygnału
    if ($signals.heapPct -gt 95)    { $score += 0.40 }
    elseif ($signals.heapPct -gt 90){ $score += 0.20 }
    elseif ($signals.heapPct -gt 85){ $score += 0.10 }

    if ($signals.elMaxMs -gt 500)   { $score += 0.30 }
    elseif ($signals.elMaxMs -gt 200){ $score += 0.15 }
    elseif ($signals.elMaxMs -gt 100){ $score += 0.05 }

    if ($signals.gcMajor -gt 5)     { $score += 0.15 }
    elseif ($signals.gcMajor -gt 2) { $score += 0.08 }

    if ($signals.ewmaAnomaly)       { $score += 0.10 }
    if ($signals.zScoreHigh)        { $score += 0.05 }
    if ($signals.isolationHigh)     { $score += 0.10 }

    # Trend rosnący heap
    if ($signals.heapTrend -gt 0.5) { $score += 0.10 }

    return [math]::Min([math]::Round($score, 3), 1.0)
}

# ─── POBIERZ METRYKI ──────────────────────────────────────
function Get-AllMetrics {
    $result = @{ ok = $false }
    try {
        # /metrics (Prometheus)
        $r = Invoke-WebRequest "http://localhost:3001/metrics" -TimeoutSec 4 -ErrorAction Stop
        $t = $r.Content
        function PM($pat) {
            $m = [regex]::Match($t, $pat)
            if ($m.Success) { return [double]$m.Groups[1].Value }
            return 0.0
        }
        $heapUsed  = PM 'nodejs_heap_size_used_bytes\s+([\d.]+)'
        $heapTotal = PM 'nodejs_heap_size_total_bytes\s+([\d.]+)'
        $result.heapPct   = if($heapTotal -gt 0){[math]::Round($heapUsed/$heapTotal*100,1)}else{0}
        $result.rssMB     = [math]::Round((PM 'process_resident_memory_bytes\s+([\d.]+)')/1MB,1)
        $result.elLagMs   = [math]::Round((PM 'nodejs_eventloop_lag_seconds\s+([\d.]+)')*1000,2)
        $result.elMaxMs   = [math]::Round((PM 'nodejs_eventloop_lag_max_seconds\s+([\d.]+)')*1000,1)
        $result.elP99Ms   = [math]::Round((PM 'nodejs_eventloop_lag_p99_seconds\s+([\d.]+)')*1000,1)
        $result.gcMinor   = [double](PM 'nodejs_gc_duration_seconds_count\{[^}]*kind="minor"[^}]*\}\s+([\d.]+)')
        $result.gcMajor   = [double](PM 'nodejs_gc_duration_seconds_count\{[^}]*kind="major"[^}]*\}\s+([\d.]+)')
        $result.cpuTotal  = [math]::Round((PM 'process_cpu_seconds_total\s+([\d.]+)'),3)
        $result.external  = [math]::Round((PM 'nodejs_external_memory_bytes\s+([\d.]+)')/1KB,0)

        # /api/system/workers
        try {
            $w = Invoke-RestMethod "http://localhost:3001/api/system/workers" -TimeoutSec 3
            $result.workersBusy    = $w.workerPool.busy
            $result.workersQueued  = $w.workerPool.queued
            $result.clusterWorkers = $w.clusterWorkers
        } catch {
            $result.workersBusy = 0; $result.workersQueued = 0; $result.clusterWorkers = 0
        }

        $result.ok = $true
    } catch { }
    return $result
}

# ─── GŁÓWNA PĘTLA ─────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║   🤖 GRAŻYNA 5.0 — ML CLUSTER FAILURE PREDICTOR          ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "  Algorytmy: EWMA + Z-Score + LinReg + Isolation Forest" -ForegroundColor Gray
Write-Host "  Próbkowanie: co ${interval}s | Okno: $WINDOW próbek" -ForegroundColor Gray
Write-Host "  Ctrl+C aby zatrzymać" -ForegroundColor Gray
Write-Host ""

$iteration  = 0
$startTime  = Get-Date
$prevGcMin  = 0
$prevGcMaj  = 0
$prevCpu    = 0
$alertCount = 0

while ($true) {
    $iteration++
    $ts     = (Get-Date).ToString("HH:mm:ss")
    $uptime = [math]::Round(((Get-Date)-$startTime).TotalMinutes,1)

    $m = Get-AllMetrics
    if (-not $m.ok) {
        Write-Host "[$ts] ❌ Backend niedostępny" -ForegroundColor Red
        Start-Sleep $interval; continue
    }

    # Przyrostowe GC i CPU
    $gcMinorDelta = [math]::Max(0, $m.gcMinor - $prevGcMin)
    $gcMajorDelta = [math]::Max(0, $m.gcMajor - $prevGcMaj)
    $cpuDelta     = [math]::Round([math]::Max(0, $m.cpuTotal - $prevCpu), 3)
    $prevGcMin = $m.gcMinor; $prevGcMaj = $m.gcMajor; $prevCpu = $m.cpuTotal

    # Dodaj do historii
    $metrics.heap_pct.Add($m.heapPct)
    $metrics.el_lag_ms.Add($m.elLagMs)
    $metrics.el_max_ms.Add($m.elMaxMs)
    $metrics.rss_mb.Add($m.rssMB)
    $metrics.gc_minor.Add($m.gcMinor)
    $metrics.gc_major.Add($m.gcMajor)
    $metrics.workers_busy.Add($m.workersBusy)
    $metrics.cpu_total.Add($cpuDelta)

    # Ogranicz historię
    foreach ($key in $metrics.Keys) {
        while ($metrics[$key].Count -gt $WINDOW*3) { $metrics[$key].RemoveAt(0) }
    }

    # ── ALGORYTMY ML ──────────────────────────────────────

    # EWMA
    $ewmaHeap = Update-EWMA "heap" $m.heapPct
    $ewmaEl   = Update-EWMA "el"   $m.elMaxMs
    $ewmaRss  = Update-EWMA "rss"  $m.rssMB

    # Z-Score
    $zHeap = Get-ZScore $metrics.heap_pct $m.heapPct
    $zEl   = Get-ZScore $metrics.el_max_ms $m.elMaxMs

    # Linear Regression
    $regHeap = Get-LinearRegression $metrics.heap_pct
    $regEl   = Get-LinearRegression $metrics.el_max_ms

    # TTT
    $tttHeap95 = Get-TTT $metrics.heap_pct 95
    $tttEl200  = Get-TTT $metrics.el_max_ms 200
    $tttRss200 = Get-TTT $metrics.rss_mb 200

    # Predykcje za 60s
    $predHeap = Get-Prediction $metrics.heap_pct 6
    $predEl   = Get-Prediction $metrics.el_max_ms 6

    # Isolation Forest
    $isoScore = Get-IsolationScore $m.heapPct $m.elMaxMs $m.rssMB $m.gcMinor

    # Failure Probability
    $signals = @{
        heapPct      = $m.heapPct
        elMaxMs      = $m.elMaxMs
        gcMajor      = $gcMajorDelta
        ewmaAnomaly  = $ewmaHeap.isAnomaly -or $ewmaEl.isAnomaly
        zScoreHigh   = [math]::Abs($zHeap) -gt 2.5 -or [math]::Abs($zEl) -gt 2.5
        isolationHigh= $isoScore -gt 0.5
        heapTrend    = $regHeap.slope
    }
    $failProb = Get-FailureProbability $signals

    # ── WYŚWIETL DASHBOARD ────────────────────────────────
    Write-Host ""
    Write-Host ("─── ML #$iteration @ $ts (uptime: ${uptime}min) ─────────────────────") -ForegroundColor DarkCyan

    # Failure Probability — główny wskaźnik
    $probPct = [math]::Round($failProb * 100)
    $probCol = if($probPct -gt 70){"Red"}elseif($probPct -gt 40){"Yellow"}else{"Green"}
    $probBar = "█" * [math]::Round($probPct/5) + "░" * (20 - [math]::Round($probPct/5))
    Write-Host ("  🤖 FAILURE PROB: [{0}] {1}%" -f $probBar, $probPct) -ForegroundColor $probCol

    # Metryki z ML
    $hCol = if($m.heapPct -gt 90){"Red"}elseif($m.heapPct -gt 80){"Yellow"}else{"Green"}
    $eCol = if($m.elMaxMs -gt 100){"Red"}elseif($m.elMaxMs -gt 50){"Yellow"}else{"Green"}

    Write-Host ("  🧠 Heap:  {0,5}%  EWMA:{1}%  Z:{2}  TTT→95%:{3}  pred60s:{4}%" -f `
        $m.heapPct, $ewmaHeap.smoothed, $zHeap, $tttHeap95, $predHeap) -ForegroundColor $hCol

    Write-Host ("  🔄 EL:    {0,5}ms max:{1}ms  EWMA:{2}ms  Z:{3}  TTT→200ms:{4}" -f `
        $m.elLagMs, $m.elMaxMs, $ewmaEl.smoothed, $zEl, $tttEl200) -ForegroundColor $eCol

    Write-Host ("  💾 RSS:   {0,5}MB  TTT→200MB:{1}  Ext:{2}KB" -f `
        $m.rssMB, $tttRss200, $m.external) -ForegroundColor Cyan

    Write-Host ("  🗑️  GC:    Minor+{0}  Major+{1}  CPU+{2}s" -f `
        $gcMinorDelta, $gcMajorDelta, $cpuDelta) -ForegroundColor Gray

    Write-Host ("  🔌 Workers: {0} busy/{1} cluster  Queued:{2}" -f `
        $m.workersBusy, $m.clusterWorkers, $m.workersQueued) -ForegroundColor Gray

    Write-Host ("  📐 LinReg: heap slope={0}/próbkę  R²={1}  IsoScore={2}" -f `
        $regHeap.slope, $regHeap.r2, $isoScore) -ForegroundColor DarkGray

    # ── ALERTY ML ─────────────────────────────────────────
    $alertsThisIter = @()

    if ($failProb -gt 0.7) {
        $alertsThisIter += "🔴 KRYTYCZNE: Failure probability ${probPct}% — rozważ restart!"
    } elseif ($failProb -gt 0.4) {
        $alertsThisIter += "🟡 OSTRZEŻENIE: Failure probability ${probPct}% — monitoruj"
    }

    if ($ewmaHeap.isAnomaly) {
        $alertsThisIter += "🚨 EWMA ANOMALIA: Heap spike! score=$($ewmaHeap.anomalyScore)"
    }
    if ($ewmaEl.isAnomaly) {
        $alertsThisIter += "🚨 EWMA ANOMALIA: EL Lag spike! score=$($ewmaEl.anomalyScore)"
    }
    if ([math]::Abs($zHeap) -gt 3) {
        $alertsThisIter += "📊 Z-SCORE: Heap Z=$zHeap (>3σ — ekstremalna anomalia!)"
    }
    if ($isoScore -gt 0.6) {
        $alertsThisIter += "🌲 ISOLATION: Wielowymiarowa anomalia! score=$isoScore"
    }
    if ($gcMajorDelta -gt 0) {
        $alertsThisIter += "🗑️  MAJOR GC: +$gcMajorDelta cykli — heap pressure!"
    }
    if ($tttHeap95 -ne "∞" -and $tttHeap95 -ne "N/A" -and $tttHeap95 -match "^\d+min$") {
        $mins = [int]($tttHeap95 -replace "min","")
        if ($mins -lt 10) {
            $alertsThisIter += "⏰ PREDYKCJA: Heap przekroczy 95% za $tttHeap95!"
        }
    }

    if ($alertsThisIter.Count -gt 0) {
        $alertCount++
        Write-Host ""
        $alertsThisIter | ForEach-Object { Write-Host "  $_" -ForegroundColor $(if($_ -match "KRYTYCZNE|ANOMALIA"){"Red"}else{"Yellow"}) }
    } else {
        Write-Host "  ✅ Wszystkie wskaźniki w normie" -ForegroundColor Green
    }

    # ── ZAPISZ PREDYKCJE DO JSON ──────────────────────────
    if ($iteration % 6 -eq 0) {
        $pred = @{
            timestamp    = (Get-Date -Format "o")
            iteration    = $iteration
            failureProbability = $failProb
            current      = @{ heapPct=$m.heapPct; elMaxMs=$m.elMaxMs; rssMB=$m.rssMB }
            predicted60s = @{ heapPct=$predHeap; elMaxMs=$predEl }
            ttt          = @{ heap95=$tttHeap95; el200=$tttEl200; rss200=$tttRss200 }
            regression   = @{ heapSlope=$regHeap.slope; heapR2=$regHeap.r2 }
            anomalies    = @{ ewmaHeap=$ewmaHeap.isAnomaly; ewmaEl=$ewmaEl.isAnomaly; zHeap=$zHeap; isoScore=$isoScore }
            alerts       = $alertsThisIter
            totalAlerts  = $alertCount
        }
        $pred | ConvertTo-Json -Depth 5 | Out-File $jsonOut -Encoding UTF8
        $logLine = "[$((Get-Date).ToString('HH:mm:ss'))] prob=$failProb heap=$($m.heapPct)% el=$($m.elMaxMs)ms alerts=$($alertsThisIter.Count)"
        Add-Content $logFile $logLine
        Write-Host "  💾 Predykcje zapisane → logs/ml_predictions.json" -ForegroundColor DarkGray
    }

    Start-Sleep $interval
}