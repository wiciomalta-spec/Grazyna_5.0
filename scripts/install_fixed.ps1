#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$DownloadDir = Join-Path $Root "downloads"
New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null

# === LISTA PLIKÓW DO POBRANIA (UZUPEŁNIJ!) ===
# Url = skąd pobrać
# Out = nazwa pliku lokalnie
# Sha256 = opcjonalnie oczekiwany SHA256 (jeśli masz)
$Downloads = @(
  [pscustomobject]@{ Url="https://example.com/driverpack.zip"; Out="driverpack.zip"; Sha256="" }
  # dodaj kolejne:
  # [pscustomobject]@{ Url="https://..."; Out="..."; Sha256="..." }
)

function Test-Url($Url) {
  try {
    $r = Invoke-WebRequest -Uri $Url -Method Head -MaximumRedirection 5 -TimeoutSec 20 -ErrorAction Stop
    return [pscustomobject]@{ Url=$Url; Ok=$true; Status=$r.StatusCode }
  } catch {
    # fallback: czasem serwer nie wspiera HEAD, więc próbujemy GET z minimalną treścią
    try {
      $r2 = Invoke-WebRequest -Uri $Url -Method Get -MaximumRedirection 5 -TimeoutSec 20 -ErrorAction Stop
      return [pscustomobject]@{ Url=$Url; Ok=$true; Status=$r2.StatusCode }
    } catch {
      return [pscustomobject]@{ Url=$Url; Ok=$false; Status=("ERR: " + $_.Exception.Message) }
    }
  }
}

function Download-File($Url, $OutPath) {
  # Standardowy download przez Invoke-WebRequest z -OutFile [4](https://powershellfaqs.com/download-file-from-url-in-powershell/)[5](https://lazyadmin.nl/powershell/download-file-powershell/)
  Invoke-WebRequest -Uri $Url -OutFile $OutPath -MaximumRedirection 5 -TimeoutSec 120
  if (-not (Test-Path $OutPath)) { throw "Nie zapisano pliku: $OutPath" }

  $len = (Get-Item $OutPath).Length
  if ($len -le 0) {
    # chroni przed pustymi plikami (MD5 pustego pliku = D41D8...) [1](https://stackoverflow.com/questions/10909976/why-do-seemingly-empty-files-and-strings-produce-md5sums)
    throw "Pobrany plik jest pusty (0B): $OutPath"
  }
}

function Verify-Sha256($Path, $Expected) {
  if ([string]::IsNullOrWhiteSpace($Expected)) { return }
  $h = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToUpperInvariant()
  if ($h -ne $Expected.ToUpperInvariant()) {
    throw "SHA256 niezgodny dla $Path. Jest: $h, oczekiwano: $Expected"
  }
}

Write-Host "ROOT: $Root" -ForegroundColor Cyan
Write-Host "Katalog pobrań: $DownloadDir" -ForegroundColor Cyan
Write-Host "Sprawdzam URL-e..." -ForegroundColor Yellow

$checks = $Downloads | ForEach-Object { Test-Url $_.Url }
$bad = $checks | Where-Object { -not $_.Ok }

$checks | Format-Table -AutoSize

if ($bad) {
  Write-Host "`n❌ Wykryto niedziałające URL-e. Przerywam, żeby nie tworzyć pustych plików." -ForegroundColor Red
  $bad | Format-Table -AutoSize
  exit 2
}

Write-Host "`nPobieram pliki..." -ForegroundColor Yellow

foreach ($d in $Downloads) {
  $outPath = Join-Path $DownloadDir $d.Out
  Write-Host "➡ $($d.Url) -> $outPath" -ForegroundColor Gray
  try {
    Download-File -Url $d.Url -OutPath $outPath
    Verify-Sha256 -Path $outPath -Expected $d.Sha256
    Write-Host "✅ OK: $($d.Out)" -ForegroundColor Green
  } catch {
    Write-Host "❌ FAIL: $($d.Out) :: $($_.Exception.Message)" -ForegroundColor Red
    exit 3
  }
}

Write-Host "`n✅ Pobieranie i weryfikacja zakończone." -ForegroundColor Green

# === tu możesz dodać rozpakowanie / instalację sterowników itp. ===
# np. Expand-Archive driverpack.zip -DestinationPath ...