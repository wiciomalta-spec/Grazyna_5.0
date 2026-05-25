$ErrorActionPreference = 'Stop'
Write-Host '🦞 GRAŻYNA 5.0 PORTABLE MODE' -ForegroundColor Cyan
Write-Host 'Tryb lekki, lokalny i odporny na brak części usług' -ForegroundColor Green

if (-not (Test-Path 'frontend\node_modules')) {
  Write-Host '▶ Instaluję frontend'
  Push-Location frontend
  npm install --silent
  Pop-Location
}

if (-not (Test-Path 'backend\node_modules')) {
  Write-Host '▶ Instaluję backend'
  Push-Location backend
  npm install --silent
  Pop-Location
}

if (-not (Test-Path 'backend\.env')) {
@"
NODE_ENV=development
PORT=3001
DATABASE_URL=postgresql://grazyna:grazyna123@localhost:5432/grazyna_db
REDIS_URL=redis://localhost:6379
JWT_SECRET=portable-mode-secret
CORS_ORIGIN=http://localhost:5173
"@ | Out-File -FilePath 'backend\.env' -Encoding UTF8
}

Start-Process cmd -ArgumentList '/k', 'cd backend && npm run dev'
Start-Sleep -Seconds 3
Start-Process cmd -ArgumentList '/k', 'cd frontend && npm run dev'
Write-Host '✓ Portable mode uruchomiony' -ForegroundColor Green
