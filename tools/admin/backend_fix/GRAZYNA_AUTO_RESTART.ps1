# ============================================================
# GRAŻYNA 5.0 — AUTO-RESTART WATCHDOG
# Monitoruje backend i restartuje przy awarii
# Uruchom: Start-Process powershell -ArgumentList "-File E:\Grazyna_5.0\GRAZYNA_AUTO_RESTART.ps1"
# ============================================================

$proj      = "E:\Grazyna_5.0"
$backend   = "$proj\backend"
$nodeExe   = "$proj\tools\nodejs\node.exe"
$logFile   = "$proj\logs\watchdog.log"
$pidFile   = "$proj\logs\backend.pid"
$maxFails  = 5      # max restartów z rzędu
$checkInt  = 10     # sekund między sprawdzeniami
$cooldown  = 30     # sekund czekania po max failach

if (-not (Test-Path "$proj\logs")) { New-Item -ItemType Directory "$proj\logs" -Force | Out-Null }

function Log($level, $msg) {
    $ts   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$ts] [$level] $msg"
    Add-Content $logFile $line -ErrorAction SilentlyContinue
    $col  = switch($level) { "OK"{"Green"}; "WARN"{"Yellow"}; "ERR"{"Red"}; "INFO"{"Cyan"} }
    Write-Host $line -ForegroundColor $col
}

function Start-Backend {
    $cmd = "cd /d `"$backend`" && `"$nodeExe`" --max-old-space-size=256 --expose-gc node_modules\tsx\dist\cli.mjs watch src\cluster-bootstrap.ts"
    $proc = Start-Process cmd -ArgumentList "/c", $cmd -PassThru -WindowStyle Minimized
    $proc.Id | Out-File $pidFile -Encoding ASCII
    Log "OK" "Backend uruchomiony (PID: $($proc.Id))"
    return $proc
}

function Test-Backend {
    try {
        $r = Invoke-WebRequest "http://localhost:3001/health" -TimeoutSec 5 -ErrorAction Stop
        return $r.StatusCode -eq 200
    } catch { return $false }
}

function Get-BackendMetrics {
    try {
        $r = Invoke-WebRequest "http://localhost:3001/metrics" -TimeoutSec 3 -ErrorAction Stop
        $t = $r.Content
        $heap = [double]([regex]::Match($t,'nodejs_heap_size_used_bytes\s+([\d.]+)').Groups[1].Value)
        $total= [double]([regex]::Match($t,'nodejs_heap_size_total_bytes\s+([\d.]+)').Groups[1].Value)
        $rss  = [double]([regex]::Match($t,'process_resident_memory_bytes\s+([\d.]+)').Groups[1].Value)
        $el   = [double]([regex]::Match($t,'nodejs_eventloop_lag_seconds\s+([\d.]+)').Groups[1].Value)
        return @{
            ok      = $true
            heapPct = if($total -gt 0){[math]::Round($heap/$total*100,1)}else{0}
            rssMB   = [math]::Round($rss/1MB,1)
            elMs    = [math]::Round($el*1000,2)
        }
    } catch { return @{ ok = $false } }
}

# ─── GŁÓWNA PĘTLA WATCHDOG ────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    GRAŻYNA 5.0 — AUTO-RESTART WATCHDOG               ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  Sprawdzanie co ${checkInt}s | Max restartów: $maxFails | Ctrl+C aby zatrzymać" -ForegroundColor Gray
Write-Host ""

Log "INFO" "=== WATCHDOG START ==="

$failCount   = 0
$totalRestarts = 0
$iteration   = 0
$backendProc = $null
$startTime   = Get-Date

# Sprawdź czy backend już działa
if (Test-Backend) {
    Log "OK" "Backend już działa na :3001"
} else {
    Log "INFO" "Backend nie odpowiada — uruchamiam..."
    $backendProc = Start-Backend
    Start-Sleep 8
}

while ($true) {
    $iteration++
    $uptime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)

    # ── SPRAWDŹ HEALTH ────────────────────────────────────
    $healthy = Test-Backend

    if ($healthy) {
        $failCount = 0

        # Pobierz metryki co 5 iteracji
        if ($iteration % 5 -eq 0) {
            $m = Get-BackendMetrics
            if ($m.ok) {
                $heapCol = if($m.heapPct -gt 90){"Yellow"}else{"Green"}
                $elCol   = if($m.elMs -gt 50){"Yellow"}else{"Green"}
                Write-Host ("  [{0}] ✅ OK | Heap:{1}% RSS:{2}MB EL:{3}ms | Restarts:{4} Uptime:{5}min" -f `
                    (Get-Date).ToString("HH:mm:ss"), $m.heapPct, $m.rssMB, $m.elMs, $totalRestarts, $uptime) `
                    -ForegroundColor $(if($m.heapPct -gt 90 -or $m.elMs -gt 50){"Yellow"}else{"Green"})

                # Alert przy wysokim heap
                if ($m.heapPct -gt 95) {
                    Log "ERR" "HEAP KRYTYCZNY: $($m.heapPct)% — wymuszam restart!"
                    $healthy = $false
                    $failCount = $maxFails  # wymuś restart
                }
            }
        } else {
            Write-Host ("  [{0}] ✅ Backend OK (iter #{1})" -f (Get-Date).ToString("HH:mm:ss"), $iteration) -ForegroundColor DarkGreen
        }
    }

    if (-not $healthy) {
        $failCount++
        Log "WARN" "Backend nie odpowiada! Fail $failCount/$maxFails"

        if ($failCount -ge $maxFails) {
            Log "ERR" "Max failów osiągnięty ($maxFails) — cooldown ${cooldown}s..."
            Start-Sleep $cooldown
            $failCount = 0
        }

        # Zatrzymaj stary proces
        $nodeProcs = Get-Process node -ErrorAction SilentlyContinue
        if ($nodeProcs) {
            Log "INFO" "Zatrzymuję $($nodeProcs.Count) procesów Node.js..."
            $nodeProcs | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep 3
        }

        # Restart
        $totalRestarts++
        Log "WARN" "Restart #$totalRestarts..."
        $backendProc = Start-Backend

        # Czekaj na start
        $started = $false
        for ($w = 1; $w -le 15; $w++) {
            Start-Sleep 2
            if (Test-Backend) {
                Log "OK" "Backend zrestartowany pomyślnie (po ${w}×2s)"
                $started = $true
                break
            }
        }

        if (-not $started) {
            Log "ERR" "Backend nie startuje po restarcie #$totalRestarts!"
        }
    }

    Start-Sleep $checkInt
}