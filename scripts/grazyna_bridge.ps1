param(
    [string]$SourcePath = "E:\Grazyna_5.0\reports",
    [string]$DestinationPath = "D:\OneDrive\GRAZYNA\reports"
)

# Kopiuj raporty do Grażyny
if (Test-Path $SourcePath) {
    $reports = Get-ChildItem -Path $SourcePath -File
    foreach ($report in $reports) {
        $dest = Join-Path $DestinationPath $report.Name
        Copy-Item -Path $report.FullName -Destination $dest -Force
        Write-Host "[GRAZYNA_BRIDGE] Skopiowano: $($report.Name) → $dest" -ForegroundColor Green
    }
} else {
    Write-Host "[GRAZYNA_BRIDGE] ❌ Ścieżka źródłowa nie istnieje: $SourcePath" -ForegroundColor Red
}
