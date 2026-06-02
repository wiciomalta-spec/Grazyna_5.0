# ═══════════════════════════════════════════════════════════════════════════
# 🦞 GRAŻYNA 5.0 - INSTALATOR WINDOWS (PowerShell)
# ═══════════════════════════════════════════════════════════════════════════

$ErrorActionPreference = "Stop"

# Kolory
function Write-Step { param($msg) Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Write-Error2 { param($msg) Write-Host "✗ $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "ℹ $msg" -ForegroundColor Blue }

# Logo
Clear-Host
Write-Host @"

    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║   🦞  GRAŻYNA 5.0 - Instalator Windows                       ║
    ║                                                               ║
    ║   System Autonomicznego Zarządzania Flotą                    ║
    ║   Wersja: 5.0.0 | Build: 2026.02.10                          ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ════════════════════════════════════════════
# Sprawdzanie wymagań
# ════════════════════════════════════════════
Write-Step "Sprawdzanie wymagań systemowych..."

$missingDeps = @()

# Node.js
try {
    $nodeVersion = (node -v) -replace 'v', ''
    $majorVersion = [int]($nodeVersion -split '\.')[0]
    if ($majorVersion -lt 18) {
        Write-Error2 "Node.js >= 18.x wymagany (zainstalowano: $nodeVersion)"
        $missingDeps += "Node.js >= 18.x"
    } else {
        Write-Success "Node.js v$nodeVersion"
    }
} catch {
    Write-Error2 "Node.js nie zainstalowany"
    $missingDeps += "Node.js"
}

# npm
try {
    $npmVersion = npm -v
    Write-Success "npm $npmVersion"
} catch {
    Write-Error2 "npm nie zainstalowany"
    $missingDeps += "npm"
}

# Docker (opcjonalny)
try {
    $dockerVersion = (docker --version) -replace 'Docker version ', '' -replace ',.*', ''
    Write-Success "Docker $dockerVersion"
    $dockerAvailable = $true
} catch {
    Write-Warning "Docker nie zainstalowany (opcjonalny)"
    $dockerAvailable = $false
}

if ($missingDeps.Count -gt 0) {
    Write-Error2 "Brakujące zależności:"
    $missingDeps | ForEach-Object { Write-Host "  - $_" }
    Write-Info "Pobierz: https://nodejs.org/"
    exit 1
}

# ════════════════════════════════════════════
# Konfiguracja .env
# ════════════════════════════════════════════
Write-Step "Konfiguracja zmiennych środowiskowych..."

if (-not (Test-Path "frontend\.env")) {
    @"
VITE_API_URL=http://localhost:3001/api
VITE_WS_URL=ws://localhost:3001
VITE_APP_NAME=GRAŻYNA 5.0
VITE_APP_VERSION=5.0.0
"@ | Out-File -FilePath "frontend\.env" -Encoding UTF8
    Write-Success "Utworzono frontend\.env"
}

if (-not (Test-Path "backend\.env")) {
    $jwtSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    @"
NODE_ENV=development
PORT=3001
DATABASE_URL=postgresql://grazyna:grazyna123@localhost:5432/grazyna_db
REDIS_URL=redis://localhost:6379
JWT_SECRET=$jwtSecret
CORS_ORIGIN=http://localhost:5173
LOG_LEVEL=debug
"@ | Out-File -FilePath "backend\.env" -Encoding UTF8
    Write-Success "Utworzono backend\.env"
}

# ════════════════════════════════════════════
# Instalacja Frontend
# ════════════════════════════════════════════
Write-Step "Instalacja Frontend..."
Push-Location frontend
npm install --silent
Pop-Location
Write-Success "Frontend zainstalowany"

# ════════════════════════════════════════════
# Instalacja Backend
# ════════════════════════════════════════════
Write-Step "Instalacja Backend..."
Push-Location backend
npm install --silent
Pop-Location
Write-Success "Backend zainstalowany"

# ════════════════════════════════════════════
# Docker - PostgreSQL i Redis
# ════════════════════════════════════════════
if ($dockerAvailable) {
    Write-Step "Uruchamianie PostgreSQL i Redis..."
    
    $pgRunning = docker ps --filter "name=grazyna-postgres" --format "{{.Names}}"
    if (-not $pgRunning) {
        docker run -d --name grazyna-postgres `
            -e POSTGRES_DB=grazyna_db `
            -e POSTGRES_USER=grazyna `
            -e POSTGRES_PASSWORD=grazyna123 `
            -p 5432:5432 `
            postgres:15-alpine | Out-Null
        Write-Success "PostgreSQL uruchomiony"
    } else {
        Write-Warning "PostgreSQL już działa"
    }

    $redisRunning = docker ps --filter "name=grazyna-redis" --format "{{.Names}}"
    if (-not $redisRunning) {
        docker run -d --name grazyna-redis -p 6379:6379 redis:7-alpine | Out-Null
        Write-Success "Redis uruchomiony"
    } else {
        Write-Warning "Redis już działa"
    }

    Start-Sleep -Seconds 5
}

# ════════════════════════════════════════════
# Skrypty startowe Windows
# ════════════════════════════════════════════
Write-Step "Tworzenie skryptów startowych..."

@"
@echo off
echo 🦞 Uruchamianie GRAZYNA 5.0...
start "Backend" cmd /k "cd backend && npm run dev"
timeout /t 3 /nobreak >nul
start "Frontend" cmd /k "cd frontend && npm run dev"
echo ✓ System uruchomiony!
echo Frontend: http://localhost:5173
echo Backend:  http://localhost:3001
"@ | Out-File -FilePath "start.bat" -Encoding ASCII

@"
@echo off
echo 🛑 Zatrzymywanie GRAZYNA 5.0...
taskkill /F /IM node.exe 2>nul
echo ✓ System zatrzymany
"@ | Out-File -FilePath "stop.bat" -Encoding ASCII

Write-Success "Utworzono start.bat i stop.bat"

# ════════════════════════════════════════════
# Podsumowanie
# ════════════════════════════════════════════
Write-Host @"

═══════════════════════════════════════════════════════════════
  ✓ INSTALACJA ZAKOŃCZONA POMYŚLNIE!
═══════════════════════════════════════════════════════════════

📋 Następne kroki:

  1. Uruchom system:
     start.bat

  2. Otwórz w przeglądarce:
     http://localhost:5173

  3. Zaloguj się:
     Email:  admin@grazyna.local
     Hasło:  admin123

🛠️  Przydatne komendy:
   start.bat       - Uruchom system
   stop.bat        - Zatrzymaj system

🦞 Dziękujemy za wybór GRAŻYNA 5.0!

"@ -ForegroundColor Green
