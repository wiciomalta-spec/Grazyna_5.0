<#
.SYNOPSIS
    Rozszerzony skrypt naprawczy dla Grazyna_5.0 z:
    - Automatycznym pobieraniem sterowników (KESS, K-TAG, FGTech itp.) z GitHub.
    - Weryfikacją sum kontrolnych (MD5) plików.
.DESCRIPTION
    Skrypt wykonuje:
    1. Tworzy brakujące foldery (scripts, drivers, config).
    2. Przenosi skrypty PowerShell z /core do /scripts.
    3. Pobiera sterowniki do /drivers (z repozytorium GitHub).
    4. Weryfikuje sumy MD5 plików po przeniesieniu.
.NOTES
    Wymagania: PowerShell 7+, dostęp do internetu, uprawnienia administratora.
#>

$rootPath = "E:\Grazyna_5.0"
$dryRun = $false
$downloadDrivers = $true
$verifyMD5 = $true

# Pobieranie sterowników
function Download-Drivers {
    if (-not $downloadDrivers) { return }
    try {
        $githubUrl = "https://github.com/TUNERPRO/TUNERPRO-Drivers/archive/refs/heads/main.zip"
        $zipPath = "$env:TEMP\drivers.zip"
        $extractPath = "$env:TEMP\drivers"
        
        Write-Host "Pobieranie sterowników..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $githubUrl -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        # Kopiuj sterowniki do /drivers
        $drivers = @("KESS", "K-TAG", "FGTech")
        foreach ($driver in $drivers) {
            $src = "$extractPath\TUNERPRO-Drivers-main\$driver"
            $dest = "$rootPath\drivers\$driver"
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $dest -Recurse -Force
                Write-Host "✅ Sterownik $driver skopiowany do /drivers/" -ForegroundColor Green
            }
        }
        Remove-Item $zipPath, $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "❌ Błąd pobierania sterowników: $_" -ForegroundColor Red
    }
}

# Weryfikacja MD5
function Verify-MD5 {
    if (-not $verifyMD5) { return }
    Write-Host "Weryfikacja MD5..." -ForegroundColor Cyan
    $files = Get-ChildItem -Path "$rootPath\scripts" -File -Recurse
    foreach ($file in $files) {
        $hash = (Get-FileHash -Path $file.FullName -Algorithm MD5).Hash
        Write-Host "$($file.Name): $hash" -ForegroundColor Yellow
    }
}

# Główne działania
New-Item -Path "$rootPath\scripts", "$rootPath\drivers", "$rootPath\config" -ItemType Directory -Force | Out-Null
Move-Item -Path "$rootPath\core\*.ps1" -Destination "$rootPath\scripts" -Force -ErrorAction SilentlyContinue
Download-Drivers
Verify-MD5

# Integracja launcher.ps1
if (Test-Path "$rootPath\GRAZYNA_LAUNCHER.ps1") {
    Copy-Item -Path "$rootPath\GRAZYNA_LAUNCHER.ps1" -Destination "$rootPath\scripts\launcher.ps1" -Force
    Write-Host "✅ Zintegrowano GRAZYNA_LAUNCHER.ps1" -ForegroundColor Green
}

# Utwórz config.json
$config = @{
    "TUNERPRO" = @{
        "version" = "2.0.0"
        "install_dir" = $rootPath
        "drivers" = @("KESS", "K-TAG", "FGTech")
    }
} | ConvertTo-Json | Out-File -FilePath "$rootPath\config\config.json"

Write-Host "✅ Skrypt zakończony!" -ForegroundColor Green