param(
    [string]$Root = "E:\Grazyna_5.0",
    [switch]$OpenReportFolder
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Root)) {
    throw "Katalog repo nie istnieje: $Root"
}

function C($c, $m) { Write-Host $m -ForegroundColor $c }
$ExcludeRegex = '\\node_modules\\|\\dist\\|\\.git\\|\\__pycache__\\|\\coverage\\|\\tmp\\|\\temp\\|\\logs\\'

$Expected = @(
    @{ Canonical='docs\analysis\GRAZYNA_ANALIZA_RAPORT.md';           Aliases=@('GRAZYNA_INTEGRATION_REPORT.txt');         Hints=@('Root Cause Analysis','CrashMonitor','PM2','EADDRINUSE','Plan Migracji do Produkcji') },
    @{ Canonical='docs\deployment\GRAZYNA_HETZNER_READY.md';          Aliases=@('GRAZYNA_REDIS_ML_CLUSTER_ANALYSIS.md');   Hints=@('Hetzner','redis.conf','IsoForest','EWMA','Nginx Config') },
    @{ Canonical='docs\architecture\GRAZYNA_DB_ANALYSIS.md';          Aliases=@(); Hints=@('schema.prisma','postgresql','SQLite','DATABASE_URL') },
    @{ Canonical='docs\architecture\GRAZYNA_AUTH_JWT_VS_SESSIONS.md'; Aliases=@(); Hints=@('JWT','Refresh Token','session','SameSite') },
    @{ Canonical='docs\architecture\GRAZYNA_ML_VS_REGRESSION.md';     Aliases=@(); Hints=@('EWMA','IsoForest','Z-Score','Regresja','TTT') },
    @{ Canonical='docs\architecture\GRAZYNA_EXPRESS_VS_FASTIFY.md';   Aliases=@(); Hints=@('Express','Fastify','express-server.ts','fastify-server.ts') },
    @{ Canonical='docs\architecture\GRAZYNA_FASTIFY_MIGRATION.md';    Aliases=@(); Hints=@('Fastify','migration','express-server.ts','fastify-server.ts') },
    @{ Canonical='backend\src\system\GRAZYNA_BACKEND_FIX.ts';         Aliases=@('backend\GRAZYNA_BACKEND_FIX.ts'); Hints=@('listen(','/health','express','cluster') },
    @{ Canonical='backend\src\services\GRAZYNA_WORKER_THREADS.ts';    Aliases=@('tasks.worker.cjs'); Hints=@('worker_threads','Worker','parentPort','task') },
    @{ Canonical='backend\src\utils\GRAZYNA_LARGE_OBJECT_DIAG.ts';    Aliases=@('backend\src\utils\heap.ts','backend\src\el-optimization.ts'); Hints=@('heap','gc','memoryUsage','large object') },
    @{ Canonical='scripts\monitoring\GRAZYNA_OOM_PREDICTOR.ps1';      Aliases=@(); Hints=@('OOM','heap','RSS','EL Lag') },
    @{ Canonical='scripts\monitoring\GRAZYNA_PREDICT_MONITOR.ps1';    Aliases=@(); Hints=@('Predict','EWMA','IsoForest','TTT') },
    @{ Canonical='scripts\monitoring\watchdog-ai.ps1';                Aliases=@('backend\watchdog-ai.ps1'); Hints=@('watchdog','restart','health') },
    @{ Canonical='infra\docker-compose.prod.yml';                     Aliases=@('docker-compose.prod.yml'); Hints=@('services:','backend:','frontend:','redis:') },
    @{ Canonical='infra\ecosystem.config.js';                         Aliases=@('backend\ecosystem.config.js'); Hints=@('pm2','instances','exec_mode') },
    @{ Canonical='.github\workflows\deploy-prod.yml';                 Aliases=@('.github\workflows\ci-cd.yml'); Hints=@('actions/checkout','Deploy','docker-compose') }
)

function Resolve-Candidate([string]$root, [string]$relativeOrName) {
    $p = Join-Path $root $relativeOrName
    if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
    $nameOnly = [System.IO.Path]::GetFileName($relativeOrName)
    $found = Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $ExcludeRegex -and $_.Name -ieq $nameOnly } |
        Sort-Object FullName | Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

function Get-ContentMatch([string]$root, [string[]]$hints) {
    Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $ExcludeRegex -and $_.Extension -in '.md','.ts','.js','.ps1','.txt','.yml','.yaml' } |
        ForEach-Object {
            try { $raw = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction Stop } catch { $raw = '' }
            $hits = 0
            foreach ($h in $hints) { if ($raw -match [regex]::Escape($h)) { $hits++ } }
            if ($hits -ge [Math]::Max(2, [Math]::Floor($hints.Count / 2))) {
                [pscustomobject]@{ Path=$_.FullName; Score=$hits }
            }
        } | Sort-Object Score -Descending, Path | Select-Object -First 1
}

# 1) Walidacja struktury oczekiwanej
$rows = [System.Collections.Generic.List[Object]]::new()
foreach ($item in $Expected) {
    $canonicalAbs = Join-Path $Root $item.Canonical
    if (Test-Path -LiteralPath $canonicalAbs) {
        $rows.Add([pscustomobject]@{ Item=$item.Canonical; Status='OK'; Resolved=$canonicalAbs; Basis='canonical'; Note='Plik w prawidłowej lokalizacji' })
        continue
    }

    $resolvedAlias = $null
    foreach ($a in $item.Aliases) {
        $resolvedAlias = Resolve-Candidate -root $Root -relativeOrName $a
        if ($resolvedAlias) { break }
    }

    if ($resolvedAlias) {
        $rows.Add([pscustomobject]@{ Item=$item.Canonical; Status='ALIAS'; Resolved=$resolvedAlias; Basis='alias'; Note='Znaleziono równoważnik pod inną nazwą/lokalizacją' })
        continue
    }

    $contentMatch = Get-ContentMatch -root $Root -hints $item.Hints
    if ($contentMatch) {
        $rows.Add([pscustomobject]@{ Item=$item.Canonical; Status='INTEGRATED'; Resolved=$contentMatch.Path; Basis='content'; Note="Treść zintegrowana / dopasowanie po zawartości (score=$($contentMatch.Score))" })
    } else {
        $rows.Add([pscustomobject]@{ Item=$item.Canonical; Status='MISSING'; Resolved=''; Basis='none'; Note='Brak po nazwie, aliasie i treści' })
    }
}

# 2) Analiza ścieżek osadzonych w dokumentach/skryptach
$PatternPathA = "(?<path>[A-Za-z]:\\[^\r\n""']+)"
$PatternPathB = "(?<path>(backend|frontend|docs|scripts|infra|monitoring|nginx|core|ahe|tools|manifests|\.github)[^\s""']+)"
$PathFiles = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch $ExcludeRegex -and $_.Extension -in '.md','.ps1','.ts','.js','.yml','.yaml','.txt' }

$PathValidation = [System.Collections.Generic.List[Object]]::new()
foreach ($f in $PathFiles) {
    try { $raw = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop } catch { continue }
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
            SourceFile = $f.FullName
            ReferencedPath = $p
            ResolvedPath = $norm
            Exists = $exists
        })
    }
}

# 3) Analiza działań wspólnych / operacyjnych
$Actions = @(
    @{ Name='start_backend';   Pattern='express-server\.ts|index\.ts|npm run dev|node .*express-server' },
    @{ Name='start_frontend';  Pattern='vite|npm run build|npm run dev|frontend' },
    @{ Name='health_check';    Pattern='/health|Invoke-RestMethod .*health|curl .*health' },
    @{ Name='metrics';         Pattern='/metrics|Prometheus|Grafana' },
    @{ Name='db_migration';    Pattern='prisma migrate|prisma db push|schema\.prisma' },
    @{ Name='deploy_prod';     Pattern='docker-compose\.prod\.yml|deploy-prod\.yml|Hetzner|Nginx' },
    @{ Name='monitoring';      Pattern='EWMA|IsoForest|OOM|watchdog|CrashMonitor' }
)

$ActionFiles = [System.Collections.Generic.List[Object]]::new()
foreach ($f in $PathFiles) {
    try { $raw = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop } catch { continue }
    foreach ($a in $Actions) {
        if ($raw -match $a.Pattern) {
            $ActionFiles.Add([pscustomobject]@{ Action=$a.Name; File=$f.FullName })
        }
    }
}

# 4) Raporty
$reportDir = Join-Path $Root 'reports'
if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$json = Join-Path $reportDir "checker_v2_$ts.json"
$csv  = Join-Path $reportDir "checker_v2_$ts.csv"
$pathsCsv = Join-Path $reportDir "checker_v2_paths_$ts.csv"
$actionsCsv = Join-Path $reportDir "checker_v2_actions_$ts.csv"

$rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $json -Encoding UTF8
$rows | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
$PathValidation | Export-Csv -LiteralPath $pathsCsv -NoTypeInformation -Encoding UTF8
$ActionFiles | Sort-Object Action, File | Export-Csv -LiteralPath $actionsCsv -NoTypeInformation -Encoding UTF8

# 5) Konsola
C Cyan "=== CHECKER V2 — STRUKTURA KANONICZNA ==="
$rows | Sort-Object Status, Item | Format-Table -AutoSize
Write-Host ''
C Cyan '=== WERYFIKACJA ŚCIEŻEK OSADZONYCH ==='
$broken = $PathValidation | Where-Object { -not $_.Exists }
if ($broken) {
    C Yellow ("Ścieżki nieistniejące: {0}" -f $broken.Count)
    $broken | Select-Object -First 25 | Format-Table -AutoSize
} else {
    C Green 'Wszystkie wykryte ścieżki istnieją.'
}
Write-Host ''
C Cyan '=== DZIAŁANIA WSPÓLNE / POKRYCIE ==='
$coverage = $ActionFiles | Group-Object Action | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{ Action=$_.Name; Files=$_.Count }
}
$coverage | Format-Table -AutoSize
Write-Host ''
C Green "Raport JSON : $json"
C Green "Raport CSV  : $csv"
C Green "Ścieżki CSV : $pathsCsv"
C Green "Akcje CSV   : $actionsCsv"

if ($OpenReportFolder) { Invoke-Item $reportDir }