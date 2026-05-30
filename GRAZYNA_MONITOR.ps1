# ============================================================
# GRAŻYNA 5.0 — AUTO-MONITORING I ALERTY
# Uruchom w tle: Start-Process powershell -ArgumentList "-File E:\Grazyna_5.0\GRAZYNA_MONITOR.ps1"
# Data: 2026-05-29
# ============================================================

$proj       = "E:\Grazyna_5.0"
$logFile    = "$proj\logs\monitor.log"
$alertFile  = "$proj\logs\alerts.json"
$interval   = 30  # sekund między sprawdzeniami
$alerts     = @()

# Upewnij się że katalog logów istnieje
if (-not (Test-Path "$proj\logs")) { New-Item -ItemType Directory "$proj\logs" -Force | Out-Null }

function Log($level, $msg) {
    $ts  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ico = switch($level) { "OK" {"✓"}; "WARN" {"⚠"}; "ERR" {"✗"}; "INFO" {"ℹ"} }
    $col = switch($level) { "OK" {"Green"}; "WARN" {"Yellow"}; "ERR" {"Red"}; "INFO" {"Cyan"} }
    $line = "[$ts] $ico $msg"
    Write-Host $line -ForegroundColor $col
    Add-Content $logFile $line
}

function AddAlert($severity, $type, $message) {
    $script:alerts += [PSCustomObject]@{
        id        = [System.Guid]::NewGuid().ToString()
        severity  = $severity
        type      = $type
        message   = $message
        timestamp = (Get-Date -Format "o")
        resolved  = $false
    }
    $script:alerts | ConvertTo-Json | Set-Content $alertFile
}

function CheckPort($port, $name) {
    $listening = netstat -ano 2>&1 | findstr ":$port" | findstr "LISTENING"
    if ($listening) {
        Log "OK" "$name :$port — ONLINE"
        return $true
    } else {
        Log "ERR" "$name :$port — OFFLINE!"
        AddAlert "critical" "port_down" "$name :$port jest niedostępny"
        return $false
    }
}

function CheckMemory() {
    $os = Get-CimInstance Win32_OperatingSystem
    $usedPct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
    $freeMB  = [math]::Round($os.FreePhysicalMemory / 1024, 0)
    if ($usedPct -gt 90) {
        Log "ERR" "RAM: $usedPct% użyte ($freeMB MB wolne) — KRYTYCZNE!"
        AddAlert "critical" "memory_high" "Użycie RAM: $usedPct%"
    } elseif ($usedPct -gt 80) {
        Log "WARN" "RAM: $usedPct% użyte ($freeMB MB wolne)"
        AddAlert "high" "memory_warn" "Użycie RAM: $usedPct%"
    } else {
        Log "OK" "RAM: $usedPct% użyte ($freeMB MB wolne)"
    }
}

function CheckDisk() {
    $disk = Get-PSDrive E -ErrorAction SilentlyContinue
    if ($disk) {
        $usedPct = [math]::Round(($disk.Used / ($disk.Used + $disk.Free)) * 100, 1)
        $freeGB  = [math]::Round($disk.Free / 1GB, 1)
        if ($usedPct -gt 95) {
            Log "ERR" "Dysk E: $usedPct% ($freeGB GB wolne) — KRYTYCZNE!"
            AddAlert "critical" "disk_full" "Dysk E: $usedPct% zapełniony"
        } elseif ($usedPct -gt 85) {
            Log "WARN" "Dysk E: $usedPct% ($freeGB GB wolne)"
        } else {
            Log "OK" "Dysk E: $usedPct% ($freeGB GB wolne)"
        }
    }
}

function CheckNodeProcesses() {
    $nodeProcs = Get-Process node -ErrorAction SilentlyContinue
    if ($nodeProcs) {
        $count = $nodeProcs.Count
        $totalMB = [math]::Round(($nodeProcs | Measure-Object WorkingSet -Sum).Sum / 1MB, 0)
        Log "OK" "Node.js: $count procesów, łącznie $totalMB MB RAM"
        foreach ($p in $nodeProcs) {
            $mb = [math]::Round($p.WorkingSet / 1MB, 0)
            if ($mb -gt 500) {
                Log "WARN" "Node PID $($p.Id): $mb MB RAM — wysokie zużycie"
            }
        }
    } else {
        Log "WARN" "Brak aktywnych procesów Node.js"
    }
}

function CheckGit() {
    Push-Location $proj
    $status = git status --short 2>&1
    $behind = git rev-list HEAD..origin/main --count 2>&1
    Pop-Location
    if ($behind -match '^\d+$' -and [int]$behind -gt 0) {
        Log "WARN" "Git: $behind commitów za origin/main"
        AddAlert "low" "git_behind" "Repozytorium jest $behind commitów za origin/main"
    } else {
        Log "OK" "Git: zsynchronizowany z origin/main"
    }
    if ($status) {
        Log "INFO" "Git: niezatwierdzone zmiany: $status"
    }
}

function CheckNodeLink() {
    $nodeExe = "$proj\tools\nodejs\node.exe"
    if (Test-Path $nodeExe) {
        $item = Get-Item $nodeExe
        if ($item.LinkType -ne "SymbolicLink") {
            Log "WARN" "node.exe NIE jest symlinklem (typ: '$($item.LinkType)')"
        } else {
            Log "OK" "node.exe symlink → $($item.Target)"
        }
    }
}

function CheckBackendHealth() {
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:3001/health" -TimeoutSec 5 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            Log "OK" "Backend /health: HTTP 200"
        } else {
            Log "WARN" "Backend /health: HTTP $($resp.StatusCode)"
        }
    } catch {
        Log "ERR" "Backend /health: niedostępny ($_)"
        AddAlert "critical" "backend_health" "Backend /health endpoint niedostępny"
    }
}

# ─── GŁÓWNA PĘTLA ─────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║    GRAŻYNA 5.0 — AUTO-MONITORING URUCHOMIONY   ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "  Interwał: ${interval}s | Log: $logFile" -ForegroundColor Gray
Write-Host "  Ctrl+C aby zatrzymać" -ForegroundColor Gray
Write-Host ""

Log "INFO" "=== MONITORING START ==="

$iteration = 0
while ($true) {
    $iteration++
    $script:alerts = @()  # reset alertów per iteracja

    Write-Host ""
    Write-Host "─── Sprawdzenie #$iteration @ $(Get-Date -Format 'HH:mm:ss') ───" -ForegroundColor DarkCyan

    # Sprawdzenia
    CheckPort 3001 "Backend"
    CheckPort 5174 "Frontend"
    CheckBackendHealth
    CheckNodeProcesses
    CheckMemory
    CheckDisk
    CheckNodeLink

    # Git co 10 iteracji (nie za często)
    if ($iteration % 10 -eq 0) { CheckGit }

    # Podsumowanie alertów
    if ($script:alerts.Count -gt 0) {
        Write-Host ""
        Write-Host "  🔔 $($script:alerts.Count) alertów w tej iteracji:" -ForegroundColor Yellow
        $script:alerts | ForEach-Object {
            Write-Host "     [$($_.severity.ToUpper())] $($_.message)" -ForegroundColor $(if($_.severity -eq 'critical'){'Red'}else{'Yellow'})
        }
    } else {
        Write-Host "  ✅ Wszystko OK" -ForegroundColor Green
    }

    Start-Sleep -Seconds $interval
}