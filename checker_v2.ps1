<#
.SYNOPSIS
    Zaawansowany system walidacji, naprawy i monitorowania struktury projektu Grażyna 5.0.
    Obsługuje:
    - Walidację kanoniczną plików/ścieżek
    - Automatyczne naprawianie struktur
    - Generowanie raportów (JSON/CSV/HTML)
    - Integrację z Grażyną, OneDrive, WicioGarage
    - Obsługę plików binarnych/EXE
    - Monitorowanie wydajności
    - Samonaprawę błędów
    - Obsługę poleceń głosowych

.DESCRIPTION
    Skrypt analizuje strukturę projektu pod kątem:
    1. Plików kanonicznych i ich aliasów
    2. Ścieżek osadzonych w kodzie
    3. Działań operacyjnych (start backend/frontend, health check, etc.)
    4. Integracji z zewnętrznymi systemami (Grażyna, OneDrive)
    5. Bezpieczeństwa i wydajności

.PARAMETER Root
    Ścieżka do korzenia projektu (domyślnie: E:\Grazyna_5.0).

.PARAMETER OpenReportFolder
    Otwiera folder z raportami po zakończeniu.

.PARAMETER FixIssues
    Automatycznie naprawia wykryte błędy (przenosi pliki, tworzy katalogi, etc.).

.PARAMETER GenerateHtmlReport
    Generuje interaktywny raport HTML.

.PARAMETER SyncWithOneDrive
    Synchronizuje krytyczne pliki z OneDrive.

.PARAMETER VoiceControl
    Włącza obsługę poleceń głosowych.

.EXAMPLE
    .\GRAZYNA_STRUCTURE_CHECKER.ps1 -Root "E:\Grazyna_5.0" -FixIssues -GenerateHtmlReport -SyncWithOneDrive

.NOTES
    Wymagania:
    - PowerShell 7+
    - Moduły: Posh-Git, ImportExcel (opcjonalnie)
    - Uprawnienia: Administrator (dla operacji systemowych)
#>

param(
    [string]$Root = "E:\Grazyna_5.0",
    [switch]$OpenReportFolder,
    [switch]$FixIssues,
    [switch]$GenerateHtmlReport,
    [switch]$SyncWithOneDrive,
    [switch]$VoiceControl,
    [switch]$SelfHeal
)

#region --- KONFIGURACJA GLOBALNA ---
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'Continue'

# Ścieżki systemowe
$GRAZYNA_ROOT = if (Test-Path "D:\OneDrive\GRAZYNA") { "D:\OneDrive\GRAZYNA" } else { $Root }
$GRAZYNA_ARCHIVE = "E:\GRAZYNA_ARCHIVE"
$WICIOGARAGE_PATH = "C:\WicioGarage"
$LECHAT_INTEGRATION = "C:\LeChat\integration"

# Wykluczone katalogi (regex)
$ExcludeRegex = '\\node_modules\\|\\dist\\|\\.git\\|\\__pycache__\\|\\coverage\\|\\tmp\\|\\temp\\|\\logs\\|\\.vscode\\|\\.idea\\|\\build\\|\\cache\\'

# Sygnatury plików binarnych/EXE (do weryfikacji)
$BinarySignatures = @{
    'GRAZYNA_CORE.EXE' = @{ MD5 = 'ABC123...'; SHA256 = 'DEF456...'; Version = '5.0.1' }
    'TUNER_PRO.EXE'    = @{ MD5 = 'XYZ789...'; SHA256 = 'UVW012...'; Version = '2.3.0' }
}

# Konfiguracja raportów
$ReportDir = Join-Path $Root 'reports'
$BackupDir = Join-Path $GRAZYNA_ARCHIVE 'backups'
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

# Kolory konsoli
function C([string]$Color, [string]$Message) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}

# Logowanie (do pliku i konsoli)
function Log([string]$Message, [string]$Level = "INFO") {
    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level) {
        "ERROR" { 'Red' }
        "WARN"  { 'Yellow' }
        "SUCCESS" { 'Green' }
        default { 'White' }
    })
    Add-Content -Path (Join-Path $ReportDir "${ScriptName}_${Timestamp}.log") -Value $logEntry
}

# Pomiar wydajności
$PerformanceMetrics = @{
    StartTime = Get-Date
    MemoryBefore = (Get-Process -Id $PID).WorkingSet64
    Operations = 0
}
function Start-Measure { $PerformanceMetrics.StartTime = Get-Date }
function Stop-Measure {
    $PerformanceMetrics.EndTime = Get-Date
    $PerformanceMetrics.Duration = ($PerformanceMetrics.EndTime - $PerformanceMetrics.StartTime).TotalSeconds
    $PerformanceMetrics.MemoryAfter = (Get-Process -Id $PID).WorkingSet64
    $PerformanceMetrics.MemoryDelta = ($PerformanceMetrics.MemoryAfter - $PerformanceMetrics.MemoryBefore) / 1MB
    Log "Czas wykonania: $($PerformanceMetrics.Duration) s | Pamięć: +$($PerformanceMetrics.MemoryDelta) MB"
}

# Obsługa błędów krytycznych
function Throw-Critical([string]$Message, [string]$Solution = "") {
    $errorMsg = @"
=== BŁĄD KRYTYCZNY ===
$Message

$(if ($Solution) { "SUGESTIA NAPRAWY: $Solution" })
"@
    Log $errorMsg "ERROR"
    if ($SelfHeal -and $Solution) {
        C Yellow "Próba samonaprawy..."
        Invoke-Expression $Solution | Out-Null
    }
    else {
        throw $Message
    }
}
#endregion

#region --- FUNKCJE POMOCNICZE ---
### Rozwiązywanie ścieżek (kanonicznych/aliasów/treści)
function Resolve-Candidate {
    param(
        [string]$root,
        [string]$relativeOrName,
        [switch]$CreateIfMissing = $false
    )

    $p = Join-Path $root $relativeOrName
    if (Test-Path -LiteralPath $p) {
        return (Resolve-Path -LiteralPath $p).Path
    }

    $nameOnly = [System.IO.Path]::GetFileName($relativeOrName)
    $found = Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch $ExcludeRegex -and
            $_.Name -ieq $nameOnly
        } |
        Sort-Object FullName |
        Select-Object -First 1

    if ($found) {
        return $found.FullName
    }

    if ($CreateIfMissing) {
        $newPath = Join-Path $root $relativeOrName
        $dir = [System.IO.Path]::GetDirectoryName($newPath)
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Log "Utworzono katalog: $dir" "SUCCESS"
        }
        New-Item -ItemType File -Path $newPath -Force | Out-Null
        Log "Utworzono plik: $newPath" "SUCCESS"
        return $newPath
    }

    return $null
}

### Wyszukiwanie po treści (z zaawansowaną analizą sygnatur)
function Get-ContentMatch {
    param(
        [string]$root,
        [string[]]$hints,
        [int]$threshold = 2
    )

    $threshold = [Math]::Max($threshold, [Math]::Floor($hints.Count / 2))
    $matches = @()
    $files = Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch $ExcludeRegex -and
            $_.Extension -in '.md', '.ps1', '.ts', '.js', '.yml', '.yaml', '.txt', '.json', '.config'
        }

    foreach ($file in $files) {
        try {
            $raw = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
            $hits = 0
            foreach ($h in $hints) {
                if ($raw -match [regex]::Escape($h)) {
                    $hits++
                }
            }
            if ($hits -ge $threshold) {
                $matches += [pscustomobject]@{
                    Path  = $file.FullName
                    Score = $hits
                    Size  = (Get-Item $file.FullName).Length
                    LastModified = (Get-Item $file.FullName).LastWriteTime
                }
            }
        } catch {
            Log "Błąd odczytu pliku: $($file.FullName) - $($_.Exception.Message)" "WARN"
        }
    }

    return ($matches | Sort-Object Score -Descending, Path | Select-Object -First 1)
}

### Walidacja plików binarnych/EXE
function Test-BinaryFile {
    param(
        [string]$Path,
        [hashtable]$ExpectedSignatures
    )

    if (-not (Test-Path $Path)) {
        return $false
    }

    try {
        $fileHash = Get-FileHash -Path $Path -Algorithm MD5, SHA256
        $fileVersion = (Get-Item $Path).VersionInfo.FileVersion

        $md5Match = $fileHash.Hash -eq $ExpectedSignatures.MD5
        $sha256Match = $fileHash.Hash -eq $ExpectedSignatures.SHA256
        $versionMatch = $fileVersion -eq $ExpectedSignatures.Version

        return @{
            Valid = ($md5Match -and $sha256Match -and $versionMatch)
            MD5Match = $md5Match
            SHA256Match = $sha256Match
            VersionMatch = $versionMatch
            ActualMD5 = $fileHash.Hash
            ActualSHA256 = $fileHash.Hash
            ActualVersion = $fileVersion
        }
    } catch {
        Log "Błąd walidacji pliku binarnego: $Path - $($_.Exception.Message)" "WARN"
        return @{ Valid = $false }
    }
}

### Synchronizacja z OneDrive
function Sync-WithOneDrive {
    param(
        [string]$SourcePath,
        [string]$DestinationPath = $GRAZYNA_ARCHIVE
    )

    if (-not (Test-Path $SourcePath)) {
        Throw-Critical "Ścieżka źródłowa nie istnieje: $SourcePath"
    }

    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }

    $filesToSync = Get-ChildItem -Path $SourcePath -Recurse -File |
        Where-Object { $_.FullName -notmatch $ExcludeRegex }

    foreach ($file in $filesToSync) {
        $relativePath = $file.FullName.Substring($SourcePath.Length).TrimStart('\')
        $destFile = Join-Path $DestinationPath $relativePath

        if (-not (Test-Path (Split-Path $destFile -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path $destFile -Parent) -Force | Out-Null
        }

        if (Test-Path $destFile) {
            $sourceHash = (Get-FileHash -Path $file.FullName -Algorithm MD5).Hash
            $destHash = (Get-FileHash -Path $destFile -Algorithm MD5).Hash
            if ($sourceHash -ne $destHash) {
                Copy-Item -Path $file.FullName -Destination $destFile -Force
                Log "Zsynchronizowano (zastąpiono): $relativePath" "SUCCESS"
            }
        } else {
            Copy-Item -Path $file.FullName -Destination $destFile -Force
            Log "Skopiowano: $relativePath" "SUCCESS"
        }
    }
}

### Generowanie raportu HTML
function Generate-HtmlReport {
    param(
        [object[]]$ValidationResults,
        [object[]]$PathValidation,
        [object[]]$ActionFiles,
        [string]$OutputPath
    )

    $html = @"
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Raport Walidacji Grażyna 5.0</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        h1 { color: #2c3e50; text-align: center; }
        h2 { color: #3498db; border-bottom: 2px solid #eee; padding-bottom: 5px; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; background: white; }
        th, td { padding: 10px; text-align: left; border: 1px solid #ddd; }
        th { background-color: #3498db; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .status-ok { background-color: #d4edda; }
        .status-missing { background-color: #f8d7da; }
        .status-alias { background-color: #fff3cd; }
        .status-integrated { background-color: #d1ecf1; }
        .status-broken { background-color: #f8d7da; }
        .summary { background: white; padding: 15px; border-radius: 5px; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .action-btn { padding: 8px 12px; background: #3498db; color: white; border: none; border-radius: 4px; cursor: pointer; }
        .action-btn:hover { background: #2980b9; }
        .file-link { color: #3498db; text-decoration: none; }
        .file-link:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <h1>🔍 Raport Walidacji Struktury Grażyna 5.0</h1>
    <p style="text-align: center; color: #7f8c8d;">Wygenerowano: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>

    <div class="summary">
        <h2>📊 Podsumowanie</h2>
        <p><strong>Pliki kanoniczne:</strong> $($ValidationResults.Count) (OK: $(($ValidationResults | Where-Object { $_.Status -eq 'OK' }).Count), Brak: $(($ValidationResults | Where-Object { $_.Status -eq 'MISSING' }).Count))</p>
        <p><strong>Ścieżki osadzone:</strong> $($PathValidation.Count) (Nieistniejące: $(($PathValidation | Where-Object { -not $_.Exists }).Count))</p>
        <p><strong>Działania operacyjne:</strong> $($ActionFiles.Count) (Unikalne: $(($ActionFiles | Group-Object Action).Count))</p>
    </div>

    <h2>📁 Walidacja Plików Kanonicznych</h2>
    <table>
        <tr>
            <th>Plik Kanoniczny</th>
            <th>Status</th>
            <th>Rozwiązano jako</th>
            <th>Podstawa</th>
            <th>Notatka</th>
        </tr>
"@

    foreach ($row in $ValidationResults) {
        $statusClass = switch ($row.Status) {
            'OK' { 'status-ok' }
            'MISSING' { 'status-missing' }
            'ALIAS' { 'status-alias' }
            'INTEGRATED' { 'status-integrated' }
            default { '' }
        }
        $resolvedLink = if ($row.Resolved -and (Test-Path $row.Resolved)) {
            "<a href='file:///$($row.Resolved.Replace('\', '/'))' class='file-link' target='_blank'>$($row.Resolved)</a>"
        } else { $row.Resolved }

        $html += @"
        <tr class="$statusClass">
            <td>$($row.Item)</td>
            <td><strong>$($row.Status)</strong></td>
            <td>$resolvedLink</td>
            <td>$($row.Basis)</td>
            <td>$($row.Note)</td>
        </tr>
"@
    }

    $html += @"
    </table>

    <h2>🔗 Weryfikacja Ścieżek Osadzonych</h2>
    <table>
        <tr>
            <th>Plik Źródłowy</th>
            <th>Ścieżka Referencyjna</th>
            <th>Rozwiązano jako</th>
            <th>Status</th>
        </tr>
"@

    foreach ($path in $PathValidation | Where-Object { -not $_.Exists }) {
        $html += @"
        <tr class="status-broken">
            <td><a href='file:///$($path.SourceFile.Replace('\', '/'))' class='file-link' target='_blank'>$($path.SourceFile.Substring($Root.Length))</a></td>
            <td>$($path.ReferencedPath)</td>
            <td>$($path.ResolvedPath)</td>
            <td>❌ Nie istnieje</td>
        </tr>
"@
    }

    $html += @"
    </table>

    <h2>⚡ Działania Operacyjne</h2>
    <table>
        <tr>
            <th>Akcja</th>
            <th>Liczba Plików</th>
            <th>Pliki</th>
        </tr>
"@

    $groupedActions = $ActionFiles | Group-Object Action | Sort-Object Name
    foreach ($group in $groupedActions) {
        $filesList = ($group.Group | ForEach-Object { $_.File.Substring($Root.Length) }) -join ", "
        $html += @"
        <tr>
            <td>$($group.Name)</td>
            <td>$($group.Count)</td>
            <td>$filesList</td>
        </tr>
"@
    }

    $html += @"
    </table>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Log "Wygenerowano raport HTML: $OutputPath" "SUCCESS"
}

### Obsługa poleceń głosowych (eksperymentalna)
function Start-VoiceControl {
    Add-Type -AssemblyName System.Speech
    $recognizer = New-Object System.Speech.Recognition.SpeechRecognitionEngine
    $grammar = New-Object System.Speech.Recognition.DictationGrammar
    $recognizer.LoadGrammar($grammar)

    $recognizer.SetInputToDefaultAudioDevice()

    Register-ObjectEvent -InputObject $recognizer -EventName "SpeechRecognized" -Action {
        $text = $_.Result.Text
        Log "Polecenie głosowe: '$text'" "INFO"

        # Proste mapowanie poleceń
        switch -Wildcard ($text) {
            "*sprawdź strukturę*" { & $MyInvocation.MyCommand.Path -Root $Root }
            "*napraw błędy*"    { & $MyInvocation.MyCommand.Path -Root $Root -FixIssues }
            "*raport html*"     { & $MyInvocation.MyCommand.Path -Root $Root -GenerateHtmlReport }
            "*zamknij*"         { Stop-Process -Id $PID }
            default {
                C Yellow "Nieznane polecenie: '$text'. Dostępne: 'sprawdź strukturę', 'napraw błędy', 'raport html', 'zamknij'."
            }
        }
    }

    $recognizer.StartAsync()
    C Green "Obsługa poleceń głosowych aktywna. Mów teraz..."
}
#endregion

#region --- GŁÓWNA LOGIKA SKRYPTU ---
Start-Measure
Log "=== ROZPOCZĘTO WALIDACJĘ STRUKTURY GRAŻYNA 5.0 ==="

# 1. Inicjalizacja katalogów
if (-not (Test-Path $Root)) {
    Throw-Critical "Katalog repo nie istnieje: $Root" "New-Item -ItemType Directory -Path $Root -Force"
}
if (-not (Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
    Log "Utworzono katalog raportów: $ReportDir" "SUCCESS"
}
if ($SyncWithOneDrive -and -not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Log "Utworzono katalog backupów: $BackupDir" "SUCCESS"
}

# 2. Definicja oczekiwanych plików (rozszerzona)
$Expected = @(
    # Dokumentacja
    @{ Canonical='docs\analysis\GRAZYNA_ANALIZA_RAPORT.md';           Aliases=@('GRAZYNA_INTEGRATION_REPORT.txt', 'docs\reports\crash_analysis.md');       Hints=@('Root Cause Analysis','CrashMonitor','PM2','EADDRINUSE','Plan Migracji do Produkcji','EL Lag','OOM') },
    @{ Canonical='docs\deployment\GRAZYNA_HETZNER_READY.md';          Aliases=@('GRAZYNA_REDIS_ML_CLUSTER_ANALYSIS.md', 'docs\cloud\hetzner_setup.md'); Hints=@('Hetzner','redis.conf','IsoForest','EWMA','Nginx Config','Docker Swarm') },
    @{ Canonical='docs\architecture\GRAZYNA_DB_ANALYSIS.md';          Aliases=@('docs\database\schema_analysis.md'); Hints=@('schema.prisma','postgresql','SQLite','DATABASE_URL','Prisma','Migration') },
    @{ Canonical='docs\architecture\GRAZYNA_AUTH_JWT_VS_SESSIONS.md'; Aliases=@('docs\security\auth_comparison.md'); Hints=@('JWT','Refresh Token','session','SameSite','Cookie','OAuth2') },
    @{ Canonical='docs\architecture\GRAZYNA_ML_VS_REGRESSION.md';     Aliases=@('docs\ai\anomaly_detection.md'); Hints=@('EWMA','IsoForest','Z-Score','Regresja','TTT','Time To Failure') },
    @{ Canonical='docs\architecture\GRAZYNA_EXPRESS_VS_FASTIFY.md';   Aliases=@('docs\backend\framework_comparison.md'); Hints=@('Express','Fastify','express-server.ts','fastify-server.ts','Middleware','Router') },
    @{ Canonical='docs\architecture\GRAZYNA_FASTIFY_MIGRATION.md';    Aliases=@('docs\backend\migration_guide.md'); Hints=@('Fastify','migration','express-server.ts','fastify-server.ts','Plugin','Decorator') },

    # Backend
    @{ Canonical='backend\src\system\GRAZYNA_BACKEND_FIX.ts';         Aliases=@('backend\GRAZYNA_BACKEND_FIX.ts', 'src\server\express-server.ts'); Hints=@('listen(','/health','express','cluster','Worker Threads') },
    @{ Canonical='backend\src\services\GRAZYNA_WORKER_THREADS.ts';    Aliases=@('tasks.worker.cjs', 'src\workers\task-manager.ts'); Hints=@('worker_threads','Worker','parentPort','task','ThreadPool') },
    @{ Canonical='backend\src\utils\GRAZYNA_LARGE_OBJECT_DIAG.ts';    Aliases=@('backend\src\utils\heap.ts','backend\src\el-optimization.ts'); Hints=@('heap','gc','memoryUsage','large object','Garbage Collector','Memory Leak') },

    # Skrypty monitorujące
    @{ Canonical='scripts\monitoring\GRAZYNA_OOM_PREDICTOR.ps1';      Aliases=@('scripts\predict-oom.ps1'); Hints=@('OOM','heap','RSS','EL Lag','Memory Usage','Predictor') },
    @{ Canonical='scripts\monitoring\GRAZYNA_PREDICT_MONITOR.ps1';    Aliases=@('scripts\ewma-monitor.ps1'); Hints=@('Predict','EWMA','IsoForest','TTT','Anomaly Detection') },
    @{ Canonical='scripts\monitoring\watchdog-ai.ps1';                Aliases=@('backend\watchdog-ai.ps1', 'scripts\health-monitor.ps1'); Hints=@('watchdog','restart','health','Crash Recovery','Auto-Heal') },

    # Infra
    @{ Canonical='infra\docker-compose.prod.yml';                     Aliases=@('docker-compose.prod.yml', 'infra\docker\prod.yml'); Hints=@('services:','backend:','frontend:','redis:','volumes:','networks:') },
    @{ Canonical='infra\ecosystem.config.js';                         Aliases=@('backend\ecosystem.config.js', 'infra\pm2\config.js'); Hints=@('pm2','instances','exec_mode','max_memory_restart','watch') },
    @{ Canonical='.github\workflows\deploy-prod.yml';                 Aliases=@('.github\workflows\ci-cd.yml', '.github\workflows\deploy.yml'); Hints=@('actions/checkout','Deploy','docker-compose','Hetzner','Secrets') },

    # Nowe: Pliki binarne/EXE
    @{ Canonical='bin\GRAZYNA_CORE.EXE';                             Aliases=@('dist\GRAZYNA_CORE.EXE', 'release\GRAZYNA_CORE.EXE'); Hints=@('Main Executable','Core Engine','Version 5.0') },
    @{ Canonical='bin\TUNER_PRO.EXE';                                Aliases=@('dist\TUNER_PRO.EXE'); Hints=@('Tuning Tool','ECU Flasher','Diagnostic') },

    # Nowe: Konfiguracja Grażyny
    @{ Canonical='config\GRAZYNA_CONFIG.json';                      Aliases=@('config\settings.json', 'grażyna_config.json'); Hints=@('GRAZYNA_ROOT','WICIOGARAGE_PATH','LECHAT_INTEGRATION','BackupSettings') }
)

# 3. Walidacja struktury kanonicznej
$ValidationResults = [System.Collections.Generic.List[Object]]::new()
foreach ($item in $Expected) {
    $canonicalAbs = Join-Path $Root $item.Canonical

    if (Test-Path -LiteralPath $canonicalAbs) {
        $ValidationResults.Add([pscustomobject]@{
            Item     = $item.Canonical
            Status   = 'OK'
            Resolved = $canonicalAbs
            Basis    = 'canonical'
            Note     = 'Plik w prawidłowej lokalizacji'
        })
        continue
    }

    # Sprawdź aliasy
    $resolvedAlias = $null
    foreach ($a in $item.Aliases) {
        $resolvedAlias = Resolve-Candidate -root $Root -relativeOrName $a
        if ($resolvedAlias) { break }
    }

    if ($resolvedAlias) {
        $ValidationResults.Add([pscustomobject]@{
            Item     = $item.Canonical
            Status   = 'ALIAS'
            Resolved = $resolvedAlias
            Basis    = 'alias'
            Note     = 'Znaleziono równoważnik pod inną nazwą/lokalizacją'
        })
        continue
    }

    # Sprawdź po treści
    $contentMatch = Get-ContentMatch -root $Root -hints $item.Hints
    if ($contentMatch) {
        $ValidationResults.Add([pscustomobject]@{
            Item     = $item.Canonical
            Status   = 'INTEGRATED'
            Resolved = $contentMatch.Path
            Basis    = 'content'
            Note     = "Treść zintegrowana / dopasowanie po zawartości (score=$($contentMatch.Score))"
        })
    }
    else {
        $ValidationResults.Add([pscustomobject]@{
            Item     = $item.Canonical
            Status   = 'MISSING'
            Resolved = ''
            Basis    = 'none'
            Note     = 'Brak po nazwie, aliasie i treści'
        })
    }
}

# 4. Automatyczne naprawianie (jeśli -FixIssues)
if ($FixIssues) {
    C Yellow "🔧 Rozpoczynam automatyczną naprawę struktur..."

    foreach ($row in $ValidationResults | Where-Object { $_.Status -eq 'MISSING' }) {
        $targetPath = Join-Path $Root $row.Item
        $targetDir = [System.IO.Path]::GetDirectoryName($targetPath)

        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            Log "Utworzono katalog: $targetDir" "SUCCESS"
        }

        # Próba znalezienia pliku po treści i przeniesienia
        $contentMatch = Get-ContentMatch -root $Root -hints $Expected.Where({ $_.Canonical -eq $row.Item }).Hints
        if ($contentMatch) {
            $sourceFile = $contentMatch.Path
            if ($sourceFile -ne $targetPath) {
                Move-Item -Path $sourceFile -Destination $targetPath -Force -ErrorAction SilentlyContinue
                Log "Przeniesiono: $sourceFile → $targetPath" "SUCCESS"
                $row.Resolved = $targetPath
                $row.Status = 'FIXED'
                $row.Basis = 'auto-fixed'
                $row.Note = 'Automatycznie przeniesiono z innej lokalizacji'
            }
        } else {
            # Utwórz pusty plik (jeśli nie znaleziono treści)
            New-Item -ItemType File -Path $targetPath -Force | Out-Null
            Log "Utworzono pusty plik: $targetPath (brakujące dane)" "WARN"
            $row.Resolved = $targetPath
            $row.Status = 'CREATED'
            $row.Basis = 'auto-created'
            $row.Note = 'Utworzony pusty plik (brakujące dane)'
        }
    }

    # Walidacja plików binarnych
    foreach ($binary in $BinarySignatures.Keys) {
        $binaryPath = Join-Path $Root $binary
        if (Test-Path $binaryPath) {
            $validation = Test-BinaryFile -Path $binaryPath -ExpectedSignatures $BinarySignatures[$binary]
            if (-not $validation.Valid) {
                Log "Plik binarny nieprawidłowy: $binary - MD5: $($validation.MD5Match), SHA256: $($validation.SHA256Match), Wersja: $($validation.VersionMatch)" "WARN"
                if ($SelfHeal) {
                    # Próba pobrania poprawnej wersji z archiwum
                    $archiveBinary = Join-Path $GRAZYNA_ARCHIVE $binary
                    if (Test-Path $archiveBinary) {
                        Copy-Item -Path $archiveBinary -Destination $binaryPath -Force
                        Log "Naprawiono plik binarny z archiwum: $binary" "SUCCESS"
                    }
                }
            }
        } else {
            Log "Brak pliku binarnego: $binary" "WARN"
        }
    }
}

# 5. Analiza ścieżek osadzonych w plikach
$PatternPathA = '(?<path>[A-Za-z]:\\[^\r\n"''`]+)'  # Ścieżki bezwzględne (C:\...)
$PatternPathB = '(?<path>(backend|frontend|docs|scripts|infra|monitoring|nginx|core|ahe|tools|manifests|\.github|bin|config)[^\s"''`]+)'  # Ścieżki względne

$PathFiles = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch $ExcludeRegex -and
        $_.Extension -in '.md', '.ps1', '.ts', '.js', '.yml', '.yaml', '.txt', '.json', '.config'
    }

$PathValidation = [System.Collections.Generic.List[Object]]::new()
foreach ($f in $PathFiles) {
    try {
        $raw = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
        $matches = @()
        $matches += [regex]::Matches($raw, $PatternPathA)
        $matches += [regex]::Matches($raw, $PatternPathB)

        $seen = @{}
        foreach ($m in $matches) {
            $p = $m.Groups['path'].Value.Trim()
            if (-not $p -or $seen.ContainsKey($p)) { continue }
            $seen[$p] = $true

            $norm = $p
            if ($p -notmatch '^[A-Za-z]:\\') {
                $norm = Join-Path $Root ($p -replace '/', '\')
            }

            $exists = Test-Path -LiteralPath $norm
            $PathValidation.Add([pscustomobject]@{
                SourceFile     = $f.FullName
                ReferencedPath = $p
                ResolvedPath   = $norm
                Exists         = $exists
            })
        }
    } catch {
        Log "Błąd odczytu pliku: $($f.FullName) - $($_.Exception.Message)" "WARN"
    }
}

# 6. Analiza działań operacyjnych
$Actions = @(
    @{ Name='start_backend';  Pattern='express-server\.ts|index\.ts|npm run dev|node .*express-server|fastify-server\.ts' },
    @{ Name='start_frontend'; Pattern='vite|npm run build|npm run dev|frontend|vite\.config' },
    @{ Name='health_check';   Pattern='/health|Invoke-RestMethod .*health|curl .*health|axios.*health' },
    @{ Name='metrics';        Pattern='/metrics|Prometheus|Grafana|statsd|InfluxDB' },
    @{ Name='db_migration';   Pattern='prisma migrate|prisma db push|schema\.prisma|knex migrate' },
    @{ Name='deploy_prod';    Pattern='docker-compose\.prod\.yml|deploy-prod\.yml|Hetzner|Nginx|pm2 start' },
    @{ Name='monitoring';     Pattern='EWMA|IsoForest|OOM|watchdog|CrashMonitor|EL Lag|Memory Leak' },
    @{ Name='tuning';        Pattern='ECU|flashing|tuning|dyno|hamownia|diagnostyka' },
    @{ Name='backup';         Pattern='backup|archive|sync|OneDrive|GRAZYNA_ARCHIVE' }
)

$ActionFiles = [System.Collections.Generic.List[Object]]::new()
foreach ($f in $PathFiles) {
    try {
        $raw = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
        foreach ($a in $Actions) {
            if ($raw -match $a.Pattern) {
                $ActionFiles.Add([pscustomobject]@{
                    Action = $a.Name
                    File   = $f.FullName
                })
            }
        }
    } catch {
        Log "Błąd analizy działań: $($f.FullName) - $($_.Exception.Message)" "WARN"
    }
}

# 7. Generowanie raportów
$jsonReport = Join-Path $ReportDir "${ScriptName}_${Timestamp}.json"
$csvReport = Join-Path $ReportDir "${ScriptName}_${Timestamp}.csv"
$pathsCsv = Join-Path $ReportDir "${ScriptName}_paths_${Timestamp}.csv"
$actionsCsv = Join-Path $ReportDir "${ScriptName}_actions_${Timestamp}.csv"
$htmlReport = Join-Path $ReportDir "${ScriptName}_${Timestamp}.html"

$ValidationResults | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonReport -Encoding UTF8
$ValidationResults | Export-Csv -LiteralPath $csvReport -NoTypeInformation -Encoding UTF8
$PathValidation | Export-Csv -LiteralPath $pathsCsv -NoTypeInformation -Encoding UTF8
$ActionFiles | Sort-Object Action, File | Export-Csv -LiteralPath $actionsCsv -NoTypeInformation -Encoding UTF8

if ($GenerateHtmlReport) {
    Generate-HtmlReport -ValidationResults $ValidationResults -PathValidation $PathValidation -ActionFiles $ActionFiles -OutputPath $htmlReport
}

# 8. Synchronizacja z OneDrive (jeśli -SyncWithOneDrive)
if ($SyncWithOneDrive) {
    C Yellow "🔄 Synchronizacja z OneDrive..."
    Sync-WithOneDrive -SourcePath $Root -DestinationPath $GRAZYNA_ARCHIVE
    Sync-WithOneDrive -SourcePath $ReportDir -DestinationPath (Join-Path $GRAZYNA_ARCHIVE 'reports')
}

# 9. Integracja z Grażyną (automatyczne wysyłanie raportów)
if (Test-Path $GRAZYNA_ROOT) {
    $grazynaReportDir = Join-Path $GRAZYNA_ROOT 'reports'
    if (-not (Test-Path $grazynaReportDir)) {
        New-Item -ItemType Directory -Path $grazynaReportDir -Force | Out-Null
    }
    Copy-Item -Path $jsonReport -Destination (Join-Path $grazynaReportDir "${ScriptName}_${Timestamp}.json") -Force
    Copy-Item -Path $csvReport -Destination (Join-Path $grazynaReportDir "${ScriptName}_${Timestamp}.csv") -Force
    if ($GenerateHtmlReport) {
        Copy-Item -Path $htmlReport -Destination (Join-Path $grazynaReportDir "${ScriptName}_${Timestamp}.html") -Force
    }
    Log "Raporty skopiowane do Grażyny: $grazynaReportDir" "SUCCESS"
}

# 10. Samonaprawa (jeśli -SelfHeal)
if ($SelfHeal) {
    C Yellow "🛠️  Uruchamianie mechanizmu samonaprawy..."

    # Sprawdź uprawnienia
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Log "Uruchom skrypt jako administrator dla pełnej funkcjonalności samonaprawy." "WARN"
    }

    # Naprawa uprawnień plików
    $ValidationResults | Where-Object { $_.Status -in 'FIXED', 'CREATED' } | ForEach-Object {
        if (Test-Path $_.Resolved) {
            $acl = Get-Acl -Path $_.Resolved
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                "Users",
                [System.Security.AccessControl.FileSystemRights]::Modify,
                [System.Security.AccessControl.InheritanceFlags]::None,
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path $_.Resolved -AclObject $acl
            Log "Naprawiono uprawnienia: $($_.Resolved)" "SUCCESS"
        }
    }
}

# 11. Obsługa poleceń głosowych (jeśli -VoiceControl)
if ($VoiceControl) {
    Start-VoiceControl
}

# 12. Wyświetlenie raportów w konsoli
Stop-Measure

C Cyan "=== 🏗️  CHECKER V3 — STRUKTURA KANONICZNA ==="
$ValidationResults | Sort-Object Status, Item | Format-Table -AutoSize

Write-Host ''
C Cyan '=== 🔗 WERYFIKACJA ŚCIEŻEK OSADZONYCH ==='
$brokenPaths = $PathValidation | Where-Object { -not $_.Exists }
if ($brokenPaths) {
    C Yellow ("⚠️  Ścieżki nieistniejące: {0}" -f $brokenPaths.Count)
    $brokenPaths | Select-Object -First 25 | Format-Table -AutoSize
} else {
    C Green '✅ Wszystkie wykryte ścieżki istnieją.'
}

Write-Host ''
C Cyan '=== ⚡ DZIAŁANIA WSPÓLNE / POKRYCIE ==='
$coverage = $ActionFiles |
    Group-Object Action |
    Sort-Object Name |
    ForEach-Object {
        [pscustomobject]@{
            Action = $_.Name
            Files  = $_.Count
        }
    }
$coverage | Format-Table -AutoSize

Write-Host ''
C Cyan '=== 📁 PLIKI BINARNE / EXE ==='
foreach ($binary in $BinarySignatures.Keys) {
    $binaryPath = Join-Path $Root $binary
    if (Test-Path $binaryPath) {
        $validation = Test-BinaryFile -Path $binaryPath -ExpectedSignatures $BinarySignatures[$binary]
        $status = if ($validation.Valid) { "✅ OK" } else { "❌ NIEPOPRAWNY" }
        C $(if ($validation.Valid) { 'Green' } else { 'Red' }) "$binary: $status"
    } else {
        C Red "$binary: ❌ BRAK"
    }
}

Write-Host ''
C Green "📄 Raport JSON: $jsonReport"
C Green "📄 Raport CSV:  $csvReport"
C Green "📄 Ścieżki CSV: $pathsCsv"
C Green "📄 Akcje CSV:   $actionsCsv"
if ($GenerateHtmlReport) {
    C Green "📄 Raport HTML: $htmlReport"
}

if ($OpenReportFolder) {
    Invoke-Item $ReportDir
}

# 13. Podsumowanie
$missingCount = ($ValidationResults | Where-Object { $_.Status -eq 'MISSING' }).Count
$brokenCount = ($PathValidation | Where-Object { -not $_.Exists }).Count
$actionCount = ($ActionFiles | Group-Object Action).Count

Write-Host ''
C Cyan "=== 📌 PODSUMOWANIE ==="
C $(if ($missingCount -eq 0 -and $brokenCount -eq 0) { 'Green' } else { 'Yellow' }) "Pliki kanoniczne: $($ValidationResults.Count) (Brak: $missingCount)"
C $(if ($brokenCount -eq 0) { 'Green' } else { 'Yellow' }) "Ścieżki osadzone: $($PathValidation.Count) (Nieistniejące: $brokenCount)"
C Green "Działania operacyjne: $actionCount unikalnych akcji"
C Green "Czas wykonania: $($PerformanceMetrics.Duration) s | Zużycie pamięci: +$($PerformanceMetrics.MemoryDelta) MB"

if ($missingCount -gt 0 -or $brokenCount -gt 0) {
    C Yellow "⚠️  Wykryto problemy. Uruchom skrypt z parametrem -FixIssues, aby je naprawić."
}

C Green "✅ Zakończono pomyślnie."
#endregion