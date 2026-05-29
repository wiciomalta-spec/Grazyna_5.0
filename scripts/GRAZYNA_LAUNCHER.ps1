# 🦞 GRAŻYNA 5.0 — HYBRID LAUNCHER
# Backend (TSX) + Frontend (Vite) + Python Kernel

$ErrorActionPreference = "Stop"

Write-Host "🚀 GRAŻYNA 5.0 — HYBRID LAUNCHER" -ForegroundColor Cyan
Write-Host "Tryb hybrydowy: backend + frontend + kernel" -ForegroundColor Green

function Test-Port {
    param($port)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect("127.0.0.1", $port)
        $tcp.Close()
        return $true
    } catch { return $false }
}

# ───────────────────────────────────────────────
# BACKEND (TSX)
# ───────────────────────────────────────────────
$backendPath = "E:\Grazyna_5.0\backend"

if (-not (Test-Port 3001)) {
    Write-Host "▶ Uruchamiam backend (TSX, port 3001)..." -ForegroundColor Yellow
    Start-Process cmd -ArgumentList "/k cd /d $backendPath && npm run dev"
} else {
    Write-Host "⚠ Backend już działa na porcie 3001" -ForegroundColor DarkYellow
}

Start-Sleep -Seconds 3

# ───────────────────────────────────────────────
# FRONTEND (Vite)
# ───────────────────────────────────────────────
$frontendPath = "E:\Grazyna_5.0\frontend"

if (-not (Test-Port 5173)) {
    Write-Host "▶ Uruchamiam frontend (Vite, port 5173)..." -ForegroundColor Yellow
    Start-Process cmd -ArgumentList "/k cd /d $frontendPath && npm run dev"
} else {
    Write-Host "⚠ Frontend już działa na porcie 5173" -ForegroundColor DarkYellow
}

Start-Sleep -Seconds 2

# ───────────────────────────────────────────────
# PYTHON HYBRID KERNEL
# ───────────────────────────────────────────────
$kernelPath = "E:\Grazyna_5.0\main.py"

if (Test-Path $kernelPath) {
    Write-Host "▶ Uruchamiam Python Hybrid Kernel..." -ForegroundColor Yellow
    Start-Process pwsh -ArgumentList "-NoExit", "-Command", "cd E:\Grazyna_5.0; python main.py"
} else {
    Write-Host "❌ Nie znaleziono main.py — kernel pominięty" -ForegroundColor Red
}

Write-Host "✓ HYBRID MODE aktywny" -ForegroundColor Green
Write-Host "🧠 Kernel przełączy się automatycznie w tryb autonomous/portable" -ForegroundColor Cyan
