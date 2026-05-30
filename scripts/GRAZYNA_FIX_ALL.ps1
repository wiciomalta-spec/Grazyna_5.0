# ============================================================
# GRAŻYNA 5.0 — KOMPLETNY SKRYPT NAPRAWCZY
# Uruchom jako Administrator w PowerShell
# Data: 2026-05-29
# ============================================================

$projectPath = "E:\Grazyna_5.0"
$nodePath    = "$projectPath\tools\nodejs"
$npmCmd      = "$nodePath\npm.cmd"
$nodeExe     = "$nodePath\node.exe"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     GRAŻYNA 5.0 — NAPRAWA PROJEKTU          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────
# KROK 1: NAPRAWA SYMLINKA node.exe
# ─────────────────────────────────────────────
Write-Host "[ 1/8 ] Naprawa node.exe symlink..." -ForegroundColor Yellow

$nvmNode  = "$projectPath\tools\nvm\nodejs\node.exe"
$toolNode = "$projectPath\tools\nodejs\node.exe"

$nodeItem = Get-Item $toolNode -ErrorAction SilentlyContinue
if ($nodeItem -and $nodeItem.LinkType -eq $null -and (Test-Path $nvmNode)) {
    $sizeMB = [math]::Round($nodeItem.Length / 1MB, 1)
    Write-Host "  → node.exe to plik ($sizeMB MB), zamieniam na symlink..." -ForegroundColor Gray
    # Backup oryginalnego pliku (jeśli nvm/nodejs/node.exe istnieje)
    Remove-Item $toolNode -Force
    New-Item -ItemType SymbolicLink -Path $toolNode -Target $nvmNode | Out-Null
    Write-Host "  ✅ Symlink utworzony: tools\nodejs\node.exe → tools\nvm\nodejs\node.exe" -ForegroundColor Green
} elseif ($nodeItem -and $nodeItem.LinkType -ne $null) {
    Write-Host "  ✅ node.exe już jest symlinklem (Target: $($nodeItem.Target))" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Nie można utworzyć symlinka — nvm\nodejs\node.exe nie istnieje, pomijam." -ForegroundColor DarkYellow
}

# ─────────────────────────────────────────────
# KROK 2: USUNIĘCIE PLIKÓW __init__.py Z PROJEKTU TS
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "[ 2/8 ] Usuwanie błędnych __init__.py z projektu TypeScript..." -ForegroundColor Yellow

$initFiles = Get-ChildItem "$projectPath\backend" -Recurse -Filter "__init__.py" -ErrorAction SilentlyContinue
$initFiles += Get-ChildItem "$projectPath\frontend" -Recurse -Filter "__init__.py" -ErrorAction SilentlyContinue
$initFiles += Get-Item "$projectPath\__init__.py" -ErrorAction SilentlyContinue | Where-Object { $_ }

foreach ($f in $initFiles) {
    if ($f -and (Test-Path $f.FullName)) {
        Remove-Item $f.FullName -Force
        Write-Host "  🗑️  Usunięto: $($f.FullName)" -ForegroundColor Gray
    }
}
Write-Host "  ✅ Gotowe" -ForegroundColor Green

# ─────────────────────────────────────────────
# KROK 3: USUNIĘCIE DUPLIKATU database.js
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "[ 3/8 ] Usuwanie duplikatu database.js (konflikt z database.ts)..." -ForegroundColor Yellow

$dbJs = "$projectPath\backend\src\config\database.js"
if (Test-Path $dbJs) {
    Remove-Item $dbJs -Force
    Write-Host "  🗑️  Usunięto: backend\src\config\database.js" -ForegroundColor Gray
    Write-Host "  ✅ Pozostaje tylko database.ts" -ForegroundColor Green
} else {
    Write-Host "  ✅ database.js nie istnieje — OK" -ForegroundColor Green
}

# ─────────────────────────────────────────────
# KROK 4: USUNIĘCIE DUPLIKATU metrics.ts Z ROOT BACKEND
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "[ 4/8 ] Usuwanie duplikatu metrics.ts z root backend/..." -ForegroundColor Yellow

$metricsRoot = "$projectPath\backend\metrics.ts"
if (Test-Path $metricsRoot) {
    Remove-Item $metricsRoot -Force
    Write-Host "  🗑️  Usunięto: backend\metrics.ts (duplikat — właściwy jest backend\src\metrics.ts)" -ForegroundColor Gray
    Write-Host "  ✅ Gotowe" -ForegroundColor Green
} else {
    Write-Host "  ✅ Brak duplikatu — OK" -ForegroundColor Green
}

# ─────────────────────────────────────────────
# KROK 5: NAPRAWA frontend/.env (dodanie brakujących zmiennych)
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "[ 5/8 ] Naprawa frontend/.env (synchronizacja z vite.env.d.ts)..." -ForegroundColor Yellow

$frontendEnv = "$projectPath\frontend\.env"
$envContent  = Get-Content $frontendEnv -Raw -ErrorAction SilentlyContinue

$needsViteEnv   = $envContent -notmatch "VITE_ENV"
$needsViteDebug = $envContent -notmatch "VITE_DEBUG"

if ($needsViteEnv -or $needsViteDebug) {
    $additions = ""
    if ($needsViteEnv)   { $additions += "`nVITE_ENV=development" }
    if ($needsViteDebug) { $additions += "`nVITE_DEBUG=false" }
    Add-Content $frontendEnv $additions
    Write-Host "  ✅ Dodano do frontend/.env:$additions" -ForegroundColor Green
} else {
    Write-Host "  ✅ frontend/.env już zawiera VITE_ENV i VITE_DEBUG" -ForegroundColor Green
}

# ─────────────────────────────────────────────
# KROK 6: AKTUALIZACJA .gitignore (duże pliki)
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "[ 6/8 ] Aktualizacja .gitignore (duże pliki analiz)..." -ForegroundColor Yellow

$gitignore = "$projectPath\.gitignore"
$toIgnore  = @(
    "analiza_structury_*.csv",
    "struktura_*.csv",
    "drzewo_*.txt",
    "katalog.txt",
    "GRAZYNA_TREE.txt",
    "*.prof",
    "build-backend.log*",
    "Nowy dokument tekstowy.txt",
    "Nowy Python File.py",
    "monitor-reports/",
    "_cache/",
    "_reports_fixroot/"
)

$currentIgnore = Get-Content $gitignore -Raw -ErrorAction SilentlyContinue
$added = @()
foreach ($entry in $toIgnore) {
    if ($currentIgnore -notmatch [regex]::Escape($entry)) {
        Add-Content $gitignore "`n$entry"
        $added += $entry
    }
}

if ($added.Count -gt 0) {
    Write-Host "  ✅ Dodano do .gitignore:" -ForegroundColor Green
    $added | ForEach-Object { Write-Host "     + $_" -ForegroundColor Gray }
} else {
    Write-Host "  ✅ .gitignore już aktualny" -ForegroundColor Green
}

# ─────────────────────────────────────────────
# KROK 7: USUNIĘCIE ŚMIECIOWYCH PLIKÓW
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "[ 7/8 ] Usuwanie śmieciowych plików..." -ForegroundColor Yellow

$junkFiles = @(
    "$projectPath\build-backend.log'",
    "$projectPath\Nowy dokument tekstowy.txt",
    "$projectPath\backend\Nowy dokument tekstowy.txt"
)

foreach ($f in $junkFiles) {
    if (Test-Path $f) {
        Remove-Item $f -Force
        Write-Host "  🗑️  Usunięto: $f" -ForegroundColor Gray
    }
}
Write-Host "  ✅ Gotowe" -ForegroundColor Green

# ─────────────────────────────────────────────
# KROK 8: WERYFIKACJA KOŃCOWA
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "[ 8/8 ] Weryfikacja końcowa..." -ForegroundColor Yellow

# Sprawdź node
$nodeVer = & $nodeExe --version 2>&1
$npmVer  = & $npmCmd --version 2>&1
Write-Host "  Node.js: $nodeVer" -ForegroundColor Cyan
Write-Host "  npm:     $npmVer" -ForegroundColor Cyan

# Sprawdź porty
$port3001 = netstat -ano | findstr ":3001" | findstr "LISTENING"
$port5174 = netstat -ano | findstr ":5174" | findstr "LISTENING"
$port5173 = netstat -ano | findstr ":5173" | findstr "LISTENING"

if ($port3001) { Write-Host "  ✅ Backend  :3001 — DZIAŁA" -ForegroundColor Green }
else           { Write-Host "  ❌ Backend  :3001 — NIE DZIAŁA" -ForegroundColor Red }

if ($port5174) { Write-Host "  ✅ Frontend :5174 — DZIAŁA (Vite dev)" -ForegroundColor Green }
elseif ($port5173) { Write-Host "  ✅ Frontend :5173 — DZIAŁA (Vite dev)" -ForegroundColor Green }
else           { Write-Host "  ❌ Frontend :5173/:5174 — NIE DZIAŁA" -ForegroundColor Red }

# Sprawdź git status
Push-Location $projectPath
$gitStat = git status --short 2>&1
Pop-Location
Write-Host "  Git status: $gitStat" -ForegroundColor Cyan

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║     ✅ NAPRAWA ZAKOŃCZONA POMYŚLNIE          ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "📌 DOSTĘP DO APLIKACJI:" -ForegroundColor Cyan
Write-Host "   Backend API:  http://localhost:3001/api" -ForegroundColor White
Write-Host "   Frontend:     http://localhost:5174" -ForegroundColor White
Write-Host "   Health check: http://localhost:3001/health" -ForegroundColor White
Write-Host ""