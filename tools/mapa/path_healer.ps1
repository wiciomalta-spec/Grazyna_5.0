$Root = "E:\Grazyna_5.0"
$ScanDisk = "E:\"   # gdzie szukać brakujących plików
$Report = @()
$FileList = @()

Write-Host "=== GRAZYNA 5.0 — PATH HEALER ===" -ForegroundColor Cyan

# 1. Pobierz listę wszystkich plików w repo
$RepoFiles = Get-ChildItem -Path $Root -Recurse -File

foreach ($file in $RepoFiles) {
    $FileList += [PSCustomObject]@{
        Name = $file.Name
        Path = $file.FullName
        Exists = $true
    }
}

# 2. Pobierz listę plików zgłoszonych przez GIT jako missing/deleted
$GitStatus = git -C $Root status --porcelain

$Missing = $GitStatus | Where-Object { $_ -match "^ D " } | ForEach-Object {
    ($_ -replace "^ D ", "").Trim()
}

foreach ($missing in $Missing) {

    $ExpectedPath = Join-Path $Root $missing

    if (-not (Test-Path $ExpectedPath)) {

        Write-Host "Brak pliku: $missing" -ForegroundColor Red

        # 3. Szukaj pliku na całym dysku
        $Found = Get-ChildItem -Path $ScanDisk -Recurse -Filter (Split-Path $missing -Leaf) -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($Found) {
            Write-Host "Znaleziono: $($Found.FullName)" -ForegroundColor Yellow

            # 4. Automatyczna naprawa ścieżki
            $Dir = Split-Path $ExpectedPath -Parent
            if (-not (Test-Path $Dir)) {
                New-Item -ItemType Directory -Path $Dir -Force | Out-Null
            }

            Copy-Item $Found.FullName $ExpectedPath -Force

            $Report += "NAPRAWIONO: $missing → $($Found.FullName)"
        }
        else {
            $Report += "NIE ZNALEZIONO: $missing"
        }
    }
}

# 5. Raport końcowy
$Report | Out-File "$Root\GRAZYNA_PATH_HEALER_REPORT.txt"

Write-Host "=== PATH HEALER ZAKOŃCZONY ===" -ForegroundColor Cyan