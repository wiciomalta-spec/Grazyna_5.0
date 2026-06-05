# ============================================================
# GRAŻYNA 5.0 — DB SWITCH DASHBOARD (TUI PANEL)
# Interaktywny panel do zarządzania SQLite ↔ PostgreSQL
# ============================================================

$proj      = "E:\Grazyna_5.0"
$backend   = "$proj\backend"
$fixDir    = "$proj\tools\admin\backend_fix"
$logFile   = "$proj\logs\db_dashboard.log"

function Log($msg){
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content $logFile "[$ts] $msg"
}

function PG-Alive {
    return (netstat -ano | findstr ":5432" | findstr "LISTENING")
}

function Backend-Alive {
    try {
        $r = Invoke-WebRequest "http://localhost:3001/health" -TimeoutSec 2
        return $r.StatusCode -eq 200
    } catch { return $false }
}

function Current-Provider {
    $env = Get-Content "$backend\.env"
    return ($env | Select-String "DB_PROVIDER").ToString().Split("=")[1]
}

function Draw-Header {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║      GRAŻYNA 5.0 — DB SWITCH DASHBOARD (TUI)         ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Draw-Status {
    $pg = PG-Alive
    $be = Backend-Alive
    $prov = Current-Provider

    Write-Host ""
    Write-Host "  STATUS SYSTEMU:" -ForegroundColor Yellow

    Write-Host ("   • Provider DB:   {0}" -f $prov) -ForegroundColor Cyan
    Write-Host ("   • PostgreSQL:    {0}" -f ($(if($pg){"ONLINE"}else{"OFFLINE"}))) -ForegroundColor $(if($pg){"Green"}else{"Red"})
    Write-Host ("   • Backend:       {0}" -f ($(if($be){"ONLINE"}else{"OFFLINE"}))) -ForegroundColor $(if($be){"Green"}else{"Red"})
}

function Draw-Menu {
    Write-Host ""
    Write-Host "  AKCJE:" -ForegroundColor Yellow
    Write-Host "   [1] Przełącz na SQLite"
    Write-Host "   [2] Przełącz na PostgreSQL"
    Write-Host "   [3] Wykonaj migracje"
    Write-Host "   [4] Restart backendu"
    Write-Host "   [5] Restart DB Daemon"
    Write-Host "   [6] Generuj enumy TypeScript"
    Write-Host "   [7] Waliduj JSON"
    Write-Host "   [8] Podgląd logów"
    Write-Host "   [R] Odśwież"
    Write-Host "   [Q] Wyjście"
}

function Show-Logs {
    Clear-Host
    Write-Host "=== LOGI DB SWITCH ===" -ForegroundColor Yellow
    Get-Content $logFile -Tail 50
    Write-Host ""
    Write-Host "[ENTER] Powrót"
    Read-Host
}

function Switch-SQLite {
    Log "Switch → SQLite"
    & "$fixDir\GRAŻYNA_DB_SWITCH.ps1"
}

function Switch-Postgres {
    Log "Switch → PostgreSQL"
    & "$fixDir\GRAŻYNA_DB_SWITCH.ps1"
}

function Run-Migrations {
    Log "Migracje"
    & "$fixDir\GRAŻYNA_DB_SWITCH.ps1"
}

function Restart-Backend {
    Log "Restart backendu"
    & "$fixDir\GRAŻYNA_AUTO_RESTART.ps1"
}

function Restart-Daemon {
    Log "Restart DB Daemon"
    Start-Process powershell -ArgumentList "-File `"$fixDir\GRAŻYNA_DB_SWITCH_DAEMON.ps1`""
}

function Generate-Enums {
    Log "Generacja enumów"
    & "$backend\tools\prisma-enums-gen.ts"
}

function Validate-JSON {
    Log "Walidacja JSON"
    & "$backend\tools\prisma-json-validator.ts"
}

# ============================================================
# GŁÓWNA PĘTLA DASHBOARDU
# ============================================================

while ($true) {
    Draw-Header
    Draw-Status
    Draw-Menu

    $choice = Read-Host "`n  Wybierz opcję"

    switch ($choice.ToUpper()) {
        "1" { Switch-SQLite }
        "2" { Switch-Postgres }
        "3" { Run-Migrations }
        "4" { Restart-Backend }
        "5" { Restart-Daemon }
        "6" { Generate-Enums }
        "7" { Validate-JSON }
        "8" { Show-Logs }
        "R" { continue }
        "Q" { break }
        default { Write-Host "Nieznana opcja" -ForegroundColor Red }
    }

    Start-Sleep 1
}
