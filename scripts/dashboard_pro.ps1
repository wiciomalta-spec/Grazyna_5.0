# ============================================
#   GRAZYNA 5.0 – DASHBOARD PRO (LIVE)
#   Tryb: TYLKO PODGLĄD – ZERO INGERENCJI
# ============================================

$root = "E:\Grazyna_5.0"
$logFile = "$root\logs\system.log"

# --- Tworzenie skrótu na pulpicie ---
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = "$desktop\GRAZYNA Dashboard PRO.lnk"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "pwsh.exe"
$Shortcut.Arguments = "-NoExit -File `"$root\dashboard_pro.ps1`""
$Shortcut.WorkingDirectory = $root
$Shortcut.WindowStyle = 1
$Shortcut.IconLocation = "shell32.dll, 44"
$Shortcut.Save()

Write-Host "Skrót 'GRAZYNA Dashboard PRO' utworzony na pulpicie." -ForegroundColor Green

# --- Funkcja rysująca sekcję ---
function Section($title, $color="Yellow") {
    Write-Host ""
    Write-Host ("==== " + $title + " ====") -ForegroundColor $color
}

# --- Dashboard Live ---
while ($true) {
    Clear-Host
    Write-Host "██████╗  █████╗ ███████╗██╗   ██╗███╗   ██╗ █████╗     5.0" -ForegroundColor Cyan
    Write-Host "██╔══██╗██╔══██╗██╔════╝██║   ██║████╗  ██║██╔══██╗" -ForegroundColor Cyan
    Write-Host "██████╔╝███████║███████╗██║   ██║██╔██╗ ██║███████║" -ForegroundColor Cyan
    Write-Host "██╔══██╗██╔══██║╚════██║██║   ██║██║╚██╗██║██╔══██║" -ForegroundColor Cyan
    Write-Host "██████╔╝██║  ██║███████║╚██████╔╝██║ ╚████║██║  ██║" -ForegroundColor Cyan
    Write-Host "╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝" -ForegroundColor Cyan
    Write-Host ""

    # --- LOGI ---
    Section "Ostatnie logi"
    if (Test-Path $logFile) {
        Get-Content $logFile -Tail 15
    } else {
        Write-Host "Brak logów." -ForegroundColor Red
    }

    # --- PROCESY ---
    Section "Procesy aktywne"
    Get-Process | Where-Object { $_.ProcessName -match "python|pwsh|gra" } |
        Select-Object ProcessName, Id, CPU, WorkingSet

    # --- ZMIANY PLIKÓW ---
    Section "Ostatnie zmiany plików"
    Get-ChildItem $root -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object FullName, LastWriteTime -First 10

    # --- UŻYCIE DYSKU ---
    Section "Użycie dysku"
    Get-PSDrive | Where-Object { $_.Name -eq "E" } |
        Select-Object Name, Used, Free

    # --- CZAS SYSTEMU ---
    Section "Czas systemu"
    Write-Host (Get-Date)

    Start-Sleep -Seconds 2
}
