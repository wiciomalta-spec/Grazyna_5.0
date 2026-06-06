$PanelRoot = "E:\Grazyna_5.0\backup-panel"
$DataRoot = Join-Path $PanelRoot "data"
$SourceReports = "E:\BACKUPS\reports"

New-Item -ItemType Directory -Force -Path $DataRoot | Out-Null

Copy-Item -LiteralPath (Join-Path $SourceReports "backup_live.json")            -Destination (Join-Path $DataRoot "backup_live.json") -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath (Join-Path $SourceReports "backup_size_report.csv")      -Destination (Join-Path $DataRoot "backup_size_report.csv") -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath (Join-Path $SourceReports "backup_integrity_report.txt") -Destination (Join-Path $DataRoot "backup_integrity_report.txt") -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath (Join-Path $SourceReports "backup_log.txt")              -Destination (Join-Path $DataRoot "backup_log.txt") -Force -ErrorAction SilentlyContinue

Write-Host "OK: Panel data synchronized."
