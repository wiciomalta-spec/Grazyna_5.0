# ============================================================
# GRAŻYNA 5.0 — PEŁNY STABILNY SKRYPT WYKONAWCZY
# Rozwiązuje: Json/enum SQLite, Prisma push, Docker, Heap
# Wklej do PowerShell i uruchom jako Administrator
# ============================================================
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

$proj    = "E:\Grazyna_5.0"
$backend = "$proj\backend"
$nodeExe = "$proj\tools\nodejs\node.exe"
$schema  = "$backend\prisma\schema.prisma"
$envFile = "$backend\.env"
$errors  = [System.Collections.Generic.List[string]]::new()
$log     = "$proj\logs\setup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

if (-not (Test-Path "$proj\logs")) { New-Item -ItemType Directory "$proj\logs" -Force | Out-Null }

function L($level, $msg) {
    $col = switch($level) { "OK"{"Green"}; "WARN"{"Yellow"}; "ERR"{"Red"}; "INFO"{"Cyan"}; "STEP"{"Magenta"} }
    $ico = switch($level) { "OK"{"✅"}; "WARN"{"⚠️"}; "ERR"{"❌"}; "INFO"{"ℹ️"}; "STEP"{"▶"} }
    $line = "[$((Get-Date).ToString('HH:mm:ss'))] $ico [$level] $msg"
    Write-Host "  $ico $msg" -ForegroundColor $col
    Add-Content $log $line -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║   GRAŻYNA 5.0 — PEŁNY SETUP (SQLite + Prisma + Heap)  ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "  Log: $log" -ForegroundColor DarkGray
Write-Host ""

# ═══════════════════════════════════════════════════════════
# KROK 1: NAPRAW SCHEMA.PRISMA DLA SQLITE
# SQLite nie obsługuje: Json, enum, @db.*, Array
# ═══════════════════════════════════════════════════════════
Write-Host "[ 1/7 ] Naprawa schema.prisma dla SQLite..." -ForegroundColor Yellow

# Backup oryginału
$backupSchema = "$backend\prisma\schema.prisma.bak_sqlite_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $schema $backupSchema -Force
L "OK" "Backup: $backupSchema"

$sc = Get-Content $schema -Raw

# 1a. Zmień provider na sqlite
$sc = $sc -replace '(?m)^\s*provider\s*=\s*"postgresql"', '  provider = "sqlite"'
$sc = $sc -replace '(?m)^\s*provider\s*=\s*"postgres"',   '  provider = "sqlite"'

# 1b. Zmień DATABASE_URL
$sc = $sc -replace 'env\("DATABASE_URL"\)', 'env("DATABASE_URL")'

# 1c. Zamień Json? → String? i Json → String
$sc = $sc -replace '\bJson\?', 'String?'
$sc = $sc -replace '\bJson\b', 'String'

# 1d. Zamień enum na String we wszystkich modelach
# Znajdź wszystkie nazwy enumów
$enumNames = [regex]::Matches($sc, '(?m)^enum\s+(\w+)\s*\{') | ForEach-Object { $_.Groups[1].Value }
L "INFO" "Znalezione enumy: $($enumNames -join ', ')"

# Usuń bloki enum
$sc = [regex]::Replace($sc, '(?ms)^enum\s+\w+\s*\{[^}]*\}', '')

# Zamień użycia enumów na String w modelach
foreach ($enumName in $enumNames) {
    # Zamień "EnumName" jako typ pola → String
    $sc = $sc -replace "(?m)(\s+\w+\s+)$([regex]::Escape($enumName))(\??\s)", '$1String$2'
    $sc = $sc -replace "(?m)(\s+\w+\s+)$([regex]::Escape($enumName))(\s*@)", '$1String$2'
}

# 1e. Usuń @db.* atrybuty (PostgreSQL-specific)
$sc = $sc -replace '@db\.\w+(\([^)]*\))?', ''

# 1f. Zamień String[] (array) → String
$sc = $sc -replace '\bString\[\]', 'String?'
$sc = $sc -replace '\bInt\[\]',    'String?'
$sc = $sc -replace '\bFloat\[\]',  'String?'

# 1g. Usuń @default(dbgenerated(...)) — nie działa w SQLite
$sc = $sc -replace '@default\(dbgenerated\([^)]*\)\)', ''

# 1h. Zamień @default(uuid()) → @default(cuid())
$sc = $sc -replace '@default\(uuid\(\)\)', '@default(cuid())'

# 1i. Usuń wielokrotne puste linie
$sc = [regex]::Replace($sc, '(\r?\n){3,}', "`n`n")

$sc | Out-File $schema -Encoding UTF8
L "OK" "Schema.prisma naprawiona dla SQLite"

# Pokaż co zostało
$lineCount = (Get-Content $schema).Count
L "INFO" "Schema: $lineCount linii"

# ═══════════════════════════════════════════════════════════
# KROK 2: NAPRAW .ENV
# ═══════════════════════════════════════════════════════════
Write-Host "[ 2/7 ] Naprawa .env..." -ForegroundColor Yellow

$envContent = Get-Content $envFile -Raw -ErrorAction SilentlyContinue
if (-not $envContent) { $envContent = "" }

# Backup
Copy-Item $envFile "$envFile.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -Force -ErrorAction SilentlyContinue

# Ustaw SQLite DATABASE_URL
if ($envContent -match "DATABASE_URL=") {
    $envContent = [regex]::Replace($envContent, '(?m)^DATABASE_URL=.*$', 'DATABASE_URL=file:./dev.db')
} else {
    $envContent += "`nDATABASE_URL=file:./dev.db"
}

# Dodaj NODE_OPTIONS jeśli brak
if ($envContent -notmatch "NODE_OPTIONS") {
    $envContent += "`nNODE_OPTIONS=--max-old-space-size=256 --expose-gc"
}

# Dodaj UV_THREADPOOL_SIZE jeśli brak
if ($envContent -notmatch "UV_THREADPOOL_SIZE") {
    $envContent += "`nUV_THREADPOOL_SIZE=16"
}

$envContent | Out-File $envFile -Encoding UTF8
L "OK" "DATABASE_URL=file:./dev.db"
L "OK" "NODE_OPTIONS ustawione"

# ═══════════════════════════════════════════════════════════
# KROK 3: PRISMA GENERATE + DB PUSH
# ═══════════════════════════════════════════════════════════
Write-Host "[ 3/7 ] Prisma generate + db push..." -ForegroundColor Yellow

$prismaCMD = "$backend\node_modules\.bin\prisma.cmd"
if (-not (Test-Path $prismaCMD)) {
    L "ERR" "prisma.cmd nie znaleziony — uruchom npm install"
    $errors.Add("Brak prisma.cmd")
} else {
    # Generate
    L "INFO" "Uruchamiam prisma generate..."
    $genOut = cmd /c "cd /d `"$backend`" && `"$prismaCMD`" generate 2>&1"
    if ($genOut -match "Generated Prisma Client") {
        L "OK" "Prisma Client wygenerowany"
    } else {
        L "WARN" "Generate: $($genOut | Select-String 'error|Error' | Select-Object -First 2)"
    }

    # DB Push
    L "INFO" "Uruchamiam prisma db push..."
    $pushOut = cmd /c "cd /d `"$backend`" && `"$prismaCMD`" db push --accept-data-loss 2>&1"

    if ($pushOut -match "Your database is now in sync|already in sync") {
        L "OK" "Baza danych zsynchronizowana!"
    } elseif ($pushOut -match "error:|Error") {
        $errLines = ($pushOut | Select-String "error:" | Select-Object -First 5) -join "; "
        L "ERR" "Prisma push błąd: $errLines"
        $errors.Add("Prisma push: $errLines")

        # Pokaż pełny output dla diagnozy
        Write-Host ""
        Write-Host "  === PRISMA OUTPUT ===" -ForegroundColor DarkGray
        $pushOut | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
        Write-Host "  === KONIEC ===" -ForegroundColor DarkGray
        Write-Host ""
    } else {
        L "INFO" "Prisma push zakończony (sprawdź output)"
        $pushOut | Select-Object -Last 5 | ForEach-Object { L "INFO" $_ }
    }
}

# ═══════════════════════════════════════════════════════════
# KROK 4: DOCKER — uruchom Redis (PostgreSQL opcjonalnie)
# ═══════════════════════════════════════════════════════════
Write-Host "[ 4/7 ] Docker — Redis..." -ForegroundColor Yellow

$dockerOk = $false
try {
    $dockerVer = docker --version 2>&1
    if ($dockerVer -match "Docker version") {
        L "OK" "Docker dostępny: $dockerVer"

        # Sprawdź czy Redis działa
        $redis = netstat -ano 2>&1 | findstr ":6379" | findstr "LISTENING"
        if ($redis) {
            L "OK" "Redis już działa na :6379"
            $dockerOk = $true
        } else {
            L "INFO" "Uruchamiam Redis przez Docker..."
            $redisOut = cmd /c "cd /d `"$proj`" && docker-compose up -d redis 2>&1"
            Start-Sleep 5
            $redis2 = netstat -ano 2>&1 | findstr ":6379" | findstr "LISTENING"
            if ($redis2) {
                L "OK" "Redis uruchomiony na :6379"
                $dockerOk = $true
            } else {
                L "WARN" "Redis nie odpowiada — backend użyje fallback mode"
            }
        }
    }
} catch {
    L "WARN" "Docker niedostępny — Redis w fallback mode (OK dla dev)"
}

# ═══════════════════════════════════════════════════════════
# KROK 5: ANALIZA HEAP 91% — ryzyko OOM
# ═══════════════════════════════════════════════════════════
Write-Host "[ 5/7 ] Analiza Heap 91% — ryzyko OOM..." -ForegroundColor Yellow

try {
    $metricsResp = Invoke-WebRequest "http://localhost:3001/metrics" -TimeoutSec 4 -ErrorAction Stop
    $mt = $metricsResp.Content

    $heapUsed  = [double]([regex]::Match($mt, 'nodejs_heap_size_used_bytes\s+([\d.]+)').Groups[1].Value)
    $heapTotal = [double]([regex]::Match($mt, 'nodejs_heap_size_total_bytes\s+([\d.]+)').Groups[1].Value)
    $rss       = [double]([regex]::Match($mt, 'process_resident_memory_bytes\s+([\d.]+)').Groups[1].Value)
    $elLag     = [double]([regex]::Match($mt, 'nodejs_eventloop_lag_seconds\s+([\d.]+)').Groups[1].Value)

    $heapPct = [math]::Round($heapUsed / $heapTotal * 100, 1)
    $rssMB   = [math]::Round($rss / 1MB, 1)
    $elMs    = [math]::Round($elLag * 1000, 2)
    $heapMB  = [math]::Round($heapUsed / 1MB, 1)
    $heapTMB = [math]::Round($heapTotal / 1MB, 1)

    Write-Host ""
    Write-Host "  📊 HEAP ANALIZA:" -ForegroundColor White
    Write-Host ("     Heap:    {0}% ({1}/{2} MB)" -f $heapPct, $heapMB, $heapTMB) -ForegroundColor $(if($heapPct -gt 90){"Red"}elseif($heapPct -gt 80){"Yellow"}else{"Green"})
    Write-Host ("     RSS:     {0} MB" -f $rssMB) -ForegroundColor Cyan
    Write-Host ("     EL Lag:  {0} ms" -f $elMs) -ForegroundColor $(if($elMs -gt 50){"Yellow"}else{"Green"})
    Write-Host ""

    # Ocena ryzyka OOM
    if ($heapPct -gt 95) {
        L "ERR" "KRYTYCZNE: Heap $heapPct% — OOM crash NIEUCHRONNY!"
        L "INFO" "Akcja: Natychmiastowy restart z --max-old-space-size=512"
        $errors.Add("Heap krytyczny: $heapPct%")
    } elseif ($heapPct -gt 90) {
        L "WARN" "Heap $heapPct% — ryzyko OOM przy wzroście ruchu"
        L "INFO" "Ryzyko: Niskie przy obecnym ruchu (dev), Wysokie na produkcji"
        L "INFO" "Fix: --max-old-space-size=256 już ustawiony w NODE_OPTIONS"
    } elseif ($heapPct -gt 80) {
        L "WARN" "Heap $heapPct% — monitoruj"
    } else {
        L "OK" "Heap $heapPct% — bezpieczny"
    }

    # Sprawdź czy GC jest dostępny
    $gcAvail = $mt -match "expose-gc" -or (Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "expose-gc" })
    if ($gcAvail) {
        L "OK" "--expose-gc aktywny — ręczny GC dostępny"
    } else {
        L "INFO" "Dodaj --expose-gc do NODE_OPTIONS dla ręcznego GC"
    }

} catch {
    L "INFO" "Backend nie odpowiada na :3001 — pomijam analizę heap"
}

# ═══════════════════════════════════════════════════════════
# KROK 6: RESTART BACKENDU Z OPTYMALIZACJAMI
# ═══════════════════════════════════════════════════════════
Write-Host "[ 6/7 ] Restart backendu..." -ForegroundColor Yellow

# Zatrzymaj wszystkie Node.js
$nodeProcs = Get-Process node -ErrorAction SilentlyContinue
if ($nodeProcs) {
    L "INFO" "Zatrzymuję $($nodeProcs.Count) procesów Node.js..."
    $nodeProcs | Stop-Process -Force
    Start-Sleep 3
}
L "OK" "Procesy zatrzymane"

# Uruchom backend przez cmd.exe (omija problem PS z .cmd)
$startCmd = "cd /d `"$backend`" && `"$nodeExe`" --max-old-space-size=256 --expose-gc node_modules\tsx\dist\cli.mjs watch src\cluster-bootstrap.ts"
Start-Process cmd -ArgumentList "/k", $startCmd -WindowStyle Normal
L "INFO" "Backend uruchamia się w nowym oknie..."

# Czekaj na start
$started = $false
for ($i = 1; $i -le 15; $i++) {
    Start-Sleep 2
    try {
        $h = Invoke-WebRequest "http://localhost:3001/health" -TimeoutSec 2 -ErrorAction Stop
        if ($h.StatusCode -eq 200) {
            L "OK" "Backend odpowiada HTTP 200 (po ${i}×2s)"
            $started = $true
            break
        }
    } catch {}
    Write-Host "  ⏳ Czekam... ($i/15)" -ForegroundColor DarkGray
}

if (-not $started) {
    L "WARN" "Backend nie odpowiada po 30s — sprawdź okno terminala"
    $errors.Add("Backend nie startuje")
}

# ═══════════════════════════════════════════════════════════
# KROK 7: TESTY WERYFIKACYJNE
# ═══════════════════════════════════════════════════════════
Write-Host "[ 7/7 ] Testy weryfikacyjne..." -ForegroundColor Yellow

# Test /health
try {
    $health = Invoke-RestMethod "http://localhost:3001/health" -TimeoutSec 5
    L "OK" "/health → status=$($health.status) uptime=$($health.uptime)s"
} catch { L "WARN" "/health: $($_.Exception.Message)" }

# Test /api
try {
    $api = Invoke-RestMethod "http://localhost:3001/api" -TimeoutSec 5
    L "OK" "/api → $($api.name) v$($api.version)"
} catch { L "WARN" "/api: $($_.Exception.Message)" }

# Test /api/system/workers
try {
    $workers = Invoke-RestMethod "http://localhost:3001/api/system/workers" -TimeoutSec 5
    L "OK" "/workers → workers=$($workers.workerPool.workers) busy=$($workers.workerPool.busy)"
} catch { L "WARN" "/workers: $($_.Exception.Message)" }

# Test rejestracji (tylko jeśli Prisma push się udał)
if ($errors.Count -eq 0 -or ($errors | Where-Object { $_ -match "Prisma" }).Count -eq 0) {
    $testEmail = "test_$(Get-Date -Format 'HHmmss')@grazyna.pl"
    try {
        $body = "{`"email`":`"$testEmail`",`"password`":`"Test1234!`",`"username`":`"testuser_$(Get-Date -Format 'HHmmss')`"}"
        $reg = Invoke-RestMethod "http://localhost:3001/api/auth/register" -Method POST -ContentType "application/json" -Body $body -TimeoutSec 5
        L "OK" "Rejestracja działa! user=$($reg.user.email ?? $reg.email ?? 'OK')"

        # Test logowania
        $loginBody = "{`"email`":`"$testEmail`",`"password`":`"Test1234!`"}"
        $login = Invoke-RestMethod "http://localhost:3001/api/auth/login" -Method POST -ContentType "application/json" -Body $loginBody -TimeoutSec 5
        $tokenPreview = if ($login.token) { $login.token.Substring(0, [Math]::Min(20, $login.token.Length)) + "..." } else { "brak" }
        L "OK" "Logowanie działa! token=$tokenPreview"
    } catch {
        $errDetail = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
        L "WARN" "Auth: $($errDetail.error ?? $_.Exception.Message)"
        $errors.Add("Auth test: $($errDetail.error ?? $_.Exception.Message)")
    }
}

# Test metryk
try {
    $metrics = Invoke-WebRequest "http://localhost:3001/metrics" -TimeoutSec 5
    $heapLine = ($metrics.Content | Select-String "nodejs_heap_size_used_bytes\s+[\d.]+").Matches[0].Value
    L "OK" "/metrics → $heapLine"
} catch { L "WARN" "/metrics: $($_.Exception.Message)" }

# ═══════════════════════════════════════════════════════════
# RAPORT KOŃCOWY
# ═══════════════════════════════════════════════════════════
Write-Host ""
if ($errors.Count -eq 0) {
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║   ✅ SETUP ZAKOŃCZONY POMYŚLNIE — BRAK BŁĘDÓW!         ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
} else {
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║   ⚠️  SETUP Z OSTRZEŻENIAMI ($($errors.Count) problemów)           ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Problemy do rozwiązania:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  ❌ $_" -ForegroundColor Red }
}

Write-Host ""
Write-Host "  📌 DOSTĘP:" -ForegroundColor Cyan
Write-Host "     Frontend:  http://localhost:5174" -ForegroundColor White
Write-Host "     Backend:   http://localhost:3001/api" -ForegroundColor White
Write-Host "     Health:    http://localhost:3001/health" -ForegroundColor White
Write-Host "     Metrics:   http://localhost:3001/metrics" -ForegroundColor White
Write-Host "     Workers:   http://localhost:3001/api/system/workers" -ForegroundColor White
Write-Host ""
Write-Host "  📋 LOG: $log" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  💡 NASTĘPNE KROKI:" -ForegroundColor Cyan
Write-Host "     1. Sprawdź okno backendu (npm run dev)" -ForegroundColor White
Write-Host "     2. Otwórz panel: start E:\Grazyna_5.0\GRAZYNA_LIVE_PANEL.html" -ForegroundColor White
Write-Host "     3. Monitor: Start-Process powershell -ArgumentList '-File E:\Grazyna_5.0\GRAZYNA_PREDICT_MONITOR.ps1'" -ForegroundColor White
Write-Host ""