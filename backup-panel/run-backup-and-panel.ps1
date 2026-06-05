$Backup = "E:\BACKUPS\backup_grazyna.ps1"
$Sync   = "E:\Grazyna_5.0\backup-panel\sync-backup-data.ps1"
$Tile   = "E:\Grazyna_5.0\backup-panel\add-backup-live-tile.ps1"
$Start  = "E:\Grazyna_5.0\backup-panel\start-backup-dashboard.ps1"

Write-Host "1/4 Backup..."
pwsh -ExecutionPolicy Bypass -File $Backup

Write-Host "2/4 Sync danych..."
pwsh -ExecutionPolicy Bypass -File $Sync

Write-Host "3/4 Kafelek..."
pwsh -ExecutionPolicy Bypass -File $Tile

Write-Host "4/4 Start panelu..."
pwsh -ExecutionPolicy Bypass -File $Start
