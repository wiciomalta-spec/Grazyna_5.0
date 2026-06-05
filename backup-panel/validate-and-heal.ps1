$ErrorActionPreference = 'Stop'

$Root = 'E:\Grazyna_5.0\backup-panel'
$DataRoot = Join-Path $Root 'data'
$ReportsRoot = 'E:\BACKUPS\reports'
$MapPath = Join-Path $Root 'panel-map.json'
$ReportTxt = Join-Path $ReportsRoot 'panel-structure-report.txt'
$ReportJson = Join-Path $ReportsRoot 'panel-structure-report.json'

function Write-Utf8File {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Get-Template {
    param([string]$Path)

    switch ($Path) {
        'E:\Grazyna_5.0\backup-panel\sync-backup-data.ps1' {
@'
$ErrorActionPreference = 'Stop'

$PanelRoot = "E:\Grazyna_5.0\backup-panel"
$DataRoot = Join-Path $PanelRoot "data"
$SourceReports = "E:\BACKUPS\reports"

New-Item -ItemType Directory -Force -Path $DataRoot | Out-Null

Copy-Item -LiteralPath (Join-Path $SourceReports "backup_live.json") `
    -Destination (Join-Path $DataRoot "backup_live.json") `
    -Force -ErrorAction SilentlyContinue

Copy-Item -LiteralPath (Join-Path $SourceReports "backup_size_report.csv") `
    -Destination (Join-Path $DataRoot "backup_size_report.csv") `
    -Force -ErrorAction SilentlyContinue

Copy-Item -LiteralPath (Join-Path $SourceReports "backup_integrity_report.txt") `
    -Destination (Join-Path $DataRoot "backup_integrity_report.txt") `
    -Force -ErrorAction SilentlyContinue

Copy-Item -LiteralPath (Join-Path $SourceReports "backup_log.txt") `
    -Destination (Join-Path $DataRoot "backup_log.txt") `
    -Force -ErrorAction SilentlyContinue

Write-Host "OK: Panel data synchronized."
'@
        }

        'E:\Grazyna_5.0\backup-panel\start-backup-dashboard.ps1' {
@'
$PanelRoot = "E:\Grazyna_5.0\backup-panel"
$PortFile  = Join-Path $PanelRoot "dashboard-port.txt"

function Test-PortFree([int]$Port) {
    try {
        $listener = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Loopback, $Port)
        $listener.Start()
        $listener.Stop()
        return $true
    }
    catch {
        return $false
    }
}

function Get-FreePort {
    $preferred = @(8765,8766,8767,8780,8085,8086,8090)
    foreach ($p in $preferred) {
        if (Test-PortFree $p) { return $p }
    }
    for ($p = 9000; $p -le 9100; $p++) {
        if (Test-PortFree $p) { return $p }
    }
    throw "Brak wolnego portu"
}

$python = Get-Command python -ErrorAction SilentlyContinue
$usePyLauncher = $false
if (-not $python) {
    $python = Get-Command py -ErrorAction SilentlyContinue
    if ($python) { $usePyLauncher = $true }
}
if (-not $python) {
    Write-Host "BLAD: brak python/py w PATH"
    exit 1
}

$port = Get-FreePort
Set-Content -Path $PortFile -Value $port -Encoding UTF8

Set-Location $PanelRoot
Start-Process "http://127.0.0.1:$port/dashboard.html"

if ($usePyLauncher) {
    & $python.Source -3 -m http.server $port
} else {
    & $python.Source -m http.server $port
}
'@
        }

        'E:\Grazyna_5.0\backup-panel\run-backup-and-panel.ps1' {
@'
$Backup = "E:\BACKUPS\backup_grazyna.ps1"
$Sync   = "E:\Grazyna_5.0\backup-panel\sync-backup-data.ps1"
$Start  = "E:\Grazyna_5.0\backup-panel\start-backup-dashboard.ps1"

Write-Host "1/3 Backup..."
pwsh -ExecutionPolicy Bypass -File $Backup

Write-Host "2/3 Sync danych..."
pwsh -ExecutionPolicy Bypass -File $Sync

Write-Host "3/3 Start panelu..."
pwsh -ExecutionPolicy Bypass -File $Start
'@
        }

        'E:\Grazyna_5.0\backup-panel\run-backup-and-panel.bat' {
@'
@echo off
pwsh -ExecutionPolicy Bypass -File "E:\Grazyna_5.0\backup-panel\run-backup-and-panel.ps1"
pause
'@
        }

        default {
            return $null
        }
    }
}

if (-not (Test-Path -LiteralPath $MapPath)) {
    throw "Brak pliku mapy: $MapPath"
}

if (-not (Test-Path -LiteralPath $Root)) {
    New-Item -ItemType Directory -Force -Path $Root | Out-Null
}
if (-not (Test-Path -LiteralPath $DataRoot)) {
    New-Item -ItemType Directory -Force -Path $DataRoot | Out-Null
}
if (-not (Test-Path -LiteralPath $ReportsRoot)) {
    New-Item -ItemType Directory -Force -Path $ReportsRoot | Out-Null
}

$map = Get-Content -LiteralPath $MapPath -Raw | ConvertFrom-Json
$results = @()

foreach ($rule in $map.rules) {
    $path = $rule.path
    $exists = Test-Path -LiteralPath $path
    $status = 'OK'
    $notes = @()

    if (-not $exists) {
        if ($rule.type -eq 'directory') {
            New-Item -ItemType Directory -Force -Path $path | Out-Null
            $exists = $true
            $notes += 'created missing directory'
            $status = 'FIXED'
        }
        else {
            $template = Get-Template -Path $path
            if ($template) {
                Write-Utf8File -Path $path -Content $template
                $exists = $true
                $notes += 'created file from template'
                $status = 'FIXED'
            }
            elseif ($rule.required) {
                $status = 'ERROR'
                $notes += 'required file missing and no template available'
            }
            else {
                $status = 'WARN'
                $notes += 'optional file missing'
            }
        }
    }

    if ($exists -and $rule.type -eq 'file') {
        $raw = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue

        if ($rule.nonEmpty -and [string]::IsNullOrWhiteSpace($raw)) {
            $template = Get-Template -Path $path
            if ($template) {
                Write-Utf8File -Path $path -Content $template
                $raw = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue
                $notes += 'replaced empty file from template'
                $status = 'FIXED'
            }
            else {
                $status = 'ERROR'
                $notes += 'file is empty'
            }
        }

        if ($raw) {
            foreach ($token in @($rule.mustContain)) {
                if ($token -and ($raw -notmatch [regex]::Escape([string]$token))) {
                    if ($status -ne 'ERROR') { $status = 'WARN' }
                    $notes += ('missing token: ' + $token)
                }
            }
        }
    }

    foreach ($dep in @($rule.dependsOn)) {
        if ($dep -and -not (Test-Path -LiteralPath $dep)) {
            if ($status -ne 'ERROR') { $status = 'WARN' }
            $notes += ('missing dependency: ' + $dep)
        }
    }

    $results += [pscustomobject]@{
        path = $path
        type = $rule.type
        required = $rule.required
        status = $status
        notes = ($notes -join '; ')
        exists = (Test-Path -LiteralPath $path)
        description = $rule.description
    }
}

# Dodatkowy auto-fill: jeżeli źródłowy backup_live.json istnieje, a w panelu go nie ma — skopiuj
$panelLive = Join-Path $DataRoot 'backup_live.json'
$reportsLive = 'E:\BACKUPS\reports\backup_live.json'
if ((Test-Path -LiteralPath $reportsLive) -and -not (Test-Path -LiteralPath $panelLive)) {
    Copy-Item -LiteralPath $reportsLive -Destination $panelLive -Force -ErrorAction SilentlyContinue
    $results += [pscustomobject]@{
        path = $panelLive
        type = 'file'
        required = $true
        status = 'FIXED'
        notes = 'copied missing backup_live.json from reports'
        exists = $true
        description = 'autofill live file'
    }
}

$txt = @()
$txt += '=== PANEL STRUCTURE REPORT ==='
$txt += ('Generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$txt += ''
foreach ($r in $results) {
    $txt += ('[{0}] {1}' -f $r.status, $r.path)
    if ($r.notes) {
        $txt += ('  -> ' + $r.notes)
    }
}

$txt -join "`r`n" | Set-Content -Path $ReportTxt -Encoding UTF8
$results | ConvertTo-Json -Depth 6 | Set-Content -Path $ReportJson -Encoding UTF8

Write-Host "OK: mapa sprawdzona i uzupelniona."
Write-Host ("TXT report:  " + $ReportTxt)
Write-Host ("JSON report: " + $ReportJson)