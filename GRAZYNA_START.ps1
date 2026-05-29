# ============================================================
# GRAŻYNA 5.0 — LAUNCHER (Backend + Frontend)
# Uruchom w PowerShell (nie wymaga Administratora)
# ============================================================

$projectPath = "E:\Grazyna_5.0"
$nodePath    = "$projectPath\tools\nodejs"
$npmCmd      = "$nodePath\npm.cmd"
$nodeExe     = "$nodePath\node.exe"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        GRAŻYNA 5.0 — LAUNCHER               ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Sprawdź czy już działa
$port3001 = netstat -ano | findstr ":3001" | findstr "LISTENING"
$port5174 = netstat -ano | findstr ":5174" | findstr "LISTENING"
$port5173 = netstat -ano | findstr ":5173" | findstr "LISTENING"

Write-Host "[ STATUS PRZED STARTEM ]" -ForegroundColor Yellow
if ($port3001) {
    Write-Host "  ✅ Backend  :3001 — już działa, pomijam start" -ForegroundColor Green
    $backendRunning = $true
} else {
    Write-Host "  ⭕ Backend  :3001 — nie działa, uruchamiam..." -ForegroundColor DarkYellow
    $backendRunning = $false
}

if ($port5174 -or $port5173) {
    Write-Host "  ✅ Frontend :5173/5174 — już działa, pomijam start" -ForegroundColor Green
    $frontendRunning = $true
} else {
    Write-Host "  ⭕ Frontend :5173 — nie działa, uruchamiam..." -ForegroundColor DarkYellow
    $frontendRunning = $false
}

Write-Host ""

# ─── BACKEND ───────────────────────────────────
if (-not $backendRunning) {
    Write-Host "[ BACKEND ] Sprawdzam node_modules..." -ForegroundColor Yellow
    if (-not (Test-Path "$projectPath\backend\node_modules")) {
        Write-Host "  → Instaluję zależności backendu (npm install)..." -ForegroundColor Gray
        Push-Location "$projectPath\backend"
        & $npmCmd install --prefer-offline 2>&1
        Pop-Location
    } else {
        Write-Host "  ✅ node_modules istnieje" -ForegroundColor Green
    }

    Write-Host "[ BACKEND ] Uruchamiam w nowym oknie..." -ForegroundColor Yellow
    $backendCmd = "cd '$projectPath\backend'; & '$npmCmd' run dev"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd -WindowStyle Normal
    Write-Host "  ✅ Backend uruchomiony (nowe okno PowerShell)" -ForegroundColor Green
    Write-Host "  → Czekam 3s na start..." -ForegroundColor Gray
    Start-Sleep -Seconds 3
}

# ─── FRONTEND ──────────────────────────────────
if (-not $frontendRunning) {
    Write-Host ""
    Write-Host "[ FRONTEND ] Sprawdzam node_modules..." -ForegroundColor Yellow
    if (-not (Test-Path "$projectPath\frontend\node_modules")) {
        Write-Host "  → Instaluję zależności frontendu (npm install)..." -ForegroundColor Gray
        Push-Location "$projectPath\frontend"
        & $npmCmd install --prefer-offline 2>&1
        Pop-Location
    } else {
        Write-Host "  ✅ node_modules istnieje" -ForegroundColor Green
    }

    Write-Host "[ FRONTEND ] Uruchamiam w nowym oknie..." -ForegroundColor Yellow
    $frontendCmd = "cd '$projectPath\frontend'; & '$npmCmd' run dev"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $frontendCmd -WindowStyle Normal
    Write-Host "  ✅ Frontend uruchomiony (nowe okno PowerShell)" -ForegroundColor Green
    Write-Host "  → Czekam 5s na start Vite..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
}

# ─── WERYFIKACJA ───────────────────────────────
Write-Host ""
Write-Host "[ WERYFIKACJA ]" -ForegroundColor Yellow

$port3001After = netstat -ano | findstr ":3001" | findstr "LISTENING"
$port5174After = netstat -ano | findstr ":5174" | findstr "LISTENING"
$port5173After = netstat -ano | findstr ":5173" | findstr "LISTENING"

if ($port3001After) {
    Write-Host "  ✅ Backend  :3001 — DZIAŁA" -ForegroundColor Green
} else {
    Write-Host "  ❌ Backend  :3001 — PROBLEM! Sprawdź okno backendu." -ForegroundColor Red
}

if ($port5174After -or $port5173After) {
    $fPort = if ($port5174After) { "5174" } else { "5173" }
    Write-Host "  ✅ Frontend :$fPort — DZIAŁA" -ForegroundColor Green
} else {
    Write-Host "  ❌ Frontend — PROBLEM! Sprawdź okno frontendu." -ForegroundColor Red
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║           GRAŻYNA 5.0 GOTOWA!               ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  🌐 Frontend:     http://localhost:5173  (lub :5174)" -ForegroundColor Cyan
Write-Host "  🔧 Backend API:  http://localhost:3001/api" -ForegroundColor Cyan
Write-Host "  ❤️  Health:       http://localhost:3001/health" -ForegroundColor Cyan
Write-Host "  📊 Metrics:      http://localhost:3001/metrics" -ForegroundColor Cyan
Write-Host ""