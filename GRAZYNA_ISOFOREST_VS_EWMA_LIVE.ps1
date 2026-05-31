# ============================================================
# GRAŻYNA 5.0 — IsoForest vs EWMA na ŻYWYCH DANYCH
# Pobiera metryki z /metrics co 10s i porównuje oba algorytmy
# Uruchom: & "E:\Grazyna_5.0\GRAZYNA_ISOFOREST_VS_EWMA_LIVE.ps1"
# ============================================================

$proj     = "E:\Grazyna_5.0"
$logFile  = "$proj\logs\isoforest_vs_ewma_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$csvFile  = "$proj\logs\comparison_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$interval = 10

if (-not (Test-Path "$proj\logs")) { New-Item -ItemType Directory "$proj\logs" -Force | Out-Null }

# ─── CSV HEADER ───────────────────────────────────────────
"timestamp,heap_pct,el_max_ms,rss_mb,gc_minor,ewma_heap_score,ewma_el_score,ewma_anomaly,iso_score,iso_anomaly,failure_prob,method_winner" |
    Out-File $csvFile -Encoding UTF8

# ─── EWMA STATE ───────────────────────────────────────────
$ewmaState = @{}
$ALPHA = 0.3

function Update-EWMA($key, $value) {
    if (-not $ewmaState.ContainsKey($key)) {
        $ewmaState[$key] = @{ v = $value; var = 0.0 }
        return @{ score = 0.0; anomaly = $false; smoothed = $value }
    }
    $s   = $ewmaState[$key]
    $new = $ALPHA * $value + (1 - $ALPHA) * $s.v
    $d   = $value - $s.v
    $var = 0.1 * $d * $d + 0.9 * $s.var
    $ewmaState[$key] = @{ v = $new; var = $var }
    $std   = [math]::Sqrt($var)
    $score = if ($std -gt 0) { [math]::Abs($value - $new) / $std } else { 0 }
    return @{ score = [math]::Round($score, 2); anomaly = $score -gt 2.5; smoothed = [math]::Round($new, 2) }
}

# ─── ISOLATION FOREST (PowerShell) ────────────────────────
$isoHistory  = [System.Collections.Generic.List[double[]]]::new()
$isoTrees    = @()
$isoWarmed   = $false
$ISO_WARMUP  = 20
$ISO_TREES   = 50
$ISO_SAMPLE  = 32
$ISO_MAXDEPTH= 5  # log2(32)

function Build-IsoTree($data, $depth) {
    if ($data.Count -le 1 -or $depth -ge $ISO_MAXDEPTH) {
        return @{ leaf = $true; size = $data.Count }
    }
    $feat = Get-Random -Minimum 0 -Maximum $data[0].Length
    $vals = $data | ForEach-Object { $_[$feat] }
    $min  = ($vals | Measure-Object -Minimum).Minimum
    $max  = ($vals | Measure-Object -Maximum).Maximum
    if ($min -eq $max) { return @{ leaf = $true; size = $data.Count } }
    $split = $min + (Get-Random -Minimum 0 -Maximum 1000) / 1000.0 * ($max - $min)
    $left  = @($data | Where-Object { $_[$feat] -lt $split })
    $right = @($data | Where-Object { $_[$feat] -ge $split })
    if ($left.Count -eq 0 -or $right.Count -eq 0) {
        return @{ leaf = $true; size = $data.Count }
    }
    return @{
        leaf  = $false
        feat  = $feat
        split = $split
        left  = Build-IsoTree $left  ($depth + 1)
        right = Build-IsoTree $right ($depth + 1)
        size  = $data.Count
    }
}

function Get-PathLength($tree, $point, $depth) {
    if ($tree.leaf) {
        $n = $tree.size
        if ($n -le 1) { return $depth }
        return $depth + 2 * ([math]::Log($n - 1) + 0.5772) - 2 * ($n - 1) / $n
    }
    if ($point[$tree.feat] -lt $tree.split) {
        return Get-PathLength $tree.left  $point ($depth + 1)
    }
    return Get-PathLength $tree.right $point ($depth + 1)
}

function Get-IsoScore($point) {
    if ($isoTrees.Count -eq 0) { return 0.0 }
    $avgPath = ($isoTrees | ForEach-Object { Get-PathLength $_ $point 0 } |
        Measure-Object -Average).Average
    $n = $ISO_SAMPLE
    $c = if ($n -le 1) { 0 } elseif ($n -eq 2) { 1 } else {
        2 * ([math]::Log($n - 1) + 0.5772) - 2 * ($n - 1) / $n
    }
    if ($c -eq 0) { return 0.0 }
    return [math]::Round([math]::Pow(2, -$avgPath / $c), 3)
}

function Train-IsoForest($history) {
    $script:isoTrees = @()
    $data = @($history)
    for ($t = 0; $t -lt $ISO_TREES; $t++) {
        $sample = @($data | Get-Random -Count ([math]::Min($ISO_SAMPLE, $data.Count)))
        $tree   = Build-IsoTree $sample 0
        $script:isoTrees += $tree
    }
    $script:isoWarmed = $true
}

function Normalize-Metrics($heap, $el, $rss, $gc) {
    return @(
        [math]::Min($heap / 100, 1.0),
        [math]::Min($el   / 500, 1.0),
        [math]::Min($rss  / 300, 1.0),
        [math]::Min($gc   / 50,  1.0)
    )
}

# ─── POBIERZ METRYKI ──────────────────────────────────────
function Get-LiveMetrics {
    try {
        $r = Invoke-WebRequest "http://localhost:3001/metrics" -TimeoutSec 4 -ErrorAction Stop
        $t = $r.Content
        function PM($p) {
            $m = [regex]::Match($t, $p)
            if ($m.Success) { return [double]$m.Groups[1].Value }
            return 0.0
        }
        $hu = PM 'nodejs_heap_size_used_bytes\s+([\d.]+)'
        $ht = PM 'nodejs_heap_size_total_bytes\s+([\d.]+)'
        return @{
            ok      = $true
            heapPct = if($ht -gt 0){[math]::Round($hu/$ht*100,1)}else{0}
            elMaxMs = [math]::Round((PM 'nodejs_eventloop_lag_max_seconds\s+([\d.]+)')*1000,1)
            elLagMs = [math]::Round((PM 'nodejs_eventloop_lag_seconds\s+([\d.]+)')*1000,2)
            rssMB   = [math]::Round((PM 'process_resident_memory_bytes\s+([\d.]+)')/1MB,1)
            gcMinor = [double](PM 'nodejs_gc_duration_seconds_count\{[^}]*kind="minor"[^}]*\}\s+([\d.]+)')
            gcMajor = [double](PM 'nodejs_gc_duration_seconds_count\{[^}]*kind="major"[^}]*\}\s+([\d.]+)')
        }
    } catch { return @{ ok = $false } }
}

# ─── STATYSTYKI PORÓWNAWCZE ────────────────────────────────
$stats = @{
    ewmaAnomalies    = 0
    isoAnomalies     = 0
    bothAnomalies    = 0
    ewmaOnly         = 0
    isoOnly          = 0
    totalSamples     = 0
    ewmaFalseAlarms  = 0  # anomalie bez potwierdzenia ISO
    isoFalseAlarms   = 0  # anomalie bez potwierdzenia EWMA
    ewmaReactionTimes= [System.Collections.Generic.List[int]]::new()
    isoReactionTimes = [System.Collections.Generic.List[int]]::new()
}

$prevGcMinor = 0
$iteration   = 0
$startTime   = Get-Date

# ─── GŁÓWNA PĘTLA ─────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║   🔬 GRAŻYNA 5.0 — IsoForest vs EWMA LIVE COMPARISON  ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "  Próbkowanie: co ${interval}s | Ctrl+C aby zatrzymać" -ForegroundColor Gray
Write-Host "  CSV: $csvFile" -ForegroundColor Gray
Write-Host ""
Write-Host ("  {0,-8} {1,-8} {2,-8} {3,-8} {4,-10} {5,-10} {6,-8} {7,-8} {8,-8}" -f `
    "Iter", "Heap%", "EL ms", "RSS MB", "EWMA score", "ISO score", "EWMA?", "ISO?", "Winner") -ForegroundColor DarkCyan
Write-Host ("  " + "─" * 80) -ForegroundColor DarkGray

while ($true) {
    $iteration++
    $ts = (Get-Date).ToString("HH:mm:ss")

    $m = Get-LiveMetrics
    if (-not $m.ok) {
        Write-Host "  [$ts] ❌ Backend niedostępny" -ForegroundColor Red
        Start-Sleep $interval; continue
    }

    $gcDelta = [math]::Max(0, $m.gcMinor - $prevGcMinor)
    $prevGcMinor = $m.gcMinor

    # ── EWMA ──────────────────────────────────────────────
    $ewmaHeap = Update-EWMA "heap" $m.heapPct
    $ewmaEl   = Update-EWMA "el"   $m.elMaxMs
    $ewmaRss  = Update-EWMA "rss"  $m.rssMB
    $ewmaAnom = $ewmaHeap.anomaly -or $ewmaEl.anomaly
    $ewmaScore= [math]::Max($ewmaHeap.score, $ewmaEl.score)

    # ── ISOLATION FOREST ──────────────────────────────────
    $vec = Normalize-Metrics $m.heapPct $m.elMaxMs $m.rssMB $gcDelta
    $isoHistory.Add($vec)
    if ($isoHistory.Count -gt 300) { $isoHistory.RemoveAt(0) }

    # Trenuj gdy mamy dość danych (i co 20 próbek)
    if ($isoHistory.Count -ge $ISO_WARMUP -and ($iteration % 20 -eq 0 -or -not $isoWarmed)) {
        $trainData = @($isoHistory | Select-Object -Last 100)
        Train-IsoForest $trainData
        if ($iteration % 20 -eq 0) {
            Write-Host "  [Retrain] IsoForest wytrenowany na $($trainData.Count) próbkach" -ForegroundColor DarkGray
        }
    }

    $isoScore = if ($isoWarmed) { Get-IsoScore $vec } else { 0.0 }
    $isoAnom  = $isoScore -gt 0.65

    # ── STATYSTYKI ─────────────────────────────────────────
    $stats.totalSamples++
    if ($ewmaAnom) { $stats.ewmaAnomalies++ }
    if ($isoAnom)  { $stats.isoAnomalies++ }
    if ($ewmaAnom -and $isoAnom)  { $stats.bothAnomalies++ }
    if ($ewmaAnom -and -not $isoAnom) { $stats.ewmaOnly++; $stats.ewmaFalseAlarms++ }
    if ($isoAnom -and -not $ewmaAnom) { $stats.isoOnly++;  $stats.isoFalseAlarms++ }

    # ── WINNER ────────────────────────────────────────────
    $winner = if ($ewmaAnom -and $isoAnom) { "BOTH" }
              elseif ($ewmaAnom)            { "EWMA" }
              elseif ($isoAnom)             { "ISO" }
              else                          { "none" }

    $method = if ($isoWarmed) { "isoforest" } else { "ewma(cold)" }

    # ── WYŚWIETL ──────────────────────────────────────────
    $heapCol  = if($m.heapPct -gt 90){"Red"}elseif($m.heapPct -gt 80){"Yellow"}else{"Green"}
    $elCol    = if($m.elMaxMs -gt 100){"Red"}elseif($m.elMaxMs -gt 50){"Yellow"}else{"Green"}
    $ewmaCol  = if($ewmaAnom){"Red"}else{"Green"}
    $isoCol   = if($isoAnom){"Red"}else{"Green"}
    $winCol   = if($winner -eq "BOTH"){"Red"}elseif($winner -ne "none"){"Yellow"}else{"Green"}

    Write-Host ("  {0,-8} " -f "#$iteration") -NoNewline -ForegroundColor DarkGray
    Write-Host ("{0,-8}" -f "$($m.heapPct)%") -NoNewline -ForegroundColor $heapCol
    Write-Host ("{0,-8}" -f "$($m.elMaxMs)ms") -NoNewline -ForegroundColor $elCol
    Write-Host ("{0,-8}" -f "$($m.rssMB)MB") -NoNewline -ForegroundColor Cyan
    Write-Host ("{0,-10}" -f $ewmaScore.ToString("F2")) -NoNewline -ForegroundColor $ewmaCol
    Write-Host ("{0,-10}" -f $isoScore.ToString("F3")) -NoNewline -ForegroundColor $isoCol
    Write-Host ("{0,-8}" -f $(if($ewmaAnom){"⚠️ YES"}else{"✅ no"})) -NoNewline -ForegroundColor $ewmaCol
    Write-Host ("{0,-8}" -f $(if($isoAnom){"⚠️ YES"}else{"✅ no"})) -NoNewline -ForegroundColor $isoCol
    Write-Host ("{0,-8}" -f $winner) -ForegroundColor $winCol

    # Status IsoForest
    if (-not $isoWarmed) {
        $pct = [math]::Round($isoHistory.Count / $ISO_WARMUP * 100)
        Write-Host ("  [IsoForest] Cold-start: {0}/{1} próbek ({2}%) — tryb EWMA" -f `
            $isoHistory.Count, $ISO_WARMUP, $pct) -ForegroundColor DarkYellow
    }

    # ── ALERTY ────────────────────────────────────────────
    if ($ewmaAnom -or $isoAnom) {
        Write-Host ""
        if ($ewmaAnom) { Write-Host "  🚨 EWMA: heap=$($ewmaHeap.score.ToString('F1'))σ el=$($ewmaEl.score.ToString('F1'))σ" -ForegroundColor Red }
        if ($isoAnom)  { Write-Host "  🌲 ISO:  score=$($isoScore.ToString('F3')) > 0.65" -ForegroundColor Red }
        if ($ewmaAnom -and -not $isoAnom) { Write-Host "  ℹ️  EWMA wykrył, ISO nie — możliwy fałszywy alarm" -ForegroundColor Yellow }
        if ($isoAnom -and -not $ewmaAnom) { Write-Host "  ℹ️  ISO wykrył, EWMA nie — wielowymiarowa anomalia" -ForegroundColor Yellow }
        Write-Host ""
    }

    # ── CSV ───────────────────────────────────────────────
    "$ts,$($m.heapPct),$($m.elMaxMs),$($m.rssMB),$gcDelta,$($ewmaHeap.score),$($ewmaEl.score),$ewmaAnom,$isoScore,$isoAnom,0,$winner" |
        Add-Content $csvFile

    # ── LOG ───────────────────────────────────────────────
    Add-Content $logFile "[$ts] heap=$($m.heapPct)% el=$($m.elMaxMs)ms ewma=$ewmaAnom iso=$isoAnom winner=$winner method=$method"

    # ── PODSUMOWANIE co 10 iteracji ────────────────────────
    if ($iteration % 10 -eq 0) {
        $uptime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
        Write-Host ""
        Write-Host "  ┌─── PODSUMOWANIE #$iteration (uptime: ${uptime}min) ───────────────────┐" -ForegroundColor DarkCyan
        Write-Host ("  │ Próbki:        {0}" -f $stats.totalSamples) -ForegroundColor White
        Write-Host ("  │ EWMA anomalie: {0} ({1}%)" -f $stats.ewmaAnomalies, [math]::Round($stats.ewmaAnomalies/$stats.totalSamples*100,1)) -ForegroundColor $(if($stats.ewmaAnomalies -gt 0){"Yellow"}else{"Green"})
        Write-Host ("  │ ISO anomalie:  {0} ({1}%)" -f $stats.isoAnomalies,  [math]::Round($stats.isoAnomalies/$stats.totalSamples*100,1))  -ForegroundColor $(if($stats.isoAnomalies -gt 0){"Yellow"}else{"Green"})
        Write-Host ("  │ Oba wykryły:   {0}" -f $stats.bothAnomalies) -ForegroundColor White
        Write-Host ("  │ Tylko EWMA:    {0} (potencjalne false alarms)" -f $stats.ewmaOnly) -ForegroundColor Yellow
        Write-Host ("  │ Tylko ISO:     {0} (wielowymiarowe anomalie)" -f $stats.isoOnly) -ForegroundColor Cyan
        Write-Host ("  │ IsoForest:     {0}" -f $(if($isoWarmed){"AKTYWNY ($($isoHistory.Count) próbek)"}else{"COLD-START ($($isoHistory.Count)/$ISO_WARMUP)"})) -ForegroundColor $(if($isoWarmed){"Green"}else{"Yellow"})
        Write-Host ("  │ CSV:           $csvFile") -ForegroundColor DarkGray
        Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host ("  {0,-8} {1,-8} {2,-8} {3,-8} {4,-10} {5,-10} {6,-8} {7,-8} {8,-8}" -f `
            "Iter", "Heap%", "EL ms", "RSS MB", "EWMA score", "ISO score", "EWMA?", "ISO?", "Winner") -ForegroundColor DarkCyan
        Write-Host ("  " + "─" * 80) -ForegroundColor DarkGray
    }

    Start-Sleep $interval
}