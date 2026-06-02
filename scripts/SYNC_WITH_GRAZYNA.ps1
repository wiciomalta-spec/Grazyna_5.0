# Skrypt synchronizacji raportów z Grażyną (OneDrive)
$source = "E:\Grazyna_5.0\reports"
$dest = "D:\OneDrive\GRAZYNA\reports"

if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
}

# Kopiuj wszystkie pliki z reports (w tym raporty z motywami)
$files = Get-ChildItem -Path $source -File
foreach ($file in $files) {
    $destFile = Join-Path $dest $file.Name
    Copy-Item -Path $file.FullName -Destination $destFile -Force
    Write-Host "[SYNC] ✅ Zsynchronizowano: $($file.Name)" -ForegroundColor Green
}

# Kopiuj także pliki z motywami (GRAZYNA_REPORT_*.html)
$themeReports = Get-ChildItem -Path $source -Filter "GRAZYNA_REPORT_*.html"
foreach ($report in $themeReports) {
    $destReport = Join-Path $dest $report.Name
    Copy-Item -Path $report.FullName -Destination $destReport -Force
    Write-Host "[SYNC] ✅ Zsynchronizowano raport z motywem: $($report.Name)" -ForegroundColor Green
}

# Kopiuj Panel Zarządzania Motywami
$themeManager = Join-Path $source "THEMES_MANAGER.html"
if (Test-Path $themeManager) {
    Copy-Item -Path $themeManager -Destination (Join-Path $dest "THEMES_MANAGER.html") -Force
    Write-Host "[SYNC] ✅ Zsynchronizowano Panel Zarządzania Motywami" -ForegroundColor Green
}

Write-Host "[SYNC] ✅ Synchronizacja z Grażyną zakończona!" -ForegroundColor Green
