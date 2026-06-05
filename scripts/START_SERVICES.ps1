# START_SERVICES.ps1 – Uruchomienie usług GRAŻYNA 5.0
Set-Location "E:\Grazyna_5.0"

# Sprawdź, czy PM2 jest zainstalowany
if (-not (Get-Command pm2 -ErrorAction SilentlyContinue)) {
    Write-Host "[SERVICES] Instalowanie PM2..."
    npm install pm2 -g
}

# Uruchom Backend
Write-Host "[SERVICES] Uruchamianie Backend..."
pm2 start backend/src/system/GRAZYNA_BACKEND_FIX.js --name GRAZYNA_BACKEND --watch
pm2 save

# Uruchom Frontend (jeśli istnieje)
$frontendPath = "E:\Grazyna_5.0\frontend"
if (Test-Path $frontendPath) {
    Write-Host "[SERVICES] Uruchamianie Frontend..."
    pm2 start "npm run dev" --name GRAZYNA_FRONTEND --cwd $frontendPath --watch
    pm2 save
} else {
    Write-Host "[SERVICES] ⚠️  Katalog frontend nie istnieje: $frontendPath" -ForegroundColor Yellow
}

# Zapisz konfigurację PM2
pm2 startup
pm2 save

Write-Host "[SERVICES] ✅ Usługi uruchomione!" -ForegroundColor Green
Write-Host "[SERVICES] Backend: http://localhost:3001" -ForegroundColor Cyan
Write-Host "[SERVICES] Frontend: http://localhost:5174" -ForegroundColor Cyan
