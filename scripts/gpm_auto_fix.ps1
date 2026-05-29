# ================================
#  GPM-AUTO-FIX v1.0
#  Automatyczna naprawa Node + pnpm
#  Autor: Copilot dla Bartosza
# ================================

Write-Host "`n=== GPM-AUTO-FIX: Wykrywanie środowiska Node ===" -ForegroundColor Cyan

# 1. Pobierz aktualną wersję Node
$nodeVer = node --version 2>$null

if (-not $nodeVer) {
    Write-Host "❌ Node.js nie jest zainstalowany lub nie jest w PATH" -ForegroundColor Red
    exit 1
}

Write-Host "🔍 Aktualna wersja Node: $nodeVer" -ForegroundColor Yellow

# 2. Wymagania pnpm
$requiredMajor = 22
$requiredMinor = 13

# 3. Parsowanie wersji
$parsed = $nodeVer -replace "v","" -split "\."
$major = [int]$parsed[0]
$minor = [int]$parsed[1]

# 4. Sprawdzenie zgodności
if ($major -lt $requiredMajor -or ($major -eq $requiredMajor -and $minor -lt $requiredMinor)) {
    Write-Host "⚠ Wersja Node jest za niska dla pnpm 9.x" -ForegroundColor Red
    Write-Host "   Wymagana: >= 22.13" -ForegroundColor DarkYellow

    # 5. Sprawdź dostępne wersje w GPM
    Write-Host "`n=== Sprawdzanie dostępnych wersji GPM ===" -ForegroundColor Cyan
    $gpmList = gpm list 2>$null

    if ($gpmList -match "22\.13") {
        Write-Host "✔ Znaleziono Node 22.13 — przełączam..." -ForegroundColor Green
        gpm use 22.13.0
    }
    elseif ($gpmList -match "25\.") {
        Write-Host "✔ Znaleziono Node 25.x — przełączam..." -ForegroundColor Green
        $ver25 = ($gpmList | Select-String "25\.\d+\.\d+").Matches.Value
        gpm use $ver25
    }
    else {
        Write-Host "⬇ Brak wymaganych wersji — instaluję Node 25.9.0" -ForegroundColor Yellow
        gpm install 25.9.0
        gpm use 25.9.0
    }

    Write-Host "`n✔ Node.js został naprawiony." -ForegroundColor Green
}
else {
    Write-Host "✔ Wersja Node jest kompatybilna." -ForegroundColor Green
}

# 6. Sprawdzenie pnpm
Write-Host "`n=== Sprawdzanie pnpm ===" -ForegroundColor Cyan
$pnpmVer = pnpm -v 2>$null

if (-not $pnpmVer) {
    Write-Host "⬇ pnpm nie znaleziony — instaluję..." -ForegroundColor Yellow
    npm i -g pnpm
}
else {
    Write-Host "✔ pnpm OK: $pnpmVer" -ForegroundColor Green
}

# 7. Naprawa frontendu
Write-Host "`n=== Naprawa frontendu ===" -ForegroundColor Cyan

$frontend = "E:\Grazyna_5.0\frontend"

if (-not (Test-Path $frontend)) {
    Write-Host "❌ Nie znaleziono katalogu frontendu" -ForegroundColor Red
    exit 1
}

Set-Location $frontend

Write-Host "📦 pnpm install..." -ForegroundColor Yellow
pnpm install

Write-Host "🔧 pnpm build..." -ForegroundColor Yellow
pnpm build

Write-Host "`n=== GPM-AUTO-FIX zakończony sukcesem ===" -ForegroundColor Green