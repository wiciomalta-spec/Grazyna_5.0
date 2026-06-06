Write-Host "🛠 GRAŻYNA 5.0 — FRONTEND FIX" -ForegroundColor Cyan

# 1. Wymuszenie poprawnej wersji npm
Write-Host "▶ Instaluję npm@10 (kompatybilny z Node 20)" -ForegroundColor Yellow
npm install -g npm@10 --silent

# 2. Czyszczenie cache
Write-Host "▶ Czyszczę cache npm" -ForegroundColor Yellow
npm cache clean --force

# 3. Usuwanie node_modules
Write-Host "▶ Usuwam node_modules" -ForegroundColor Yellow
if (Test-Path "E:\Grazyna_5.0\frontend\node_modules") {
    Remove-Item -Recurse -Force "E:\Grazyna_5.0\frontend\node_modules"
}

# 4. Usuwanie package-lock.json
if (Test-Path "E:\Grazyna_5.0\frontend\package-lock.json") {
    Remove-Item -Force "E:\Grazyna_5.0\frontend\package-lock.json"
}

# 5. Instalacja zależności
Write-Host "▶ Instaluję zależności frontendu" -ForegroundColor Yellow
cd E:\Grazyna_5.0\frontend
npm install --silent

# 6. Uruchomienie frontendu
Write-Host "▶ Uruchamiam frontend (Vite)" -ForegroundColor Green
Start-Process cmd -ArgumentList "/k cd E:\Grazyna_5.0\frontend && npm run dev"

Write-Host "✓ Frontend naprawiony i uruchomiony" -ForegroundColor Green
