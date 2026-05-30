$BackendPath = "E:\Grazyna_5.0\backend"
$HealthUrl   = "http://localhost:3001/health"
$HeapUrl     = "http://localhost:3001/api/system/heap"
$MetricsUrl  = "http://localhost:3001/metrics"
$GcUrl       = "http://localhost:3001/api/system/gc"
$LogFile     = "E:\Grazyna_5.0\logs\watchdog-ai.log"

function Log([string]$msg) {
    $line = "[" + (Get-Date -Format s) + "] " + $msg
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Stop-Port3001 {
    Get-NetTCPConnection -LocalPort 3001 -ErrorAction SilentlyContinue |
        Where-Object { $_.OwningProcess -ne 0 } |
        Select-Object -ExpandProperty OwningProcess -Unique |
        ForEach-Object {
            try {
                Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
                Log "Stopped PID $_ on port 3001"
            } catch {
                Log "Could not stop PID $_"
            }
        }
}

function Start-Backend {
    Start-Process powershell -ArgumentList "-NoExit","-Command","cd E:\Grazyna_5.0\backend; npm run dev"
    Log "Started backend: E:\Grazyna_5.0\backend -> npm run dev"
}

# ===== retry/backoff =====
$attempt = 0
$maxAttempts = 6
$baseDelay = 2
$scaleCounter = 0

while ($true) {
    try {
        $health = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 3 -ErrorAction Stop
        if ($health.status -eq "ok") {
            Log "Backend OK"
            $attempt = 0
        }

        # ===== heap decision =====
        try {
            $heap = Invoke-RestMethod -Uri $HeapUrl -TimeoutSec 3 -ErrorAction Stop
            $heapPct = [double]$heap.heap.pct
            Log ("Heap pct: " + $heapPct)

            if ($heapPct -ge 90) {
                Log "AI decision: GC or restart candidate (heap >= 90%)"
                try {
                    Invoke-RestMethod -Uri $GcUrl -Method Post -TimeoutSec 3 -ErrorAction Stop | Out-Null
                    Log "GC endpoint invoked"
                } catch {
                    Log "GC endpoint unavailable -> restart fallback"
                    Stop-Port3001
                    Start-Backend
                }
            }
        } catch {
            Log "Heap endpoint unavailable"
        }

        # ===== metrics / scale suggestion =====
        try {
            $metrics = Invoke-WebRequest -Uri $MetricsUrl -TimeoutSec 3 -ErrorAction Stop
            $text = $metrics.Content

            if ($text -match 'nodejs_eventloop_lag_p99_seconds\s+([0-9\.]+)') {
                $lag = [double]$matches[1]
                Log ("EventLoopLag p99: " + $lag)

                if ($lag -gt 0.05) {
                    $scaleCounter++
                    Log "Scale signal raised (lag > 50ms)"
                } else {
                    if ($scaleCounter -gt 0) { $scaleCounter-- }
                }
            }

            if ($scaleCounter -ge 3) {
                Log "AI decision: SCALE suggested (sustained lag)"
                $scaleCounter = 0
            }
        } catch {
            Log "Metrics unavailable"
        }

    } catch {
        Log "Backend DOWN"

        if ($attempt -ge $maxAttempts) {
            Log "Max restart attempts reached, stopping watchdog"
            break
        }

        $delay = [Math]::Min(($baseDelay * [Math]::Pow(2, $attempt)), 30)
        Log ("AI decision: RESTART in " + $delay + " sec (attempt " + ($attempt + 1) + ")")

        Start-Sleep -Seconds $delay
        Stop-Port3001
        Start-Backend
        $attempt++
    }

    Start-Sleep -Seconds 5
}
