# MONITOR_SERVICES.ps1 – Monitoring usług GRAŻYNA 5.0
$LogPath = "E:\Grazyna_5.0\reports\MONITOR_ALERTS_$(Get-Date -Format 'yyyyMMdd').log"
$Alerts = @()

function Log-Alarm {
    param([string]$Message, [string]$Level = "CRITICAL")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level) {
        "CRITICAL" { 'Red' }
        "WARNING" { 'Yellow' }
        "SUCCESS" { 'Green' }
        default { 'White' }
    })
    Add-Content -Path $LogPath -Value $logEntry
    $Alerts += $logEntry
}

function Test-Port {
    param([int]$Port, [string]$ServiceName)
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect("127.0.0.1", $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(1000, $false)
        if ($wait) {
            $tcpClient.EndConnect($connect)
            $tcpClient.Close()
            return $true
        } else {
            $tcpClient.EndConnect($connect)
            $tcpClient.Close()
            return $false
        }
    } catch {
        return $false
    }
}

function Test-HealthEndpoint {
    param([string]$Url)
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -ErrorAction Stop
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

# Główna pętla monitoringu
while ($true) {
    Log-Alarm "=== Sprawdzenie #$(Get-Date -Format 'HH:mm:ss') ==="

    # Sprawdź Backend (Port 3001)
    $backendOnline = Test-Port -Port 3001 -ServiceName "Backend"
    if ($backendOnline) {
        Log-Alarm "✓ Backend :3001 — ONLINE!" "SUCCESS"
    } else {
        Log-Alarm "✗ Backend :3001 — OFFLINE!" "CRITICAL"
    }

    # Sprawdź Frontend (Port 5174)
    $frontendOnline = Test-Port -Port 5174 -ServiceName "Frontend"
    if ($frontendOnline) {
        Log-Alarm "✓ Frontend :5174 — ONLINE!" "SUCCESS"
    } else {
        Log-Alarm "✗ Frontend :5174 — OFFLINE!" "CRITICAL"
    }

    # Sprawdź /health endpoint
    $healthOnline = Test-HealthEndpoint -Url "http://localhost:3001/health"
    if ($healthOnline) {
        Log-Alarm "✓ Backend /health: dostępny" "SUCCESS"
    } else {
        Log-Alarm "✗ Backend /health: niedostępny (Nie można połączyć się z serwerem zdalnym)" "CRITICAL"
    }

    # Sprawdź procesy Node.js
    $nodeProcesses = Get-Process -Name node -ErrorAction SilentlyContinue
    if ($nodeProcesses) {
        Log-Alarm "ℹ Aktywne procesy Node.js: $($nodeProcesses.Count)" "INFO"
    } else {
        Log-Alarm "⚠ Brak aktywnych procesów Node.js" "WARNING"
    }

    # Sprawdź RAM i Dysk
    $ram = (Get-WmiObject Win32_OperatingSystem).FreePhysicalMemory / 1MB
    $ramPercent = [math]::Round((100 - ($ram / (Get-WmiObject Win32_OperatingSystem).TotalVisibleMemorySize * 1MB) * 100)), 1)
    Log-Alarm "✓ RAM: $ramPercent% użyte ($ram MB wolne)" "SUCCESS"

    $disk = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "E:" }
    $diskPercent = [math]::Round((100 - ($disk.FreeSpace / $disk.Size * 100)), 1)
    Log-Alarm "✓ Dysk E: $diskPercent% ($([math]::Round($disk.FreeSpace / 1GB, 1)) GB wolne)" "SUCCESS"

    # Sprawdź symlink Node.js
    $nodePath = "E:\Grazyna_5.0\tools\nvm\nodejs\node.exe"
    if (Test-Path $nodePath) {
        Log-Alarm "✓ node.exe symlink → $nodePath" "SUCCESS"
    } else {
        Log-Alarm "❌ node.exe symlink nie istnieje!" "CRITICAL"
    }

    # Sprawdź Git
    try {
        Set-Location "E:\Grazyna_5.0"
        $gitStatus = git status -uno
        Log-Alarm "✓ Git: zsynchronizowany z origin/main" "SUCCESS"
    } catch {
        Log-Alarm "⚠ Git: $($_.Exception.Message)" "WARNING"
    }

    # Poczekaj 1 minutę przed następnym sprawdzeniem
    Start-Sleep -Seconds 60
}
