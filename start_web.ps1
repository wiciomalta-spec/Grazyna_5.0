Write-Host "🌐 START WEB GUI"

$Root = "E:\Grazyna_5.0"
$nodePath = "$Root\tools\nodejs"
$npmCmd = "$nodePath\npm.cmd"

function Test-Port([int]$port) {
    return @(Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq "Listen" }).Count -gt 0
}

function Wait-Port([int]$port, [int]$timeoutSec) {
    $start = Get-Date
    while ((Get-Date) -lt $start.AddSeconds($timeoutSec)) {
        if (Test-Port $port) { return $true }
        Start-Sleep -Seconds 1
    }
    return $false
}

function Kill-Port([int]$port) {
    Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
      Select-Object -ExpandProperty OwningProcess -Unique |
      ForEach-Object { try { Stop-Process -Id $_ -Force } catch {} }
}

# BACKEND
if (-not (Test-Port 3001)) {
    if (-not (Test-Path "$Root\backend\node_modules")) {
        Write-Host "📦 Backend npm install..."
        Push-Location "$Root\backend"
        & $npmCmd install --prefer-offline
        Pop-Location
    }

    $backendCmd = "cd '$Root\backend'; & '$npmCmd' run dev"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd -WindowStyle Normal
    Write-Host "⏳ Czekam na backend :3001 ..."
    if (Wait-Port 3001 20) {
        Write-Host "✅ Backend READY" -ForegroundColor Green
    } else {
        Write-Host "❌ Backend timeout" -ForegroundColor Red
    }
} else {
    Write-Host "✅ Backend already running" -ForegroundColor Green
}

# FRONTEND
if (-not (Test-Port 5173) -and -not (Test-Port 5174)) {
    if (-not (Test-Path "$Root\frontend\node_modules")) {
        Write-Host "📦 Frontend npm install..."
        Push-Location "$Root\frontend"
        & $npmCmd install --prefer-offline
        Pop-Location
    }

    $frontendCmd = "cd '$Root\frontend'; & '$npmCmd' run dev"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $frontendCmd -WindowStyle Normal
    Write-Host "⏳ Czekam na frontend :5173/:5174 ..."
    $frontReady = (Wait-Port 5173 25) -or (Wait-Port 5174 25)
    if ($frontReady) {
        Write-Host "✅ Frontend READY" -ForegroundColor Green
    } else {
        Write-Host "❌ Frontend timeout" -ForegroundColor Red
    }
} else {
    Write-Host "✅ Frontend already running" -ForegroundColor Green
}

Start-Sleep -Seconds 2
$frontPort = if (Test-Port 5173) { 5173 } elseif (Test-Port 5174) { 5174 } else { $null }
if ($frontPort) {
    Start-Process "http://localhost:$frontPort"
}

Write-Host "🌍 Open:"
Write-Host " - Frontend: http://localhost:5173 (lub 5174)"
Write-Host " - Backend API: http://localhost:3001/api"
Write-Host " - Health: http://localhost:3001/api/health"
Write-Host " - Metrics: http://localhost:3001/metrics"
