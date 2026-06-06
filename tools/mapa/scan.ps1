$Root = "E:\Grazyna_5.0"
$ConfigFile = "$Root\config\paths.json"

$RequiredFiles = @(
    @{ Name="backend.exe"; Path="$Root\backend\backend.exe" }
    @{ Name="frontend.exe"; Path="$Root\frontend\frontend.exe" }
    @{ Name="node.exe"; Path="$Root\nodejs\node.exe" }
)

$Report = @()

foreach ($file in $RequiredFiles) {

    if (Test-Path $file.Path) {
        $Report += "OK: $($file.Name) → $($file.Path)"
        continue
    }

    $Report += "MISSING: $($file.Name) → expected $($file.Path)"

    $found = Get-ChildItem -Path "E:\" -Recurse -Filter $file.Name -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($found) {
        $Report += "FOUND: $($file.Name) → $($found.FullName)"

        (Get-Content $ConfigFile) -replace [regex]::Escape($file.Path), $found.FullName |
            Set-Content $ConfigFile

        $Report += "UPDATED PATH: $($file.Name)"
    }
    else {
        $Report += "NOT FOUND: $($file.Name)"
    }
}

$Report | Out-File "$Root\GRAZYNA_SCAN_REPORT.txt"
Write-Host "Skanowanie zakończone."