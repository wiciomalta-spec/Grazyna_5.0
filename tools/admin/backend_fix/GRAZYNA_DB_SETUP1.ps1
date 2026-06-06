# ============================================================
# GRAŻYNA 5.0 — SETUP BAZY DANYCH (SQLite dev + PostgreSQL prod)
# Rozwiązuje:
#   1. Prisma bash script na Windows → użyj prisma.cmd
#   2. PostgreSQL niedostępny → SQLite dla dev
#   3. DATABASE_URL hostname docker → localhost
# ============================================================

$proj    = "E:\Grazyna_5.0"
$backend = "$proj\backend"
$nodeExe = "$proj\tools\nodejs\node.exe"

function Log($level, $msg) {
    $col = switch($level) { "OK"{"Green"}; "WARN"{"Yellow"}; "ERR"{"Red"}; "INFO"{"Cyan"} }
    $ico = switch($level) { "OK"{"✅"}; "WARN"{"⚠️"}; "ERR"{"❌"}; "INFO"{"ℹ️"} }
    Write-Host "  $ico $msg" -ForegroundColor $col
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    GRAŻYNA 5.0 — DATABASE SETUP                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─── KROK 1: Znajdź poprawny Prisma binary ────────────────
Write-Host "[ 1/5 ] Szukam Prisma binary..." -ForegroundColor Yellow

# Na Windows: prisma.cmd (nie prisma — to bash script)
$prismaCandidates = @(
    "$backend\node_modules\.bin\prisma.cmd",
    "$backend\node_modules\prisma\build\index.js",
    "$backend\node_modules\@prisma\client\scripts\postinstall.js"
)

$prismaCmd = $null
foreach ($c in $prismaCandidates) {
    if (Test-Path $c) {
        $prismaCmd = $c
        Log "OK" "Znaleziono Prisma: $c"
        break
    }
}

if (-not $prismaCmd) {
    Log "ERR" "Prisma nie znaleziona! Uruchom: npm install"
    exit 1
}

# Funkcja do uruchamiania Prisma
function Run-Prisma($args) {
    Push-Location $backend
    if ($prismaCmd -match "\.cmd$") {
        # Windows .cmd — uruchom przez cmd.exe
        $result = cmd /c "`"$prismaCmd`" $args 2>&1"
    } else {
        # Node.js script
        $result = & $nodeExe $prismaCmd $args 2>&1
    }
    Pop-Location
    return $result
}

# ─── KROK 2: Weryfikacja schema.prisma ────────────────────
Write-Host "[ 2/5 ] Weryfikacja schema.prisma..." -ForegroundColor Yellow

$schemaPath = "$backend\prisma\schema.prisma"
$schema = Get-Content $schemaPath -Raw

$provider = if ($schema -match 'provider\s*=\s*"(\w+)"') { $Matches[1] } else { "unknown" }
$dbUrl    = (Get-Content "$backend\.env" -Raw) -match 'DATABASE_URL=(.+)' | Out-Null
$dbUrl    = if ($Matches) { $Matches[1].Trim() } else { "unknown" }

Log "INFO" "Provider: $provider"
Log "INFO" "DATABASE_URL: $((Get-Content "$backend\.env" | Select-String "DATABASE_URL").Line)"

# ─── KROK 3: Sprawdź dostępność bazy ─────────────────────
Write-Host "[ 3/5 ] Sprawdzam dostępność bazy danych..." -ForegroundColor Yellow

if ($provider -eq "sqlite") {
    $dbFile = "$backend\dev.db"
    if (Test-Path $dbFile) {
        $sizeMB = [math]::Round((Get-Item $dbFile).Length / 1MB, 2)
        Log "OK" "SQLite dev.db istnieje ($sizeMB MB)"
    } else {
        Log "INFO" "SQLite dev.db nie istnieje — zostanie utworzona przez Prisma"
    }
} elseif ($provider -eq "postgresql") {
    $port5432 = netstat -ano 2>&1 | findstr ":5432" | findstr "LISTENING"
    if ($port5432) {
        Log "OK" "PostgreSQL działa na :5432"
    } else {
        Log "WARN" "PostgreSQL NIE działa na :5432"
        Log "INFO" "Przełączam na SQLite dla dev..."

        # Auto-switch do SQLite
        $envContent = Get-Content "$backend\.env" -Raw
        $envFixed = $envContent -replace "DATABASE_URL=.*(\r?\n)", "DATABASE_URL=file:./dev.db`n"
        $envFixed | Out-File "$backend\.env" -Encoding UTF8

        $schemaFixed = $schema -replace 'provider\s*=\s*"postgresql"', 'provider = "sqlite"'
        # SQLite nie obsługuje niektórych typów — napraw
        $schemaFixed = $schemaFixed -replace '@db\.Text', ''
        $schemaFixed = $schemaFixed -replace '@db\.VarChar\(\d+\)', ''
        $schemaFixed = $schemaFixed -replace 'Unsupported\("[^"]+"\)', 'String'
        $schemaFixed | Out-File $schemaPath -Encoding UTF8

        Log "OK" "Przełączono na SQLite"
        $provider = "sqlite"
    }
}

# ─── KROK 4: Prisma db push ───────────────────────────────
Write-Host "[ 4/5 ] Uruchamiam Prisma db push..." -ForegroundColor Yellow

Push-Location $backend
$env:DATABASE_URL = (Get-Content ".env" | Select-String "DATABASE_URL").Line -replace "DATABASE_URL=", ""

Write-Host "  Używam: $prismaCmd" -ForegroundColor Gray

if ($prismaCmd -match "\.cmd$") {
    $output = cmd /c "`"$prismaCmd`" db push --accept-data-loss 2>&1"
} else {
    $output = & $nodeExe $prismaCmd db push --accept-data-loss 2>&1
}

Pop-Location

$output | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

if ($output -match "Your database is now in sync" -or $output -match "already in sync") {
    Log "OK" "Prisma db push zakończony pomyślnie!"
} elseif ($output -match "error" -or $output -match "Error") {
    Log "WARN" "Prisma db push zwrócił błąd — sprawdź output powyżej"
} else {
    Log "INFO" "Prisma db push zakończony"
}

# ─── KROK 5: Restart backendu ─────────────────────────────
Write-Host "[ 5/5 ] Restart backendu..." -ForegroundColor Yellow

Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2
Log "OK" "Procesy Node.js zatrzymane"

# Uruchom backend
$devCmd = "cd /d `"$backend`" && `"$proj\tools\nodejs\node.exe`" --max-old-space-size=256 --expose-gc node_modules\tsx\dist\cli.mjs watch src\cluster-bootstrap.ts"
Start-Process cmd -ArgumentList "/k", $devCmd -WindowStyle Normal
Log "INFO" "Backend uruchamia się w nowym oknie..."
Start-Sleep 8

# Test
try {
    $health = Invoke-WebRequest "http://localhost:3001/health" -TimeoutSec 5 -ErrorAction Stop
    Log "OK" "Backend odpowiada: HTTP $($health.StatusCode)"
} catch {
    Log "WARN" "Backend jeszcze nie odpowiada — poczekaj chwilę"
}

# Test rejestracji
Write-Host ""
Write-Host "  Test rejestracji..." -ForegroundColor Cyan
try {
    $body = '{"email":"test@grazyna.pl","password":"Test1234!","username":"testuser","firstName":"Test","lastName":"User"}'
    $reg = Invoke-RestMethod "http://localhost:3001/api/auth/register" -Method POST -ContentType "application/json" -Body $body -ErrorAction Stop
    Log "OK" "Rejestracja działa! Token: $($reg.token.Substring(0,20))..."
} catch {
    $errMsg = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
    Log "WARN" "Rejestracja: $($errMsg.error ?? $_.Exception.Message)"
}

# ─── PODSUMOWANIE ─────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║    ✅ DATABASE SETUP ZAKOŃCZONY                      ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Provider:  $provider" -ForegroundColor Cyan
Write-Host "  Backend:   http://localhost:3001" -ForegroundColor White
Write-Host "  Health:    http://localhost:3001/health" -ForegroundColor White
Write-Host "  API:       http://localhost:3001/api" -ForegroundColor White
Write-Host ""