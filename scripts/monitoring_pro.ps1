# ================================
#   GRAZYNA 5.0 – MONITORING PRO
#   Tryb: TYLKO PODGLĄD (bez ingerencji)
# ================================

$root = "E:\Grazyna_5.0"
$logFile = "$root\logs\system.log"

# --- Tworzenie skrótu na pulpicie ---
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = "$desktop\GRAZYNA Monitoring PRO.lnk"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "pwsh.exe"
$Shortcut.Arguments = "-NoExit -File `"$root\monitoring_pro.ps1`""
$Shortcut.WorkingDirectory = $root
$Shortcut.WindowStyle = 1
$Shortcut.IconLocation = "shell32.dll, 44"
$Shortcut.Save()

Write-Host "Skrót 'GRAZYNA Monitoring PRO' utworzony na pulpicie." -ForegroundColor Green

# --- Monitoring live ---
while ($true) {
    Clear-Host
    Write-Host "=== GRAZYNA 5.0 – MONITORING PRO (LIVE) ===" -ForegroundColor Cyan

    # --- Logi systemowe ---
    Write-Host "`n--- Ostatnie logi ---" -ForegroundColor Yellow
    if (Test-Path $logFile) {
        Get-Content $logFile -Tail 20
    } else {
        Write-Host "Brak pliku logów." -ForegroundColor Red
    }

    # --- Procesy powiązane ---
    Write-Host "`n--- Procesy aktywne ---" -ForegroundColor Yellow
    Get-Process | Where-Object { $_.ProcessName -match "python|pwsh|gra" } |
        Select-Object ProcessName, Id, CPU, WorkingSet

    # --- Ostatnie zmiany plików ---
    Write-Host "`n--- Ostatnie zmiany plików ---" -ForegroundColor Yellow
    Get-ChildItem $root -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object FullName, LastWriteTime -First 10

    Start-Sleep -Seconds 2
}
