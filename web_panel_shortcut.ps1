$root = "E:\Grazyna_5.0"
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = "$desktop\GRAZYNA Web Panel PRO.lnk"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "pwsh.exe"
$Shortcut.Arguments = "-NoExit -Command `"`& 'python' '$root\web_panel_pro.py'`""
$Shortcut.WorkingDirectory = $root
$Shortcut.WindowStyle = 1
$Shortcut.IconLocation = "shell32.dll, 44"
$Shortcut.Save()

Write-Host "Skrót 'GRAZYNA Web Panel PRO' utworzony na pulpicie." -ForegroundColor Green
