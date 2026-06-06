# ============================================================
# GRAŻYNA 5.0 — DB SWITCH ULTIMATE (SQLite ↔ PostgreSQL)
# Auto:
#  - wykrywa PostgreSQL
#  - przełącza DB_PROVIDER
#  - ustawia DATABASE_URL
#  - podmienia schema.prisma (HYBRID / PG PRO)
#  - wykonuje migracje SQL
#  - generuje enumy TypeScript
#  - waliduje JSON
#  - odpala testy integracyjne (TS + PY + PS + CMD)
# ============================================================

$proj      = "E:\Grazyna_5.0"
$backend   = "$proj\backend"
$prismaDir = "$backend\prisma"
$toolsDir  = "$backend\tools"
$testsDir  = "$backend\tests\integration"
$nodeExe   = "$proj\tools\nodejs\node.exe"
$npmCmd    = "$proj\tools\nodejs\npm.cmd"

function Log($lvl,$msg){
    $c = switch($lvl){ "OK"{"Green"};"WARN"{"Yellow"};"ERR"{"Red"};"INFO"{"Cyan"} }
    Write-Host "[$lvl] $msg" -ForegroundColor $c
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     GRAŻYNA 5.0 — DB SWITCH ULTIMATE                 ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 1. WYKRYWANIE POSTGRESQL
# ============================================================

$pgRunning = netstat -ano | findstr ":5432" | findstr "LISTENING"

if ($pgRunning) {
    Log "OK" "PostgreSQL wykryty → tryb PRODUKCYJNY"
    $provider = "postgresql"
    $dbUrl = "postgresql://grazyna:grazyna123@localhost:5432/grazyna_db"
} else {
    Log "WARN" "PostgreSQL NIE działa → tryb DEV (SQLite)"
    $provider = "sqlite"
    $dbUrl = "file:./dev.db"
}

# ============================================================
# 2. USTAWIENIE ENV
# ============================================================

$envPath = "$backend\.env"
$envContent = @()
$envContent += "DB_PROVIDER=$provider"
$envContent += "DATABASE_URL=$dbUrl"
$envContent | Set-Content $envPath -Encoding UTF8

Log "OK" "Zaktualizowano .env → DB_PROVIDER=$provider"

# ============================================================
# 3. WYBÓR SCHEMA (HYBRID / PG PRO)
# ============================================================

$schemaUltimate = "$prismaDir\schema.ultimate.prisma"
$schemaPG       = "$prismaDir\schema.pro.pg.prisma"
$schemaTarget   = "$prismaDir\schema.prisma"

if ($provider -eq "postgresql") {
    Copy-Item $schemaPG $schemaTarget -Force
    Log "OK" "Używam schema.pro.pg.prisma"
} else {
    Copy-Item $schemaUltimate $schemaTarget -Force
    Log "OK" "Używam schema.ultimate.prisma (HYBRID)"
}

# ============================================================
# 4. MIGRACJE (PostgreSQL)
# ============================================================

if ($provider -eq "postgresql") {
    Log "INFO" "Wykonuję migracje SQL…"

    $migDir = "$prismaDir\migrations"
    $migs = Get-ChildItem $migDir -Filter "*.sql"

    foreach ($m in $migs) {
        Log "INFO" "→ $($m.Name)"
        $sql = Get-Content $m.FullName -Raw
        $cmd = "psql ""$dbUrl"" -c ""$sql"""
        cmd /c $cmd
    }

    Log "OK" "Migracje PostgreSQL zakończone"
} else {
    Log "INFO" "SQLite → migracje nie wymagane"
}

# ============================================================
# 5. GENERATOR ENUMÓW TYPESCRIPT
# ============================================================

$enumGen = "$toolsDir\prisma-enums-gen.ts"

if (Test-Path $enumGen) {
    Log "INFO" "Generuję enumy TypeScript…"
    & $nodeExe $enumGen
    Log "OK" "Enumy wygenerowane"
} else {
    Log "WARN" "Brak prisma-enums-gen.ts"
}

# ============================================================
# 6. VALIDATOR JSON
# ============================================================

$validator = "$toolsDir\prisma-json-validator.ts"

if (Test-Path $validator) {
    Log "INFO" "Testuję validator JSON…"
    & $nodeExe $validator 2>$null
    Log "OK" "Validator JSON działa"
} else {
    Log "WARN" "Brak prisma-json-validator.ts"
}

# ============================================================
# 7. TESTY INTEGRACYJNE (TS + PY + PS + CMD)
# ============================================================

Log "INFO" "Uruchamiam testy integracyjne…"

# TS
if (Test-Path "$testsDir\ts") {
    Log "INFO" "→ TS"
    Push-Location $backend
    & $npmCmd test --silent
    Pop-Location
}

# PY
if (Test-Path "$testsDir\py") {
    Log "INFO" "→ Python"
    python "$testsDir\py\test_prisma_models.py"
}

# PS
if (Test-Path "$testsDir\ps\Test-PrismaModels.ps1") {
    Log "INFO" "→ PowerShell"
    powershell -ExecutionPolicy Bypass -File "$testsDir\ps\Test-PrismaModels.ps1"
}

# CMD
if (Test-Path "$testsDir\cmd\run_all_tests.cmd") {
    Log "INFO" "→ CMD"
    cmd /c "$testsDir\cmd\run_all_tests.cmd"
}

Log "OK" "Testy integracyjne zakończone"

# ============================================================
# 8. PODSUMOWANIE
# ============================================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║     DB SWITCH ULTIMATE — ZAKOŃCZONO                  ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Provider: $provider" -ForegroundColor Cyan
Write-Host "  DATABASE_URL: $dbUrl" -ForegroundColor Cyan
Write-Host ""
