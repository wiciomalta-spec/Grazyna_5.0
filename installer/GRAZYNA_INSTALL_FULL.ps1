# ============================================================
# GRAŻYNA 5.0 — PEŁNA INSTALACJA ŚRODOWISKA
# Uruchom jako Administrator w PowerShell
# Data: 2026-05-29
# ============================================================

$proj    = "E:\Grazyna_5.0"
$nodeExe = "$proj\tools\nodejs\node.exe"
$npmCmd  = "$proj\tools\nodejs\npm.cmd"
$pyExe   = "$proj\tools\PythonPortable\python.exe"
$errors  = @()

function Step($n, $total, $msg) {
    Write-Host ""
    Write-Host "[ $n/$total ] $msg" -ForegroundColor Cyan
}
function OK($msg)   { Write-Host "  ✅ $msg" -ForegroundColor Green }
function WARN($msg) { Write-Host "  ⚠️  $msg" -ForegroundColor Yellow }
function ERR($msg)  { Write-Host "  ❌ $msg" -ForegroundColor Red; $script:errors += $msg }
function INFO($msg) { Write-Host "  → $msg" -ForegroundColor Gray }

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║    GRAŻYNA 5.0 — PEŁNA INSTALACJA ŚRODOWISKA   ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Magenta

# ─────────────────────────────────────────────
# KROK 1: WERYFIKACJA NODE.JS
# ─────────────────────────────────────────────
Step 1 10 "Weryfikacja Node.js"

if (Test-Path $nodeExe) {
    $nodeVer = & $nodeExe --version 2>&1
    $npmVer  = & $npmCmd  --version 2>&1
    OK "Node.js: $nodeVer"
    OK "npm:     $npmVer"

    # Sprawdź typ pliku node.exe
    $nodeItem = Get-Item $nodeExe
    if ($nodeItem.LinkType -eq "SymbolicLink") {
        OK "node.exe jest symlinklem → $($nodeItem.Target)"
    } elseif ($nodeItem.LinkType -eq $null) {
        $hardlinks = (fsutil hardlink list $nodeExe 2>&1) -split "`n" | Where-Object { $_ -match "\\" }
        if ($hardlinks.Count -gt 1) {
            WARN "node.exe jest hardlinkiem ($($hardlinks.Count) linki). Działa poprawnie ale zajmuje 2x miejsce."
            INFO "Aby naprawić: uruchom GRAZYNA_FIX_NODELINK.ps1 jako Admin po zatrzymaniu Node.js"
        } else {
            WARN "node.exe to zwykły plik (66.8 MB). Rozważ zamianę na symlink."
        }
    }
} else {
    ERR "node.exe nie znaleziony w $nodeExe"
    INFO "Sprawdź czy Node.js jest zainstalowany w tools\nodejs\"
}

# ─────────────────────────────────────────────
# KROK 2: WERYFIKACJA PYTHON
# ─────────────────────────────────────────────
Step 2 10 "Weryfikacja Python"

if (Test-Path $pyExe) {
    $pyVer = & $pyExe --version 2>&1
    OK "Python Portable: $pyVer"
} else {
    WARN "Python Portable nie znaleziony w tools\PythonPortable\"
}

# Sprawdź system Python
$sysPy = Get-Command python -ErrorAction SilentlyContinue
if ($sysPy) {
    $sysPyVer = & python --version 2>&1
    OK "System Python: $sysPyVer"
} else {
    WARN "System Python nie znaleziony w PATH"
}

# ─────────────────────────────────────────────
# KROK 3: BACKEND — npm install
# ─────────────────────────────────────────────
Step 3 10 "Backend — npm install"

$backendPath = "$proj\backend"
if (Test-Path "$backendPath\package.json") {
    Push-Location $backendPath
    if (Test-Path "node_modules") {
        OK "node_modules już istnieje"
        INFO "Sprawdzam czy aktualne..."
        $result = & $npmCmd install --prefer-offline 2>&1
        if ($LASTEXITCODE -eq 0) { OK "npm install OK" }
        else { ERR "npm install backend failed: $result" }
    } else {
        INFO "Instaluję zależności backendu..."
        $result = & $npmCmd install 2>&1
        if ($LASTEXITCODE -eq 0) { OK "npm install backend OK" }
        else { ERR "npm install backend failed" }
    }
    Pop-Location
} else {
    ERR "Nie znaleziono backend\package.json"
}

# ─────────────────────────────────────────────
# KROK 4: FRONTEND — npm install
# ─────────────────────────────────────────────
Step 4 10 "Frontend — npm install"

$frontendPath = "$proj\frontend"
if (Test-Path "$frontendPath\package.json") {
    Push-Location $frontendPath
    if (Test-Path "node_modules") {
        OK "node_modules już istnieje"
        $result = & $npmCmd install --prefer-offline 2>&1
        if ($LASTEXITCODE -eq 0) { OK "npm install OK" }
        else { ERR "npm install frontend failed: $result" }
    } else {
        INFO "Instaluję zależności frontendu..."
        $result = & $npmCmd install 2>&1
        if ($LASTEXITCODE -eq 0) { OK "npm install frontend OK" }
        else { ERR "npm install frontend failed" }
    }
    Pop-Location
} else {
    ERR "Nie znaleziono frontend\package.json"
}

# ─────────────────────────────────────────────
# KROK 5: PRISMA GENERATE
# ─────────────────────────────────────────────
Step 5 10 "Prisma — generowanie klienta"

Push-Location "$proj\backend"
if (Test-Path "node_modules\.bin\prisma") {
    INFO "Uruchamiam prisma generate..."
    $result = & $npmCmd run db:generate 2>&1
    if ($LASTEXITCODE -eq 0) { OK "Prisma client wygenerowany" }
    else {
        WARN "Prisma generate zwróciło błąd (może brak połączenia z DB — to normalne w dev)"
        INFO "Uruchom ręcznie gdy DB jest dostępna: npm run db:generate"
    }
} else {
    WARN "Prisma nie znaleziona w node_modules — uruchom npm install najpierw"
}
Pop-Location

# ─────────────────────────────────────────────
# KROK 6: BACKEND BUILD (TypeScript → JS)
# ─────────────────────────────────────────────
Step 6 10 "Backend — kompilacja TypeScript"

Push-Location "$proj\backend"
if (Test-Path "dist\index.js") {
    OK "dist\index.js już istnieje (build aktualny)"
    $distAge = (Get-Item "dist\index.js").LastWriteTime
    $srcAge  = (Get-Item "src\index.ts").LastWriteTime
    if ($srcAge -gt $distAge) {
        WARN "src\index.ts jest nowszy niż dist\index.js — rebuild zalecany"
        INFO "Uruchamiam npm run build..."
        $result = & $npmCmd run build 2>&1
        if ($LASTEXITCODE -eq 0) { OK "Build OK" }
        else { ERR "Build failed: sprawdź błędy TypeScript" }
    } else {
        OK "dist/ jest aktualny"
    }
} else {
    INFO "Brak dist/ — uruchamiam build..."
    $result = & $npmCmd run build 2>&1
    if ($LASTEXITCODE -eq 0) { OK "Build OK — dist\index.js utworzony" }
    else { ERR "Build failed: $result" }
}
Pop-Location

# ─────────────────────────────────────────────
# KROK 7: PYTHON DEPENDENCIES
# ─────────────────────────────────────────────
Step 7 10 "Python — instalacja zależności"

$reqFile = "$proj\requirements.txt"
if (Test-Path $reqFile) {
    INFO "requirements.txt znaleziony"
    if (Test-Path $pyExe) {
        $result = & $pyExe -m pip install -r $reqFile --quiet 2>&1
        if ($LASTEXITCODE -eq 0) { OK "Python deps zainstalowane (Portable Python)" }
        else { WARN "pip install zwróciło błąd: $result" }
    } elseif ($sysPy) {
        $result = & python -m pip install -r $reqFile --quiet 2>&1
        if ($LASTEXITCODE -eq 0) { OK "Python deps zainstalowane (System Python)" }
        else { WARN "pip install zwróciło błąd" }
    } else {
        WARN "Brak Pythona — pomiń lub zainstaluj Python"
    }
} else {
    WARN "Brak requirements.txt"
}

# ─────────────────────────────────────────────
# KROK 8: WERYFIKACJA .ENV
# ─────────────────────────────────────────────
Step 8 10 "Weryfikacja plików .env"

$envFiles = @(
    @{ path="$proj\.env";          name="Root .env" },
    @{ path="$proj\backend\.env";  name="Backend .env" },
    @{ path="$proj\frontend\.env"; name="Frontend .env" }
)

foreach ($ef in $envFiles) {
    if (Test-Path $ef.path) {
        $content = Get-Content $ef.path -Raw
        OK "$($ef.name) istnieje"
        # Sprawdź kluczowe zmienne
        if ($ef.name -match "Backend") {
            if ($content -match "DATABASE_URL") { INFO "DATABASE_URL ✓" }
            else { WARN "Brak DATABASE_URL w backend .env!" }
            if ($content -match "JWT_SECRET") { INFO "JWT_SECRET ✓" }
            else { WARN "Brak JWT_SECRET w backend .env!" }
        }
        if ($ef.name -match "Frontend") {
            if ($content -match "VITE_API_URL") { INFO "VITE_API_URL ✓" }
            if ($content -match "VITE_ENV")     { INFO "VITE_ENV ✓" }
            if ($content -match "VITE_DEBUG")   { INFO "VITE_DEBUG ✓" }
        }
    } else {
        ERR "$($ef.name) NIE ISTNIEJE — utwórz plik .env!"
    }
}

# ─────────────────────────────────────────────
# KROK 9: WERYFIKACJA PORTÓW
# ─────────────────────────────────────────────
Step 9 10 "Weryfikacja portów sieciowych"

$ports = @(
    @{ port=3001; name="Backend API" },
    @{ port=5173; name="Frontend Vite (domyślny)" },
    @{ port=5174; name="Frontend Vite (alternatywny)" },
    @{ port=5432; name="PostgreSQL" },
    @{ port=6379; name="Redis" }
)

foreach ($p in $ports) {
    $listening = netstat -ano 2>&1 | findstr ":$($p.port)" | findstr "LISTENING"
    if ($listening) {
        $pid = ($listening -split '\s+')[-1]
        OK "$($p.name) :$($p.port) — DZIAŁA (PID: $pid)"
    } else {
        if ($p.port -in @(5432, 6379)) {
            INFO "$($p.name) :$($p.port) — nie działa (uruchom Docker)"
        } else {
            WARN "$($p.name) :$($p.port) — nie działa"
        }
    }
}

# ─────────────────────────────────────────────
# KROK 10: RAPORT KOŃCOWY
# ─────────────────────────────────────────────
Step 10 10 "Raport końcowy"

Write-Host ""
if ($errors.Count -eq 0) {
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║   ✅ INSTALACJA ZAKOŃCZONA BEZ BŁĘDÓW!          ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Green
} else {
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║   ⚠️  INSTALACJA Z OSTRZEŻENIAMI ($($errors.Count) błędów)    ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Błędy do naprawy:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  ❌ $_" -ForegroundColor Red }
}

Write-Host ""
Write-Host "📌 NASTĘPNE KROKI:" -ForegroundColor Cyan
Write-Host "  1. Uruchom system:    & '$proj\GRAZYNA_START.ps1'" -ForegroundColor White
Write-Host "  2. Otwórz panel:      $proj\GRAZYNA_PANEL.html" -ForegroundColor White
Write-Host "  3. Frontend:          http://localhost:5174" -ForegroundColor White
Write-Host "  4. Backend API:       http://localhost:3001/api" -ForegroundColor White
Write-Host "  5. Health check:      http://localhost:3001/health" -ForegroundColor White
Write-Host ""