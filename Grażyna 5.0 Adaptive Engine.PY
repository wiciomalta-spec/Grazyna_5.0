from pathlib import Path

content = r'''# GRAŻYNA 5.0 - Adaptive Engine Installer (Skeleton)
# PowerShell 7+

param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

Write-Host "=== GRAŻYNA 5.0 Adaptive Installer ==="

$root = (Resolve-Path $ProjectRoot).Path

$dirs = @(
    ".grazyna",
    ".grazyna\snapshots",
    ".grazyna\audits",
    ".grazyna\telemetry",
    ".grazyna\errors",
    ".grazyna\recommendations",
    ".grazyna\knowledge",
    ".grazyna\reports",
    ".grazyna\health",
    ".grazyna\workspace"
)

foreach($d in $dirs){
    New-Item -ItemType Directory -Force -Path (Join-Path $root $d) | Out-Null
}

$config = @{
    version = "5.0"
    adaptive_engine = $true
    health_monitor = $true
    recommendations = $true
    snapshots = $true
    audit_log = $true
} | ConvertTo-Json

$config | Set-Content (Join-Path $root ".grazyna\config.json")

$readme = @"
GRAZYNA 5.0 ADAPTIVE ENGINE

Funkcje:
- Monitoring projektu
- Rejestr błędów
- Health Center
- Snapshoty
- Knowledge Base
- Rekomendacje zmian

Przed automatycznymi zmianami wymagane jest zatwierdzenie użytkownika.
"@

$readme | Set-Content (Join-Path $root ".grazyna\README.txt")

Write-Host "Instalacja zakończona."
Write-Host "Katalog projektu: $root"
'''

path = "/mnt/data/Grazyna5_AdaptiveInstaller.ps1"
Path(path).write_text(content, encoding="utf-8")

print(path)