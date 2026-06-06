# ============================================================
# GRAŻYNA 5.0 — DB SWITCH FRONTEND LAUNCHER
# Uruchamia panel webowy (Vite) do zarządzania DB (SQLite/PG)
# ============================================================

$proj     = "E:\Grazyna_5.0"
$frontend = "$proj\frontend"
$nodePath = "$proj\tools\nodejs"
$npmCmd   = "$nodePath\npm.cmd"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   GRAŻYNA 5.0 — DB SWITCH FRONTEND          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

function Test-Port([int]$port) {
    return @(Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq "Listen" }).Count -gt 0
}

# 1) Upewnij się, że backend API dla DB switch działa (WEB)
Write-Host "[ BACKEND DB WEB ]" -ForegroundColor Yellow
try {
    $r = Invoke-WebRequest "http://localhost:8088/db/status" -TimeoutSec 3 -ErrorAction Stop
    Write-Host "  ✅ DB SWITCH WEB API działa (http://localhost:8088)" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️ DB SWITCH WEB API nie odpowiada — uruchom GRAŻYNA_DB_SWITCH_WEB" -ForegroundColor Yellow
}

# 2) node_modules frontend
Write-Host ""
Write-Host "[ FRONTEND ] Sprawdzam node_modules..." -ForegroundColor Yellow
if (-not (Test-Path "$frontend\node_modules")) {
    Write-Host "  📦 Instaluję zależności frontendu (npm install)..." -ForegroundColor Gray
    Push-Location $frontend
    & $npmCmd install --prefer-offline
    Pop-Location
} else {
    Write-Host "  ✅ node_modules istnieje" -ForegroundColor Green
}

# 3) Start Vite (dedykowany panel DB switch)
Write-Host ""
Write-Host "[ FRONTEND ] Uruchamiam DB SWITCH DASHBOARD (Vite)..." -ForegroundColor Yellow

# Zakładamy, że w package.json jest skrypt: "db-switch": "vite --config vite.db-switch.config.ts"
$cmd = "cd `"$frontend`"; & `"$npmCmd`" run db-switch"
Start-Process powershell -ArgumentList "-NoExit","-Command",$cmd -WindowStyle Normal

Write-Host "  ✅ DB SWITCH FRONTEND uruchomiony (nowe okno PowerShell)" -ForegroundColor Green
Write-Host "  ⏳ Czekam na start Vite..." -ForegroundColor Gray

$ready = $false
for ($i=0; $i -lt 30; $i++) {
    Start-Sleep 1
    if (Test-Port 5175) { $ready = $true; break }
}

Write-Host ""
if ($ready) {
    Write-Host "  ✅ Panel DB SWITCH dostępny: http://localhost:5175" -ForegroundColor Green
    Start-Process "http://localhost:5175"
} else {
    Write-Host "  ❌ Vite (DB SWITCH) nie wystartował na :5175" -ForegroundColor Red
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   DB SWITCH FRONTEND — GOTOWY                ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""