# Zapisz skrypt TUNERPRO do pliku
$scriptPath = "E:\Grazyna_5.0\TUNERPRO.ps1"
$scriptContent = @'
# =============================================================================
# 🚀 TUNERPRO v2.0.0-PRO-MAX – PEŁNA KOMENDA (ZOPTYMALIZOWANA)
# =============================================================================
# Opis: Pełna analiza, naprawa, synchronizacja i scalanie systemu GRAŻYNA 5.0.
# Wymagania: PowerShell 7+ (u Ciebie: 7.6.2 ✅)
# Użycie: WKLEJ TO DO POWERSHELL 7+ (jako administrator) i naciśnij ENTER.
# Autor: TUNERPRO (Mistral AI) | Dla: Bartosz Jeźewski | Data: 03.06.2026
# =============================================================================

# --- 0. KONFIGURACJA GŁÓWNA ---
$Root = "E:\Grazyna_5.0"
$GrazynaArchive = "E:\GRAZYNA_ARCHIVE"
$OneDrivePath = "D:\OneDrive\GRAZYNA"
$LogPath = "$Root\reports\TUNERPRO_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Funkcja logowania (z obsługą przerwań)
function Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level) {
        "ERROR" { 'Red' }
        "WARN"  { 'Yellow' }
        "SUCCESS" { 'Green' }
        "TUNERPRO" { 'Cyan' }
        default { 'White' }
    })
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
}

# Obsługa przerwania (Ctrl+C)
$script:interrupted = $false
$action = {
    $script:interrupted = $true
    Log "❌ Skrypt przerwany przez użytkownika (Ctrl+C)" "ERROR"
    exit
}
Register-EngineEvent -SourceIdentifier "Interrupt" -Action $action
$null = Register-ObjectEvent -InputObject ([System.Console]::CancelKeyPress) -Action $action

try {
    Log "🚀 TUNERPRO v2.0.0-PRO-MAX – START" "TUNERPRO"

    # --- 1. SPRAWDZENIE ŚRODOWISKA ---
    Log "🔍 Sprawdzanie środowiska..." "TUNERPRO"
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Log "❌ PowerShell 7+ wymagany! Obecna wersja: $($PSVersionTable.PSVersion)" "ERROR"
        throw "Zainstaluj PowerShell 7+: `winget install Microsoft.PowerShell`"
    }
    Log "✅ PowerShell $($PSVersionTable.PSVersion) – OK" "SUCCESS"

    $paths = @($Root, $GrazynaArchive, $OneDrivePath)
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) {
            New-Item -ItemType Directory -Path $p -Force | Out-Null
            Log "✅ Utworzono: $p" "SUCCESS"
        } else {
            Log "✅ Ścieżka OK: $p" "SUCCESS"
        }
    }

    # --- 2. DEFINICJA STRUKTURY (Pełna lista) ---
    Log "📋 Ładowanie definicji struktur TUNERPRO..." "TUNERPRO"
    $ExpectedStructure = @(
        @{ Path = "docs\analysis\GRAZYNA_ANALIZA_RAPORT.md"; Type = "file"; ContentKeywords = @("Root Cause Analysis", "CrashMonitor", "PM2") },
        @{ Path = "docs\deployment\GRAZYNA_HETZNER_READY.md"; Type = "file"; ContentKeywords = @("Hetzner", "redis.conf", "Nginx Config") },
        @{ Path = "infra\ecosystem.config.js"; Type = "file"; ContentKeywords = @("pm2", "instances") },
        @{ Path = "scripts\SYNC_WITH_GRAZYNA.ps1"; Type = "file" },
        @{ Path = "scripts\GRAZYNA_MONITORING_SERVICE.ps1"; Type = "file" },
        @{ Path = "config\GRAZYNA_CONFIG.json"; Type = "file" }
    )

    # --- 3. ANALIZA STRUKTURY ---
    Log "🔍 Analiza struktury..." "TUNERPRO"
    $CurrentStructure = @()
    $AllFiles = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue
    foreach ($file in $AllFiles) {
        if ($script:interrupted) { throw "Skrypt przerwany" }
        $relativePath = $file.FullName.Substring($Root.Length).TrimStart('\')
        $CurrentStructure += @{ Path = $relativePath; FullPath = $file.FullName; Size = $file.Length; LastModified = $file.LastWriteTime }
    }

    $AnalysisResults = @()
    foreach ($expected in $ExpectedStructure) {
        if ($script:interrupted) { throw "Skrypt przerwany" }
        $found = $CurrentStructure | Where-Object { $_.Path -eq $expected.Path }
        if ($found) {
            $AnalysisResults += @{ Path = $expected.Path; Status = "OK"; FullPath = $found.FullPath; Action = "NONE" }
        } else {
            $AnalysisResults += @{ Path = $expected.Path; Status = "MISSING"; FullPath = ""; Action = "CREATE" }
        }
    }
    Log "📊 Analiza struktury: $($AnalysisResults.Count) plików (OK: $(($AnalysisResults | Where-Object { $_.Status -eq "OK" }).Count), MISSING: $(($AnalysisResults | Where-Object { $_.Status -eq "MISSING" }).Count))" "TUNERPRO"

    # --- 4. NAPRAWA STRUKTURY ---
    Log "🔧 Naprawianie struktur..." "TUNERPRO"
    foreach ($item in $AnalysisResults | Where-Object { $_.Status -eq "MISSING" }) {
        if ($script:interrupted) { throw "Skrypt przerwany" }
        $fullPath = "$Root\$($item.Path)"
        $dir = [System.IO.Path]::GetDirectoryName($fullPath)
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null; Log "✅ Utworzono katalog: $dir" "SUCCESS" }
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType File -Path $fullPath -Force | Out-Null
            Log "✅ Utworzono plik: $fullPath" "SUCCESS"
            $fileName = [System.IO.Path]::GetFileName($item.Path)
            switch ($fileName) {
                "ecosystem.config.js" {
                    $content = @'
module.exports = {
  apps: [{
    name: "GRAZYNA_BACKEND",
    script: "./backend/src/system/GRAZYNA_BACKEND_FIX.ts",
    instances: "max",
    exec_mode: "cluster"
  }]
};
'@
                    $content | Out-File -FilePath $fullPath -Encoding UTF8
                    Log "✅ Uzupełniono zawartość: $fileName" "SUCCESS"
                }
                "GRAZYNA_CONFIG.json" {
                    $content = @'
{
  "GRAZYNA_ROOT": "E:\\Grazyna_5.0",
  "GRAZYNA_ARCHIVE": "E:\\GRAZYNA_ARCHIVE",
  "ONEDRIVE_PATH": "D:\\OneDrive\\GRAZYNA"
}
'@
                    $content | Out-File -FilePath $fullPath -Encoding UTF8
                    Log "✅ Uzupełniono zawartość: $fileName" "SUCCESS"
                }
            }
        }
    }

    # --- 5. SYNCHRONIZACJA Z GRAŻYNĄ ---
    Log "🔄 Synchronizacja z Grażyną..." "TUNERPRO"
    if (-not (Test-Path $OneDrivePath)) { New-Item -ItemType Directory -Path $OneDrivePath -Force | Out-Null; Log "✅ Utworzono katalog: $OneDrivePath" "SUCCESS" }
    $syncCount = 0
    $allFiles = Get-ChildItem -Path $Root -Recurse -File | Where-Object { $path = $_.FullName.Substring($Root.Length); -not ($path -match "\\node_modules\\|\\.git\\|\\temp\\|\\logs\\") }
    $totalFiles = $allFiles.Count
    Log "📦 Znaleziono $totalFiles plików do synchronizacji..." "TUNERPRO"
    $i = 0
    foreach ($file in $allFiles) {
        if ($script:interrupted) { throw "Skrypt przerwany" }
        $i++
        $relativePath = $file.FullName.Substring($Root.Length).TrimStart('\')
        $destPath = "$OneDrivePath\$relativePath"
        $destDir = [System.IO.Path]::GetDirectoryName($destPath)
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -Path $file.FullName -Destination $destPath -Force -ErrorAction SilentlyContinue
        $syncCount++
        if ($i % 10 -eq 0) { Log "📤 Synchronizacja: $i/$totalFiles plików..." "TUNERPRO" }
    }
    Log "✅ Zsynchronizowano $syncCount plików z Grażyną." "SUCCESS"

    # --- 6. GENEROWANIE RAPORTU ---
    Log "📊 Generowanie raportu..." "TUNERPRO"
    try {
        $reportPath = "$Root\reports\TUNERPRO_REPORT_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
        $reportContent = @"
<!DOCTYPE html>
<html lang="pl">
<head><meta charset="UTF-8"><title>TUNERPRO – Raport</title>
<style>body{font-family:Arial;margin:20px;background:#f5f7fa;color:#333}header{background:#2c3e50;color:white;padding:20px;text-align:center}table{width:100%;border-collapse:collapse}th,td{padding:10px;border:1px solid #ddd}th{background:#2c3e50;color:white}.status-ok{color:#2ecc71;font-weight:bold}.status-missing{color:#e74c3c;font-weight:bold}</style>
</head>
<body>
<header><h1>🚀 TUNERPRO Raport</h1><p>Wygenerowano: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p></header>
<div><h2>📊 Podsumowanie</h2><p>Pliki OK: <strong>$(($AnalysisResults | Where-Object { $_.Status -eq "OK" }).Count)</strong></p><p>Pliki brakujące: <strong>$(($AnalysisResults | Where-Object { $_.Status -eq "MISSING" }).Count)</strong></p><p>Pliki zsynchronizowane: <strong>$syncCount</strong></p></div>
<div><h2>📁 Wyniki</h2><table><tr><th>Plik</th><th>Status</th><th>Lokalizacja</th><th>Akcja</th></tr><tbody>
"@
        foreach ($result in $AnalysisResults) {
            $statusClass = if ($result.Status -eq "OK") { "status-ok" } else { "status-missing" }
            $reportContent += @"
<tr><td>$($result.Path)</td><td><span class="$statusClass">$($result.Status)</span></td><td>$($result.FullPath)</td><td>$($result.Action)</td></tr>
"@
        }
        $reportContent += @"
</tbody></table></div>
<footer><p>📌 TUNERPRO v2.0.0-PRO-MAX</p></footer>
</body></html>
"@
        $reportContent | Out-File -FilePath $reportPath -Encoding UTF8
        Log "✅ Wygenerowano raport: $reportPath" "SUCCESS"
        try { Invoke-Item $reportPath -ErrorAction Stop; Log "🌐 Otworzono raport." "SUCCESS" } catch { Log "⚠️  Raport: $reportPath" "WARN" }
    } catch { Log "❌ Błąd raportu: $($_.Exception.Message)" "ERROR" }

    Log "✅ TUNERPRO – PROCES ZAKOŃCZONY!" "TUNERPRO"
} catch { Log "❌ Błąd: $($_.Exception.Message)" "ERROR" } finally { Unregister-Event -SourceIdentifier "Interrupt" -ErrorAction SilentlyContinue }
'@

$scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8
Write-Host "[INSTALLER] ✅ Zapisanio skrypt TUNERPRO: $scriptPath" -ForegroundColor Green