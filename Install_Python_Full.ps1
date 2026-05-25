Write-Host "=== AUTOMATYCZNA INSTALACJA PYTHONA 3.10.11 (FULL + TKINTER) ==="

# 1. Ścieżki
$pythonInstaller = "$env:TEMP\python-3.10.11-amd64.exe"
$pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
$installDir = "C:\Python310"
$portableDir = "E:\Grazyna_5.0\tools\PythonPortable"

# 2. Pobieranie instalatora
Write-Host "[INFO] Pobieram instalator Pythona..."
Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller

# 3. Instalacja cicha
Write-Host "[INFO] Instaluję Pythona do C:\Python310..."
Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=0 TargetDir=$installDir Include_tcltk=1 Include_pip=1" -Wait

# 4. Sprawdzenie instalacji
if (!(Test-Path "$installDir\python.exe")) {
    Write-Host "[BŁĄD] Python nie został zainstalowany!"
    exit
}

Write-Host "[OK] Python zainstalowany."

# 5. Kopiowanie jako portable
Write-Host "[INFO] Kopiuję Pythona jako portable do Grażyny..."
if (Test-Path $portableDir) {
    Remove-Item $portableDir -Recurse -Force
}
Copy-Item $installDir $portableDir -Recurse -Force

# 6. Weryfikacja tkinter
Write-Host "[INFO] Sprawdzam tkinter..."
$tkPath = Join-Path $portableDir "DLLs\tkinter.pyd"
$tclPath = Join-Path $portableDir "tcl\tk8.6"

if (!(Test-Path $tkPath) -or !(Test-Path $tclPath)) {
    Write-Host "[BŁĄD] Brakuje tkinter! Instalacja niekompletna."
    exit
}

Write-Host "[OK] Tkinter jest dostępny."

# 7. Uruchomienie Grażyny
Write-Host "[INFO] Uruchamiam Grażynę 5.1..."
Start-Process "E:\Grazyna_5.0\launch.bat"

Write-Host "=== GOTOWE ==="
