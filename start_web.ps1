Write-Host "🌐 START WEB GUI"

$Root = "E:\Grazyna_5.0"

# backend
if (Test-Path "$Root\backend\package.json") {
    Start-Process powershell -ArgumentList "-NoExit","-Command","cd $Root\backend; npm run dev"
    Write-Host "✅ Backend start command: cd backend; npm run dev"
} else {
    Write-Host "❌ backend\package.json not found"
}

# frontend
if (Test-Path "$Root\frontend\package.json") {
    Start-Process powershell -ArgumentList "-NoExit","-Command","cd $Root\frontend; npm run dev"
    Write-Host "✅ Frontend start command: cd frontend; npm run dev"
} else {
    Write-Host "❌ frontend\package.json not found"
}

Write-Host "ℹ️ Oczekiwane adresy wg README:"
Write-Host " - Frontend: http://localhost:5173"
Write-Host " - Backend API: http://localhost:3001/api"
