# ============================================================
# GRAŻYNA 5.0 — OOM PREDICTOR + CLUSTER STABILITY MONITOR
# Predykcja OOM z wyprzedzeniem 60s używając EWMA + LinReg
# Progi dla klastra 4 workerów oparte na rzeczywistych danych
# ============================================================

$proj     = "E:\Grazyna_5.0"
$logFile  = "$proj\logs\oom_predictor_$(Get-Date -Format 'yyyyMMdd').log"
$jsonOut  = "$proj\logs\oom_predictions.json"
$interval = 10  # sekund

if (-not (Test-Path "$proj\logs")) { New-Item -ItemType Directory "$proj\logs" -Force | Out-Null }

# ─── PROGI ALARMOWE (klaster 4 workerów) ──────────────────
# Oparte na analizie danych z sesji GRAŻYNA 5.0
$THRESHOLDS = @{
    # Heap — przy --max-old-space-size=512
    heap_warn     = 82    # % — ostrzeżenie (niższy niż single proc bo crash=25% capacity)
    heap_critical = 90    # % — krytyczny
    heap_oom      = 95    # % — OOM imminent

    # Event Loop Lag
    el_lag_warn   = 20    # ms — ostrzeżenie
    el_lag_crit   = 100   # ms — krytyczny
    el_max_warn   = 50    # ms — ostrzeżenie (sesja 2: 35ms = OK)
    el_max_crit   = 200   # ms — krytyczny (sesja 1: 869ms = CRASH)

    # GC — oparte na sesji 3: ×92 w 2.2h = normalny
    gc_minor_warn = 20    # per próbkę — ostrzeżenie
    gc_minor_crit = 50    # per próbkę — krytyczny
    gc_major_warn = 1     # per próbkę — ostrzeżenie
    gc_major_crit = 3     # per próbkę — krytyczny

    # RSS
    rss_warn      = 150   # MB
    rss_crit      = 300   # MB

    # Failure Probability
    fp_warn       = 0.30  # 30%
    fp_crit       = 0.60  # 60%
    fp_oom        = 0.80  # 80%

    # TTT (Time To Threshold) — kluczowe: 60s ahead
    ttt_warn_s    = 300   # 5 minut
    ttt_crit_s    = 60    # 60 sekund — wymagane minimum
}

# ─── EWMA STATE ───────────────────────────────────────────
$ewmaState = @{}
$ALPHA = 0.3

function Update-EWMA($key, $value) {
    if (-not $ewmaState.ContainsKey($key)) {
        $ewmaState[$key] = @{ v = $value; var = 0.0 }
        return @{ smoothed = $value; score = 0.0; anomaly = $false }
    }
    $s   = $ewmaState[$key]
    $new = $ALPHA * $value + (1 - $ALPHA) * $s.v
    $d   = $value - $s.v
    $var = 0.1 * $d * $d + 0.9 * $s.var
    $ewmaState[$key] = @{ v = $new; var = $var }
    $std   = if ($var -gt 0) { [math]::Sqrt($var) } else { 0.001 }
    $score = [math]::Abs($value - $new) / $std
    return @{
        smoothed = [math]::Round($new, 2)
        score    = [math]::Round($score, 2)
        anomaly  = $score -gt 2.5
    }
}

# ─── LINEAR REGRESSION + TTT ──────────────────────────────
$history = @{}
$WINDOW  = 20

function Add-DataPoint($key, $value) {
    if (-not $history.ContainsKey($key)) { $history[$key] = [System.Collections.Generic.List[double]]::new() }
    $history[$key].Add([double]$value)
    if ($history[$key].Count -gt $WINDOW * 3) { $history[$key].RemoveAt(0) }
}

function Get-Slope($key) {
    $pts = $history[$key]
    if (-not $pts -or $pts.Count -lt 5) { return 0.0 }
    $recent = @($pts | Select-Object -Last $WINDOW)
    $n = $recent.Count
    $xs = 0..($n-1)
    $sumX  = ($xs | Measure-Object -Sum).Sum
    $sumY  = ($recent | Measure-Object -Sum).Sum
    $sumXY = 0; for ($i=0;$i -lt $n;$i++) { $sumXY += $xs[$i]*$recent[$i] }
    $sumX2 = ($xs | ForEach-Object {$_*$_} | Measure-Object -Sum).Sum
    $denom = $n*$sumX2 - $sumX*$sumX
    if ($denom -eq 0) { return 0.0 }
    return ($n*$sumXY - $sumX*$sumY) / $denom
}

function Get-TTT($key, $threshold) {
    $pts = $history[$key]
    if (-not $pts -or $pts.Count -lt 5) { return @{ text="N/A"; seconds=9999 } }
    $current = $pts[$pts.Count-1]
    if ($current -ge $threshold) { return @{ text="JUŻ PRZEKROCZONY"; seconds=0 } }
    $slope = Get-Slope $key
    if ($slope -le 0.001) { return @{ text="∞ (stabilny)"; seconds=99999 } }
    $steps   = ($threshold - $current) / $slope
    $seconds = [math]::Round($steps * $interval)
    if ($seconds -lt 60)   { return @{ text="${seconds}s"; seconds=$seconds } }
    if ($seconds -lt 3600) { return @{ text="$([math]::Round($seconds/60))min $($seconds%60)s"; seconds=$seconds } }
    return @{ text="$([math]::Round($seconds/3600,1))h"; seconds=$seconds }
}

function Get-Prediction($key, $stepsAhead=6) {
    $pts = $history[$key]
    if (-not $pts -or $pts.Count -lt 10) { return $null }
    $slope = Get-Slope $key
    return [math]::Round($pts[$pts.Count-1] + $slope * $stepsAhead, 1)
}

# ─── FAILURE PROBABILITY ──────────────────────────────────
function Get-FailureProbability($heap, $elMax, $gcMajor, $ewmaAnomaly, $gcMinorRate) {
    $score = 0.0
    # Heap (dominuje przy OOM)
    if ($heap -gt 95)    { $score += 0.40 }
    elseif ($heap -gt 90){ $score += 0.20 }
    elseif ($heap -gt 85){ $score += 0.10 }
    # EL Lag max (był 869ms w sesji 1 = crash)
    if ($elMax -gt 500)    { $score += 0.30 }
    elseif ($elMax -gt 200){ $score += 0.15 }
    elseif ($elMax -gt 100){ $score += 0.05 }
    # GC Major (heap pressure)
    if ($gcMajor -gt 5)   { $score += 0.15 }
    elseif ($gcMajor -gt 2){ $score += 0.08 }
    elseif ($gcMajor -gt 0){ $score += 0.03 }
    # EWMA anomaly
    if ($ewmaAnomaly) { $score += 0.10 }
    # GC Minor rate
    if ($gcMinorRate -gt 30) { $score += 0.05 }
    return [math]::Min([math]::Round($score, 3), 1.0)
}

# ─── POBIERZ METRYKI ──────────────────────────────────────
function Get-Metrics {
    try {
        $r = Invoke-WebRequest "http://localhost:3001/metrics" -TimeoutSec 4 -ErrorAction Stop
        $t = $r.Content
        function PM($p) { $m=[regex]::Match($t,$p); if($m.Success){return [double]$m.Groups[1].Value}; return 0.0 }
        $hu = PM 'nodejs_heap_size_used_bytes\s+([\d.]+)'
        $ht = PM 'nodejs_heap_size_total_bytes\s+([\d.]+)'
        return @{
            ok      = $true
            heapPct = if($ht-gt 0){[math]::Round($hu/$ht*100,1)}else{0}
            rssMB   = [math]::Round((PM 'process_resident_memory_bytes\s+([\d.]+)')/1MB,1)
            elMs    = [math]::Round((PM 'nodejs_eventloop_lag_seconds\s+([\d.]+)')*1000,2)
            elMaxMs = [math]::Round((PM 'nodejs_eventloop_lag_max_seconds\s+([\d.]+)')*1000,1)
            elP99Ms = [math]::Round((PM 'nodejs_eventloop_lag_p99_seconds\s+([\d.]+)')*1000,1)
            gcMinor = [double](PM 'nodejs_gc_duration_seconds_count\{[^}]*kind="minor"[^}]*\}\s+([\d.]+)')
            gcMajor = [double](PM 'nodejs_gc_duration_seconds_count\{[^}]*kind="major"[^}]*\}\s+([\d.]+)')
            losUsed = [math]::Round((PM 'nodejs_heap_space_size_used_bytes\{space="large_object"\}\s+([\d.]+)')/1024,0)
            losTotal= [math]::Round((PM 'nodejs_heap_space_size_total_bytes\{space="large_object"\}\s+([\d.]+)')/1024,0)
            oldPct  = 0.0  # obliczane poniżej
        }
    } catch { return @{ ok = $false } }
}

# ─── GŁÓWNA PĘTLA ─────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║   🔮 GRAŻYNA 5.0 — OOM PREDICTOR (60s ahead)              ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "  Progi: Heap WARN>82% CRIT>90% OOM>95% | EL max CRIT>200ms" -ForegroundColor Gray
Write-Host "  TTT krytyczny: <60s | Klaster: 4 workery" -ForegroundColor Gray
Write-Host "  Ctrl+C aby zatrzymać" -ForegroundColor Gray
Write-Host ""

$iteration   = 0
$prevGcMinor = 0
$prevGcMajor = 0
$oomAlerts   = 0
$startTime   = Get-Date

while ($true) {
    $iteration++
    $ts     = (Get-Date).ToString("HH:mm:ss")
    $uptime = [math]::Round(((Get-Date)-$startTime).TotalMinutes,1)

    $m = Get-Metrics
    if (-not $m.ok) {
        Write-Host "[$ts] ❌ Backend niedostępny — sprawdź :3001" -ForegroundColor Red
        Start-Sleep $interval; continue
    }

    # Przyrostowe GC
    $gcMinorDelta = [math]::Max(0, $m.gcMinor - $prevGcMinor)
    $gcMajorDelta = [math]::Max(0, $m.gcMajor - $prevGcMajor)
    $prevGcMinor  = $m.gcMinor
    $prevGcMajor  = $m.gcMajor

    # Dodaj do historii
    Add-DataPoint "heap"   $m.heapPct
    Add-DataPoint "el_max" $m.elMaxMs
    Add-DataPoint "rss"    $m.rssMB
    Add-DataPoint "gc_min" $m.gcMinor

    # EWMA
    $ewmaHeap = Update-EWMA "heap"   $m.heapPct
    $ewmaEl   = Update-EWMA "el_max" $m.elMaxMs

    # TTT (kluczowe — 60s ahead)
    $tttHeap95 = Get-TTT "heap"   $THRESHOLDS.heap_oom
    $tttHeap90 = Get-TTT "heap"   $THRESHOLDS.heap_critical
    $tttEl200  = Get-TTT "el_max" $THRESHOLDS.el_max_crit

    # Predykcje za 60s (6 próbek × 10s)
    $predHeap = Get-Prediction "heap"   6
    $predEl   = Get-Prediction "el_max" 6

    # Failure Probability
    $fp = Get-FailureProbability $m.heapPct $m.elMaxMs $gcMajorDelta $ewmaHeap.anomaly $gcMinorDelta

    # ── WYŚWIETL DASHBOARD ────────────────────────────────
    Write-Host ""
    Write-Host ("─── OOM #$iteration @ $ts (uptime: ${uptime}min) ─────────────────────────") -ForegroundColor DarkCyan

    # Failure Probability bar
    $fpPct = [math]::Round($fp * 100)
    $fpBar = "█" * [math]::Round($fpPct/5) + "░" * (20 - [math]::Round($fpPct/5))
    $fpCol = if($fpPct -gt 60){"Red"}elseif($fpPct -gt 30){"Yellow"}else{"Green"}
    Write-Host ("  🔮 OOM RISK: [{0}] {1}%" -f $fpBar, $fpPct) -ForegroundColor $fpCol

    # Heap
    $hCol = if($m.heapPct -gt $THRESHOLDS.heap_oom){"Red"}elseif($m.heapPct -gt $THRESHOLDS.heap_critical){"Yellow"}else{"Green"}
    $hTrend = if((Get-Slope "heap") -gt 0.1){"↗"}elseif((Get-Slope "heap") -lt -0.1){"↘"}else{"→"}
    Write-Host ("  🧠 Heap:    {0,5}%  EWMA:{1}%  {2}  TTT→95%:{3,-12} pred60s:{4}%" -f `
        $m.heapPct, $ewmaHeap.smoothed, $hTrend, $tttHeap95.text, $predHeap) -ForegroundColor $hCol

    # EL Lag
    $eCol = if($m.elMaxMs -gt $THRESHOLDS.el_max_crit){"Red"}elseif($m.elMaxMs -gt $THRESHOLDS.el_max_warn){"Yellow"}else{"Green"}
    Write-Host ("  🔄 EL Lag:  {0,5}ms  max:{1}ms  p99:{2}ms  EWMA:{3}ms  TTT→200ms:{4}" -f `
        $m.elMs, $m.elMaxMs, $m.elP99Ms, $ewmaEl.smoothed, $tttEl200.text) -ForegroundColor $eCol

    # RSS + LOS
    $rCol = if($m.rssMB -gt $THRESHOLDS.rss_crit){"Red"}elseif($m.rssMB -gt $THRESHOLDS.rss_warn){"Yellow"}else{"Green"}
    $losPct = if($m.losTotal -gt 0){[math]::Round($m.losUsed/$m.losTotal*100,0)}else{0}
    Write-Host ("  💾 RSS:     {0,5}MB  LOS:{1}KB/{2}KB ({3}%)  GC:minor+{4} major+{5}" -f `
        $m.rssMB, $m.losUsed, $m.losTotal, $losPct, $gcMinorDelta, $gcMajorDelta) -ForegroundColor $rCol

    # ── ALERTY PREDYKCYJNE ────────────────────────────────
    $alerts = @()

    # KRYTYCZNY: TTT < 60s
    if ($tttHeap95.seconds -lt $THRESHOLDS.ttt_crit_s -and $tttHeap95.seconds -gt 0) {
        $alerts += "🔴 KRYTYCZNY: Heap OOM za $($tttHeap95.text)! Wymuś GC lub restart!"
        $oomAlerts++
    }
    # OSTRZEŻENIE: TTT < 5min
    elseif ($tttHeap95.seconds -lt $THRESHOLDS.ttt_warn_s -and $tttHeap95.seconds -gt 0) {
        $alerts += "⚠️  OSTRZEŻENIE: Heap OOM za $($tttHeap95.text) — monitoruj"
    }

    # EWMA anomalie
    if ($ewmaHeap.anomaly) { $alerts += "🚨 EWMA ANOMALIA: Heap spike! score=$($ewmaHeap.score)σ" }
    if ($ewmaEl.anomaly)   { $alerts += "🚨 EWMA ANOMALIA: EL Lag spike! score=$($ewmaEl.score)σ" }

    # Failure Probability
    if ($fp -gt $THRESHOLDS.fp_oom)  { $alerts += "🔴 FAILURE PROB $fpPct% > 80% — OOM IMMINENT!" }
    elseif ($fp -gt $THRESHOLDS.fp_crit) { $alerts += "⚠️  FAILURE PROB $fpPct% > 60% — KRYTYCZNY" }

    # GC Major
    if ($gcMajorDelta -gt 0) { $alerts += "🗑️  MAJOR GC +$gcMajorDelta — heap pressure!" }

    # Large Object Space
    if ($losPct -ge 100) { $alerts += "📦 LOS 100% — Prisma DMMF stały (normalny)" }

    if ($alerts.Count -gt 0) {
        Write-Host ""
        $alerts | ForEach-Object {
            $col = if($_ -match "KRYTYCZNY|IMMINENT|ANOMALIA"){"Red"}else{"Yellow"}
            Write-Host "  $_" -ForegroundColor $col
        }
    } else {
        Write-Host "  ✅ Wszystkie metryki w normie" -ForegroundColor Green
    }

    # ── AKCJE AUTOMATYCZNE ────────────────────────────────
    if ($tttHeap95.seconds -lt $THRESHOLDS.ttt_crit_s -and $tttHeap95.seconds -gt 0) {
        Write-Host "  🤖 AUTO-AKCJA: Wymuszam GC..." -ForegroundColor Magenta
        try {
            $gc = Invoke-RestMethod "http://localhost:3001/api/system/gc" -Method POST -TimeoutSec 3
            if ($gc.success) { Write-Host "  ✅ GC zwolnił $($gc.freed_mb) MB" -ForegroundColor Green }
        } catch { Write-Host "  ⚠️  GC endpoint niedostępny" -ForegroundColor Yellow }
    }

    # ── ZAPISZ DO JSON ────────────────────────────────────
    if ($iteration % 6 -eq 0) {
        $pred = @{
            timestamp       = (Get-Date -Format "o")
            iteration       = $iteration
            failure_prob    = $fp
            oom_risk_pct    = $fpPct
            current         = @{ heapPct=$m.heapPct; elMaxMs=$m.elMaxMs; rssMB=$m.rssMB }
            predicted_60s   = @{ heapPct=$predHeap; elMaxMs=$predEl }
            ttt             = @{ heap95=$tttHeap95.text; heap90=$tttHeap90.text; el200=$tttEl200.text }
            ttt_seconds     = @{ heap95=$tttHeap95.seconds; heap90=$tttHeap90.seconds }
            ewma            = @{ heapAnomaly=$ewmaHeap.anomaly; elAnomaly=$ewmaEl.anomaly }
            gc_delta        = @{ minor=$gcMinorDelta; major=$gcMajorDelta }
            alerts          = $alerts
            total_oom_alerts= $oomAlerts
            thresholds      = $THRESHOLDS
        }
        $pred | ConvertTo-Json -Depth 5 | Out-File $jsonOut -Encoding UTF8
        $logLine = "[$ts] heap=$($m.heapPct)% fp=$fpPct% ttt95=$($tttHeap95.text) el=$($m.elMaxMs)ms alerts=$($alerts.Count)"
        Add-Content $logFile $logLine
        Write-Host "  💾 Predykcje → logs/oom_predictions.json" -ForegroundColor DarkGray
    }

    Start-Sleep $interval
}