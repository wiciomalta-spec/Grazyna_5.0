@echo off
:: TUNERPRO v2.0.0-PRO-MAX ? Samowystarczalny pakiet
:: Uruchom jako administrator!

:: Sprawd?, czy PowerShell 7+ jest dost?pny
where pwsh >nul 2>&1
if %ERRORLEVEL% equ 0 (
    pwsh.exe -ExecutionPolicy Bypass -File "%~dp0TUNERPRO.ps1" -NoExit
) else (
    :: Je?li nie ma PowerShell 7+, spr?buj z PowerShell 5.1
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0TUNERPRO.ps1" -NoExit
)

pause
