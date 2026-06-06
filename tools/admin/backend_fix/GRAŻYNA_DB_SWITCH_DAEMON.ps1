# ============================================================
# GRAŻYNA 5.0 — DB SWITCH DAEMON
# Automatyczne przełączanie SQLite ↔ PostgreSQL
# ============================================================

$proj      = "E:\Grazyna_5.0"
$backend   = "$proj\backend"
$logFile   = "$proj\logs\db_daemon.log"
$interval  = 10

function Log($lvl,$msg){
    $c = switch($lvl){ "OK"{"Green"};"WARN"{"Yellow"};"ERR"{"Red"};"INFO"{"Cyan"} }
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$ts][$lvl] $msg"
    Write-Host $line -ForegroundColor $c
    Add-Content $logFile $line
}

function PG-Alive {
    return (netstat -ano | findstr ":5432" | findstr "LISTENING")
}

function Backend-Alive {
    try {
        $r = Invoke-WebRequest "http://localhost:3001/health" -TimeoutSec 3
        return $r.StatusCode -eq 200
    } catch { return $false }
}

function Switch-DB($target){
    Log "INFO" "Przełączam DB → $target"
    & "$proj\tools\admin\backend_fix\GRAZYNA_DB_SWITCH.ps1"
}

Log "INFO" "=== DB DAEMON START ==="

$current = "unknown"

while ($true) {
    $pg = PG-Alive
    $be = Backend-Alive

    if ($pg -and $current -ne "postgresql") {
        Log "OK" "PostgreSQL dostępny → przełączam na PostgreSQL"
        Switch-DB "postgresql"
        $current = "postgresql"
    }

    if (-not $pg -and $current -ne "sqlite") {
        Log "WARN" "PostgreSQL niedostępny → przełączam na SQLite"
        Switch-DB "sqlite"
        $current = "sqlite"
    }

    if (-not $be) {
        Log "ERR" "Backend nie odpowiada → restartuję"
        & "$proj\tools\admin\backend_fix\GRAZYNA_AUTO_RESTART.ps1"
    }

    Start-Sleep $interval
}