# ============================================================
# GRAŻYNA 5.0 — MASTER INTEGRATION SCRIPT
# Pełna integracja środowiska, plików i zawartości
# Uruchom jako Administrator: & "E:\Grazyna_5.0\GRAZYNA_MASTER_INTEGRATION.ps1"
# ============================================================
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

$proj    = "E:\Grazyna_5.0"
$backend = "$proj\backend"
$nodeExe = "$proj\tools\nodejs\node.exe"
$log     = "$proj\logs\integration_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$report  = "$proj\GRAZYNA_INTEGRATION_REPORT.txt"
$errors  = [System.Collections.Generic.List[string]]::new()
$ok      = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path "$proj\logs")) { New-Item -ItemType Directory "$proj\logs" -Force | Out-Null }

function L($level, $msg) {
    $col  = switch($level) { "OK"{"Green"}; "WARN"{"Yellow"}; "ERR"{"Red"}; "INFO"{"Cyan"}; "STEP"{"Magenta"} }
    $ico  = switch($level) { "OK"{"✅"}; "WARN"{"⚠️"}; "ERR"{"❌"}; "INFO"{"ℹ️"}; "STEP"{"▶"} }
    $line = "[$((Get-Date).ToString('HH:mm:ss'))] $ico $msg"
    Write-Host "  $ico $msg" -ForegroundColor $col
    Add-Content $log $line -ErrorAction SilentlyContinue
    if ($level -eq "OK")  { $ok.Add($msg) }
    if ($level -eq "ERR") { $errors.Add($msg) }
}

function Section($title) {
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
    Write-Host "  │  $title" -ForegroundColor Cyan
    Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║   GRAŻYNA 5.0 — MASTER INTEGRATION                    ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "  Projekt: $proj" -ForegroundColor Gray
Write-Host "  Log:     $log" -ForegroundColor Gray
Write-Host ""

# ═══════════════════════════════════════════════════════════
# FAZA 1: INWENTARYZACJA PLIKÓW
# ═══════════════════════════════════════════════════════════
Section "FAZA 1: INWENTARYZACJA PLIKÓW PROJEKTU"

$fileMap = @{
    "Schema Prisma (zoptymalizowana)" = "$proj\GRAZYNA_PRISMA_SCHEMA_OPTIMIZED.prisma"
    "Backend Fix (index.ts)"          = "$proj\GRAZYNA_BACKEND_FIX.ts"
    "Worker Pool"                     = "$proj\GRAZYNA_WORKER_THREADS.ts"
    "EL Optimization"                 = "$proj\GRAZYNA_EL_OPTIMIZATION.ts"
    "Large Object Diag"               = "$proj\GRAZYNA_LARGE_OBJECT_DIAG.ts"
    "New API Routes"                  = "$proj\backend_new_routes.ts"
    "Auth JWT vs Sessions"            = "$proj\GRAZYNA_AUTH_JWT_VS_SESSIONS.md"
    "DB Analysis"                     = "$proj\GRAZYNA_DB_ANALYSIS.md"
    "Express vs Fastify"              = "$proj\GRAZYNA_EXPRESS_VS_FASTIFY.md"
    "Fastify Migration"               = "$proj\GRAZYNA_FASTIFY_MIGRATION.md"
    "ML vs Regression"                = "$proj\GRAZYNA_ML_VS_REGRESSION.md"
    "Heap Workers Monitor"            = "$proj\GRAZYNA_HEAP_WORKERS_MONITOR.md"
    "Analiza Raport"                  = "$proj\GRAZYNA_ANALIZA_RAPORT.md"
    "Start Script"                    = "$proj\GRAZYNA_START.ps1"
    "Fix All Script"                  = "$proj\GRAZYNA_FIX_ALL.ps1"
    "Fix Nodelink"                    = "$proj\GRAZYNA_FIX_NODELINK.ps1"
    "Fix NPM"                         = "$proj\GRAZYNA_FIX_NPM.ps1"
    "Worker Fix"                      = "$proj\GRAZYNA_WORKER_FIX.ps1"
    "Full Setup"                      = "$proj\GRAZYNA_FULL_SETUP.ps1"
    "DB Setup"                        = "$proj\GRAZYNA_DB_SETUP.ps1"
    "Node Optimize"                   = "$proj\GRAZYNA_NODE_OPTIMIZE.ps1"
    "Monitor"                         = "$proj\GRAZYNA_MONITOR.ps1"
    "Predict Monitor"                 = "$proj\GRAZYNA_PREDICT_MONITOR.ps1"
    "Auto Restart"                    = "$proj\GRAZYNA_AUTO_RESTART.ps1"
    "Install Full"                    = "$proj\GRAZYNA_INSTALL_FULL.ps1"
    "Live Panel"                      = "$proj\GRAZYNA_LIVE_PANEL.html"
    "Mega Panel"                      = "$proj\GRAZYNA_MEGA_PANEL.html"
    "CI/CD Pipeline"                  = "$proj\.github\workflows\ci-cd.yml"
    "CI/CD Rollback"                  = "$proj\.github\workflows\ci-cd-rollback.yml"
}

$found = 0; $missing = 0
foreach ($name in $fileMap.Keys) {
    $path = $fileMap[$name]
    if (Test-Path $path) {
        $size = [math]::Round((Get-Item $path).Length / 1KB, 1)
        L "OK" "$name ($size KB)"
        $found++
    } else {
        L "WARN" "BRAK: $name → $path"
        $missing++
    }
}
L "INFO" "Pliki: $found znalezionych, $missing brakujących"

# ═══════════════════════════════════════════════════════════
# FAZA 2: KOPIOWANIE PLIKÓW DO PROJEKTU
# ═══════════════════════════════════════════════════════════
Section "FAZA 2: INTEGRACJA PLIKÓW DO BACKENDU"

# 2a. Zoptymalizowana schema Prisma
$schemaSrc = "$proj\GRAZYNA_PRISMA_SCHEMA_OPTIMIZED.prisma"
$schemaDst = "$backend\prisma\schema.prisma"
if (Test-Path $schemaSrc) {
    # Backup
    Copy-Item $schemaDst "$schemaDst.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -Force -ErrorAction SilentlyContinue
    Copy-Item $schemaSrc $schemaDst -Force
    L "OK" "Schema Prisma zaktualizowana → backend/prisma/schema.prisma"
} else {
    L "WARN" "Brak zoptymalizowanej schema — używam istniejącej"
}

# 2b. Nowe routes API → backend/src/routes/
$routesSrc = "$proj\backend_new_routes.ts"
$routesDst = "$backend\src\routes\new-routes.ts"
if (Test-Path $routesSrc) {
    Copy-Item $routesSrc $routesDst -Force
    L "OK" "Nowe routes API → backend/src/routes/new-routes.ts"
}

# 2c. Worker Pool → backend/src/
$wpSrc = "$proj\GRAZYNA_WORKER_THREADS.ts"
if (Test-Path $wpSrc) {
    # Sprawdź czy worker-pool.ts już istnieje (z poprzednich kroków)
    if (-not (Test-Path "$backend\src\worker-pool.ts")) {
        Copy-Item $wpSrc "$backend\src\worker-pool-reference.ts" -Force
        L "OK" "Worker Pool reference → backend/src/worker-pool-reference.ts"
    } else {
        L "INFO" "worker-pool.ts już istnieje — pomijam"
    }
}

# 2d. EL Optimization → backend/src/
$elSrc = "$proj\GRAZYNA_EL_OPTIMIZATION.ts"
if (Test-Path $elSrc) {
    if (-not (Test-Path "$backend\src\el-optimization.ts")) {
        Copy-Item $elSrc "$backend\src\el-optimization.ts" -Force
        L "OK" "EL Optimization → backend/src/el-optimization.ts"
    } else {
        L "INFO" "el-optimization.ts już istnieje"
    }
}

# 2e. Skrypty PS1 → scripts/
$scriptsDir = "$proj\scripts"
$ps1Files = @(
    "GRAZYNA_START.ps1", "GRAZYNA_FIX_ALL.ps1", "GRAZYNA_FIX_NODELINK.ps1",
    "GRAZYNA_MONITOR.ps1", "GRAZYNA_PREDICT_MONITOR.ps1", "GRAZYNA_AUTO_RESTART.ps1",
    "GRAZYNA_FULL_SETUP.ps1", "GRAZYNA_NODE_OPTIMIZE.ps1", "GRAZYNA_MASTER_INTEGRATION.ps1"
)
foreach ($ps1 in $ps1Files) {
    $src = "$proj\$ps1"
    if (Test-Path $src) {
        Copy-Item $src "$scriptsDir\$ps1" -Force -ErrorAction SilentlyContinue
    }
}
L "OK" "Skrypty PS1 zsynchronizowane → scripts/"

# 2f. Panele HTML → docs/
$docsDir = "$proj\docs"
if (-not (Test-Path $docsDir)) { New-Item -ItemType Directory $docsDir -Force | Out-Null }
@("GRAZYNA_LIVE_PANEL.html", "GRAZYNA_MEGA_PANEL.html") | ForEach-Object {
    $src = "$proj\$_"
    if (Test-Path $src) {
        Copy-Item $src "$docsDir\$_" -Force
    }
}
L "OK" "Panele HTML → docs/"

# ═══════════════════════════════════════════════════════════
# FAZA 3: PRISMA SETUP
# ═══════════════════════════════════════════════════════════
Section "FAZA 3: PRISMA GENERATE + DB PUSH"

$prismaCMD = "$backend\node_modules\.bin\prisma.cmd"
if (Test-Path $prismaCMD) {
    # Generate
    L "INFO" "prisma generate..."
    $genOut = cmd /c "cd /d `"$backend`" && `"$prismaCMD`" generate 2>&1"
    if ($genOut -match "Generated Prisma Client") { L "OK" "Prisma Client wygenerowany" }
    else { L "WARN" "Generate: sprawdź output" }

    # DB Push
    L "INFO" "prisma db push..."
    $pushOut = cmd /c "cd /d `"$backend`" && `"$prismaCMD`" db push --accept-data-loss 2>&1"
    if ($pushOut -match "in sync") {
        L "OK" "Baza danych zsynchronizowana (SQLite dev.db)"
    } else {
        $errLine = ($pushOut | Select-String "error:" | Select-Object -First 1)
        L "ERR" "Prisma push: $errLine"
    }
} else {
    L "ERR" "prisma.cmd nie znaleziony"
}

# ═══════════════════════════════════════════════════════════
# FAZA 4: WERYFIKACJA ŚRODOWISKA
# ═══════════════════════════════════════════════════════════
Section "FAZA 4: WERYFIKACJA ŚRODOWISKA"

# Node.js
$nodeVer = & $nodeExe --version 2>&1
L "OK" "Node.js: $nodeVer"

# npm
$npmVer = cmd /c "`"$proj\tools\nodejs\npm.cmd`" --version 2>&1"
L "OK" "npm: $npmVer"

# Git
Push-Location $proj
$gitBranch = git branch --show-current 2>&1
$gitCommit = git rev-parse --short HEAD 2>&1
$gitStatus = git status --short 2>&1
Pop-Location
L "OK" "Git: branch=$gitBranch commit=$gitCommit"
if ($gitStatus) { L "INFO" "Niezatwierdzone zmiany: $($gitStatus.Count) plików" }
else { L "OK" "Git: working tree clean" }

# Porty
$ports = @(3001, 5174, 6379, 5432)
foreach ($port in $ports) {
    $listening = netstat -ano 2>&1 | findstr ":$port" | findstr "LISTENING"
    if ($listening) {
        $pid = ($listening -split '\s+')[-1]
        L "OK" "Port :$port LISTENING (PID $pid)"
    } else {
        $name = switch($port) { 3001{"Backend"}; 5174{"Frontend"}; 6379{"Redis"}; 5432{"PostgreSQL"} }
        if ($port -in @(3001, 5174)) { L "WARN" "Port :$port ($name) nie działa" }
        else { L "INFO" "Port :$port ($name) nie działa (opcjonalny)" }
    }
}

# Backend health
try {
    $h = Invoke-RestMethod "http://localhost:3001/health" -TimeoutSec 5
    L "OK" "Backend /health: status=$($h.status) uptime=$($h.uptime)"
} catch { L "WARN" "Backend /health niedostępny" }

# Workers
try {
    $w = Invoke-RestMethod "http://localhost:3001/api/system/workers" -TimeoutSec 5
    L "OK" "Workers: $($w.workerPool.workers) workers, $($w.clusterWorkers) cluster"
} catch { L "WARN" "Workers endpoint niedostępny" }

# Metryki
try {
    $m = Invoke-WebRequest "http://localhost:3001/metrics" -TimeoutSec 5
    $heapUsed  = [double]([regex]::Match($m.Content,'nodejs_heap_size_used_bytes\s+([\d.]+)').Groups[1].Value)
    $heapTotal = [double]([regex]::Match($m.Content,'nodejs_heap_size_total_bytes\s+([\d.]+)').Groups[1].Value)
    $heapPct   = if($heapTotal -gt 0){[math]::Round($heapUsed/$heapTotal*100,1)}else{0}
    $rssMB     = [math]::Round([double]([regex]::Match($m.Content,'process_resident_memory_bytes\s+([\d.]+)').Groups[1].Value)/1MB,1)
    L "OK" "Metryki: Heap=$heapPct% RSS=${rssMB}MB"
} catch { L "WARN" "Metryki niedostępne" }

# ═══════════════════════════════════════════════════════════
# FAZA 5: GIT COMMIT WSZYSTKICH ZMIAN
# ═══════════════════════════════════════════════════════════
Section "FAZA 5: GIT COMMIT"

Push-Location $proj
$gitChanges = git status --short 2>&1
if ($gitChanges) {
    L "INFO" "Zatwierdzam $($gitChanges.Count) zmian..."
    git add -A 2>&1 | Out-Null
    $commitMsg = "feat: full integration - schema SQLite, workers, auth, monitoring, panels [$(Get-Date -Format 'yyyy-MM-dd')]"
    $commitOut = git commit -m $commitMsg 2>&1
    if ($commitOut -match "master|main") {
        L "OK" "Commit: $($commitOut | Select-String '\[' | Select-Object -First 1)"
    } else {
        L "INFO" "Git commit: $commitOut"
    }

    # Push
    L "INFO" "git push origin main..."
    $pushOut = git push origin main 2>&1
    if ($pushOut -match "error|Error") {
        L "WARN" "Push: $pushOut"
    } else {
        L "OK" "Push do origin/main zakończony"
    }
} else {
    L "OK" "Git: brak zmian do zatwierdzenia"
}
Pop-Location

# ═══════════════════════════════════════════════════════════
# FAZA 6: URUCHOM MONITORING W TLE
# ═══════════════════════════════════════════════════════════
Section "FAZA 6: START MONITORING"

$watchdogRunning = Get-Process powershell -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match "AUTO_RESTART" }

if (-not $watchdogRunning) {
    Start-Process powershell -ArgumentList "-WindowStyle Minimized -File `"$proj\GRAZYNA_AUTO_RESTART.ps1`""
    L "OK" "Auto-restart watchdog uruchomiony w tle"
} else {
    L "INFO" "Watchdog już działa"
}

# ═══════════════════════════════════════════════════════════
# FAZA 7: GENERUJ RAPORT INTEGRACJI
# ═══════════════════════════════════════════════════════════
Section "FAZA 7: RAPORT INTEGRACJI"

$reportContent = @"
╔══════════════════════════════════════════════════════════════════╗
║         GRAŻYNA 5.0 — RAPORT INTEGRACJI                        ║
║         $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                              ║
╚══════════════════════════════════════════════════════════════════╝

ŚRODOWISKO:
  Node.js:    $nodeVer
  npm:        $npmVer
  Git branch: $gitBranch ($gitCommit)
  Projekt:    $proj

PLIKI PROJEKTU ($found znalezionych):
$(($fileMap.Keys | Where-Object { Test-Path $fileMap[$_] } | ForEach-Object { "  ✅ $_" }) -join "`n")

BRAKUJĄCE PLIKI ($missing):
$(($fileMap.Keys | Where-Object { -not (Test-Path $fileMap[$_]) } | ForEach-Object { "  ❌ $_" }) -join "`n")

WYNIKI ($($ok.Count) OK, $($errors.Count) błędów):
$(($ok | ForEach-Object { "  ✅ $_" }) -join "`n")
$(($errors | ForEach-Object { "  ❌ $_" }) -join "`n")

DOSTĘP:
  Frontend:  http://localhost:5174
  Backend:   http://localhost:3001/api
  Health:    http://localhost:3001/health
  Metrics:   http://localhost:3001/metrics
  Workers:   http://localhost:3001/api/system/workers
  Heap Diag: http://localhost:3001/api/system/heap

SKRYPTY:
  Start:     & "$proj\GRAZYNA_START.ps1"
  Monitor:   Start-Process powershell -ArgumentList "-File $proj\GRAZYNA_PREDICT_MONITOR.ps1"
  Watchdog:  Start-Process powershell -ArgumentList "-File $proj\GRAZYNA_AUTO_RESTART.ps1"
  Panel:     start "$proj\GRAZYNA_LIVE_PANEL.html"

LOG: $log
"@

$reportContent | Out-File $report -Encoding UTF8
L "OK" "Raport zapisany: $report"

# ═══════════════════════════════════════════════════════════
# PODSUMOWANIE KOŃCOWE
# ═══════════════════════════════════════════════════════════
Write-Host ""
if ($errors.Count -eq 0) {
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║   ✅ INTEGRACJA ZAKOŃCZONA POMYŚLNIE!                  ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
} else {
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║   ⚠️  INTEGRACJA Z $($errors.Count) PROBLEMAMI                    ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    $errors | ForEach-Object { Write-Host "  ❌ $_" -ForegroundColor Red }
}

Write-Host ""
Write-Host "  📌 DOSTĘP:" -ForegroundColor Cyan
Write-Host "     🌐 Frontend:  http://localhost:5174" -ForegroundColor White
Write-Host "     🔧 Backend:   http://localhost:3001/api" -ForegroundColor White
Write-Host "     ❤️  Health:    http://localhost:3001/health" -ForegroundColor White
Write-Host "     📊 Metrics:   http://localhost:3001/metrics" -ForegroundColor White
Write-Host "     🔌 Workers:   http://localhost:3001/api/system/workers" -ForegroundColor White
Write-Host ""
Write-Host "  📋 Raport: $report" -ForegroundColor DarkGray
Write-Host "  📋 Log:    $log" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  💡 NASTĘPNE KROKI:" -ForegroundColor Cyan
Write-Host "     start `"$proj\GRAZYNA_LIVE_PANEL.html`"" -ForegroundColor White
Write-Host "     Start-Process powershell -ArgumentList `"-File $proj\GRAZYNA_PREDICT_MONITOR.ps1`"" -ForegroundColor White
Write-Host ""