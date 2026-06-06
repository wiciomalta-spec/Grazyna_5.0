# =====================================================================
# Grażyna 5.1 Tile Edition - Installer
# =====================================================================

param(
    [string]$RootPath = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Grażyna 5.1 Tile Edition Installer"
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

$Folders = @(
    "tile_launcher",
    "tile_launcher\core",
    "tile_launcher\ui",
    "tile_launcher\widgets",
    "tile_launcher\plugins",
    "tile_launcher\config",

    "diagnostics",
    "diagnostics\logs",

    "vehicle_database",
    "vehicle_database\data",

    "ecu_tools",
    "ecu_tools\maps",
    "ecu_tools\projects",

    "ai_assistant",

    "monitoring",
    "sync",
    "api",

    "backups",
    "logs",
    "config"
)

foreach ($Folder in $Folders)
{
    $Path = Join-Path $RootPath $Folder

    if (!(Test-Path $Path))
    {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

$SystemConfig = @{
    name = "Grażyna 5.1 Tile Edition"
    version = "5.1"
    auto_discovery = $true
    theme = "dark"

    modules = @(
        "diagnostics",
        "vehicle_database",
        "ecu_tools",
        "ai_assistant",
        "monitoring",
        "sync",
        "api"
    )
}

$SystemConfig |
ConvertTo-Json -Depth 10 |
Set-Content "$RootPath\config\system.json" -Encoding UTF8

$TileConfig = @{
    columns = 6
    tile_size = "medium"
    auto_generate = $true
}

$TileConfig |
ConvertTo-Json |
Set-Content "$RootPath\tile_launcher\config\tiles.json" -Encoding UTF8

@"
CREATE TABLE IF NOT EXISTS vehicles(
    id INTEGER PRIMARY KEY,
    brand TEXT,
    model TEXT,
    engine TEXT,
    ecu TEXT
);

CREATE TABLE IF NOT EXISTS dtc(
    id INTEGER PRIMARY KEY,
    code TEXT,
    description TEXT
);

CREATE TABLE IF NOT EXISTS ecu_files(
    id INTEGER PRIMARY KEY,
    file_name TEXT,
    checksum TEXT
);
"@ | Set-Content "$RootPath\vehicle_database\schema.sql" -Encoding UTF8

@"
from pathlib import Path

print("Grażyna Tile Launcher")

for item in Path('.').iterdir():
    print(item.name)
"@ | Set-Content "$RootPath\tile_launcher\launcher.py" -Encoding UTF8

@"
# Auto Discovery

from pathlib import Path

SUPPORTED = [
    '.exe',
    '.py',
    '.bat',
    '.ps1',
    '.json',
    '.sql'
]

def scan(path):
    results = []

    for item in Path(path).rglob('*'):
        if item.suffix.lower() in SUPPORTED:
            results.append(str(item))

    return results

if __name__ == '__main__':
    for x in scan('.'):
        print(x)
"@ | Set-Content "$RootPath\tile_launcher\core\discovery.py" -Encoding UTF8

@"
# Diagnostics Module
# DTC
# Live Data
# Coding
# Adaptation
# CAN Monitor
"@ | Set-Content "$RootPath\diagnostics\module.txt" -Encoding UTF8

@"
# ECU Module
# Map Viewer
# Compare
# Checksum
# DPF
# EGR
"@ | Set-Content "$RootPath\ecu_tools\module.txt" -Encoding UTF8

@"
# AI Assistant Module
# Error Analysis
# Log Analysis
# ECU Analysis
"@ | Set-Content "$RootPath\ai_assistant\module.txt" -Encoding UTF8

@"
# Monitoring
# CPU
# RAM
# Disk
# API
# PostgreSQL
"@ | Set-Content "$RootPath\monitoring\module.txt" -Encoding UTF8

$Detected = @{
    python = $null
    node = $null
    git = $null
    docker = $null
}

try { $Detected.python = (python --version) 2>&1 } catch {}
try { $Detected.node = (node --version) 2>&1 } catch {}
try { $Detected.git = (git --version) 2>&1 } catch {}
try { $Detected.docker = (docker --version) 2>&1 } catch {}

$Detected |
ConvertTo-Json |
Set-Content "$RootPath\logs\environment.json" -Encoding UTF8

$BackupName = "PRE_TILE_SYSTEM_" + (Get-Date -Format "yyyyMMdd_HHmmss")

New-Item `
    -ItemType Directory `
    -Path "$RootPath\backups\$BackupName" `
    -Force | Out-Null

Write-Host ""
Write-Host "Instalacja zakończona." -ForegroundColor Green
Write-Host "Lokalizacja: $RootPath" -ForegroundColor Yellow
Write-Host ""