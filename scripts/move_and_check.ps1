<#
.SYNOPSIS
  Przenieś projekt na E:, zweryfikuj, popraw docker-compose ścieżki, zainstaluj deps, zbuduj i uruchom kontenery, pokaż logi.

.PARAMETER Source
  Ścieżka źródłowa projektu (np. C:\Users\wicio\Grazyna_5.0). Jeśli katalog nie istnieje, skrypt spróbuje pominąć kopiowanie.

.PARAMETER Dest
  Ścieżka docelowa (np. E:\Grazyna_5.0).

.PARAMETER RemoveSource
  Jeśli ustawione, po weryfikacji i potwierdzeniu usunie katalog źródłowy.

.EXAMPLE
  .\move_and_check.ps1 -Source "C:\Users\wicio\Grazyna_5.0" -Dest "E:\Grazyna_5.0" -RemoveSource:$false
#>

param(
  [string]$Source = "C:\Users\wicio\Grazyna_5.0",
  [string]$Dest   = "E:\Grazyna_5.0",
  [switch]$RemoveSource
)

function Count-Files($path) {
  if (-not (Test-Path $path)) { return 0 }
  return (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
}

function Replace-AbsolutePathsInCompose($filePath, $projectRoot) {
  # Zamienia wystąpienia ścieżek typu C:\... lub D:\... na względne ./ jeśli mieszczą się w projekcie
  $content = Get-Content -Raw -Path $filePath -ErrorAction Stop
  $updated = $false

  # Regex: znajdź Windows absolute paths w formacie "C:\..." lub "C:/..."
  $pattern = '(?:[A-Za-z]:[\\/][^\s"''\)\]]+)'
  $replacements = @()

  [regex]::Matches($content, $pattern) | ForEach-Object {
    $abs = $_.Value
    # Normalize slashes
    $norm = $abs -replace '/','\'
    # If path is inside project root, convert to relative
    try {
      $full = (Resolve-Path -LiteralPath $norm -ErrorAction Stop).ProviderPath
      if ($full -like "$projectRoot*") {
        $rel = $full.Substring($projectRoot.Length).TrimStart('\','/')
        $relUnix = "./" + ($rel -replace '\\','/')
        $content = $content -replace [regex]::Escape($abs), $relUnix
        $updated = $true
      }
    } catch {
      # ignore unresolved paths
    }
  }

  if ($updated) {
    Write-Host "  - Aktualizuję ścieżki w $filePath"
    $backup = "$filePath.bak.$((Get-Date).ToString('yyyyMMddHHmmss'))"
    Copy-Item -Path $filePath -Destination $backup -Force
    Set-Content -Path $filePath -Value $content -Force
    return $true
  }
  return $false
}

Write-Host "=== Move and Check — start ==="
Write-Host "Source: $Source"
Write-Host "Dest:   $Dest"

# 1) Jeśli źródło istnieje, skopiuj; jeśli nie, sprawdź czy dest już ma projekt
if (Test-Path $Source) {
  if (-not (Test-Path $Dest)) {
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    Write-Host "Utworzono katalog docelowy $Dest"
  }
  Write-Host "Kopiowanie projektu (robocopy, pomijając node_modules)..."
  $robocopyArgs = @($Source, $Dest, "/MIR", "/Z", "/R:3", "/W:5", "/MT:8", "/XD", "node_modules")
  $proc = Start-Process -FilePath robocopy -ArgumentList $robocopyArgs -Wait -NoNewWindow -PassThru
  if ($proc.ExitCode -ge 8) {
    Write-Warning "Robocopy zakończone z kodem $($proc.ExitCode). Sprawdź output ręcznie."
  } else {
    Write-Host "Kopiowanie zakończone (kod $($proc.ExitCode))."
  }
} else {
  Write-Warning "Źródło $Source nie istnieje. Zakładam, że projekt już jest w $Dest i pomijam kopiowanie."
}

# 2) Weryfikacja zawartości
$srcCount = Count-Files $Source
$dstCount = Count-Files $Dest
Write-Host "Liczba plików: Source=$srcCount  Dest=$dstCount"

if ($srcCount -gt 0 -and $srcCount -ne $dstCount) {
  Write-Warning "Liczba plików różni się. Sprawdź ręcznie. Kontynuuję, ale nie usuwam źródła."
}

# 3) Poprawa ścieżek w docker-compose*.yml
Write-Host "Skanowanie plików docker-compose*.yml w $Dest i poprawa absolutnych ścieżek..."
$composeFiles = Get-ChildItem -Path $Dest -Filter "docker-compose*.yml" -Recurse -ErrorAction SilentlyContinue
if ($composeFiles.Count -eq 0) {
  Write-Host "  - Brak plików docker-compose*.yml w projekcie."
} else {
  foreach ($f in $composeFiles) {
    try {
      Replace-AbsolutePathsInCompose -filePath $f.FullName -projectRoot (Resolve-Path $Dest).ProviderPath | Out-Null
    } catch {
      Write-Warning "  - Błąd podczas aktualizacji $($f.FullName): $_"
    }
  }
}

# 4) Backup ważnych plików (README, .env, docker-compose.yml)
$backupRoot = Join-Path $Dest "backup_pre_deploy_$(Get-Date -Format yyyyMMddHHmmss)"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$toBackup = @("README.md","docker-compose.yml","docker-compose.prod.yml","backend\.env","frontend\.env")
foreach ($name in $toBackup) {
  $path = Join-Path $Dest $name
  if (Test-Path $path) {
    Copy-Item -Path $path -Destination $backupRoot -Force
  }
}
Write-Host "Utworzono backup kluczowych plików w $backupRoot"

# 5) Usuń node_modules w dest i wyczyść npm cache
Write-Host "Czyszczenie node_modules w dest (frontend/backend) i czyszczenie cache npm..."
$fm = Join-Path $Dest "frontend\node_modules"
$bm = Join-Path $Dest "backend\node_modules"
Remove-Item -Recurse -Force $fm -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $bm -ErrorAction SilentlyContinue
npm cache clean --force

# 6) Instalacja zależności (npm ci) w backend i frontend jeśli package.json istnieje
if (Test-Path (Join-Path $Dest "backend\package.json")) {
  Push-Location (Join-Path $Dest "backend")
  Write-Host "Instalacja zależności backend..."
  npm ci
  Pop-Location
} else {
  Write-Host "Brak backend/package.json — pomijam instalację backend."
}
if (Test-Path (Join-Path $Dest "frontend\package.json")) {
  Push-Location (Join-Path $Dest "frontend")
  Write-Host "Instalacja zależności frontend..."
  npm ci
  Pop-Location
} else {
  Write-Host "Brak frontend/package.json — pomijam instalację frontend."
}

# 7) Build i uruchomienie docker-compose
Push-Location $Dest
if (Test-Path (Join-Path $Dest "docker-compose.yml")) {
  Write-Host "Budowanie obrazów (docker-compose build --no-cache)..."
  docker-compose build --no-cache
  Write-Host "Uruchamianie kontenerów (docker-compose up -d)..."
  docker-compose up -d
  Start-Sleep -Seconds 6
} else {
  Write-Warning "Brak docker-compose.yml w $Dest. Pomiń uruchomienie."
}
Pop-Location

# 8) Zbieranie statusu i logów
Write-Host "Pobieram status kontenerów (docker ps)..."
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

# 9) Sprawdzenie backend health endpoints (próbujemy kilka portów)
$healthChecked = $false
$possiblePorts = @(4000,3001,3000,5173)
foreach ($p in $possiblePorts) {
  try {
    $url = "http://localhost:$p/health"
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    Write-Host "Health OK: $url -> $($r.StatusCode)"
    $healthChecked = $true
    break
  } catch {
    # spróbuj innego endpointu
  }
}
if (-not $healthChecked) {
  Write-Warning "Nie udało się potwierdzić health endpoint na standardowych portach. Sprawdź logi backend."
}

# 10) Pobierz ostatnie 200 linii logów backend (jeśli usługa istnieje)
$backendContainer = (docker ps --format "{{.Names}}" | Where-Object { $_ -match "backend|grazyna-backend|grazyna" } | Select-Object -First 1)
if ($backendContainer) {
  Write-Host "Pobieram logi kontenera backend: $backendContainer"
  docker logs --tail 200 $backendContainer 2>&1 | Out-String | Tee-Object -Variable backendLogs
} else {
  Write-Warning "Nie znaleziono kontenera backend w docker ps."
}

# 11) Prosta analiza logów: szukamy ERROR/WARN/Traceback/Exception
if ($backendLogs) {
  $errors = ($backendLogs -split "`n") | Where-Object { $_ -match '(ERROR|WARN|Traceback|Exception|CRITICAL)' }
  if ($errors.Count -gt 0) {
    Write-Host "=== Znalezione potencjalne problemy w logach backend (przykłady) ==="
    $errors | Select-Object -First 30 | ForEach-Object { Write-Host $_ }
  } else {
    Write-Host "Brak oczywistych ERROR/WARN/Traceback w ostatnich logach backend."
  }
}

# 12) Opcjonalne usunięcie źródła
if ($RemoveSource.IsPresent -and (Test-Path $Source)) {
  $confirm = Read-Host "Usunąć katalog źródłowy $Source ? (tak/nie)"
  if ($confirm -match '^(t|y|tak|yes)$') {
    Write-Host "Usuwam źródło..."
    Remove-Item -Recurse -Force $Source
    Write-Host "Usunięto źródło."
  } else {
    Write-Host "Pominięto usuwanie źródła."
  }
}

Write-Host "=== Move and Check — zakończono ==="
Write-Host "Sprawdź: docker ps, docker-compose logs -f backend, oraz frontend i backend endpoints w przeglądarce."