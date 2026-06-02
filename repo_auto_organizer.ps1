param(
    [string]$Root = "E:\Grazyna_5.0",
    [switch]$WhatIf,
    [switch]$VerboseReport
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Root)) {
    throw "Katalog repo nie istnieje: $Root"
}

function Write-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host $msg -ForegroundColor Green }
function Write-WarnX($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-ErrX($msg) { Write-Host $msg -ForegroundColor Red }

$ExcludeRegex = '\\node_modules\\|\\dist\\|\\.git\\|\\__pycache__\\|\\.next\\|\\coverage\\|\\tmp\\|\\temp\\|\\logs\\'

$Rules = @(
    @{ Canonical='GRAZYNA_ANALIZA_RAPORT.md';        Dest='docs\analysis';      Type='doc';      Aliases=@('GRAZYNA_INTEGRATION_REPORT.md','GRAZYNA_INTEGRATION_REPORT.txt','GRAZYNA_CRASH_CLUSTER_ANALYSIS.md') },
    @{ Canonical='GRAZYNA_HETZNER_READY.md';         Dest='docs\deployment';    Type='doc';      Aliases=@('GRAZYNA_REDIS_ML_CLUSTER_ANALYSIS.md','GRAZYNA_HETZNER_DEPLOY_CHECKLIST.md') },
    @{ Canonical='GRAZYNA_DB_ANALYSIS.md';           Dest='docs\architecture';  Type='doc';      Aliases=@('GRAZYNA_DATABASE_ANALYSIS.md') },
    @{ Canonical='GRAZYNA_AUTH_JWT_VS_SESSIONS.md';  Dest='docs\architecture';  Type='doc';      Aliases=@('GRAZYNA_AUTH_ANALYSIS.md') },
    @{ Canonical='GRAZYNA_ML_VS_REGRESSION.md';      Dest='docs\architecture';  Type='doc';      Aliases=@('GRAZYNA_ML_ANALYSIS.md','GRAZYNA_REDIS_ML_CLUSTER_ANALYSIS.md') },
    @{ Canonical='GRAZYNA_EXPRESS_VS_FASTIFY.md';    Dest='docs\architecture';  Type='doc';      Aliases=@('GRAZYNA_SERVER_COMPARISON.md') },
    @{ Canonical='GRAZYNA_FASTIFY_MIGRATION.md';     Dest='docs\architecture';  Type='doc';      Aliases=@('GRAZYNA_FASTIFY_PLAN.md') },

    @{ Canonical='GRAZYNA_BACKEND_FIX.ts';           Dest='backend\src\system';   Type='code'; Aliases=@('backend_fix.ts') },
    @{ Canonical='GRAZYNA_WORKER_THREADS.ts';        Dest='backend\src\services'; Type='code'; Aliases=@('worker_threads.ts','tasks.worker.ts','tasks.worker.cjs') },
    @{ Canonical='GRAZYNA_LARGE_OBJECT_DIAG.ts';     Dest='backend\src\utils';    Type='code'; Aliases=@('large_object_diag.ts','los_diag.ts') },

    @{ Canonical='GRAZYNA_OOM_PREDICTOR.ps1';        Dest='scripts\monitoring';   Type='script'; Aliases=@('OOM_PREDICTOR.ps1') },
    @{ Canonical='GRAZYNA_PREDICT_MONITOR.ps1';      Dest='scripts\monitoring';   Type='script'; Aliases=@('PREDICT_MONITOR.ps1') },
    @{ Canonical='watchdog-ai.ps1';                  Dest='scripts\monitoring';   Type='script'; Aliases=@('GRAZYNA_WATCHDOG_AI.ps1') },

    @{ Canonical='docker-compose.prod.yml';          Dest='infra';                  Type='infra';   Aliases=@('docker-compose.production.yml') },
    @{ Canonical='ecosystem.config.js';              Dest='infra';                  Type='infra';   Aliases=@('backend\ecosystem.config.js') },
    @{ Canonical='deploy-prod.yml';                  Dest='.github\workflows';      Type='infra';   Aliases=@('ci-cd.yml','deploy.yml') }
)

$ContentHints = @{
    'GRAZYNA_ANALIZA_RAPORT.md' = @('Root Cause Analysis','CrashMonitor','PM2','EADDRINUSE', 'Plan Migracji do Produkcji')
    'GRAZYNA_HETZNER_READY.md'  = @('Hetzner','redis.conf','IsoForest','EWMA','Nginx Config')
    'GRAZYNA_DB_ANALYSIS.md'    = @('schema.prisma','postgresql','SQLite','DATABASE_URL')
    'GRAZYNA_AUTH_JWT_VS_SESSIONS.md' = @('JWT','Refresh Token','session','SameSite')
    'GRAZYNA_ML_VS_REGRESSION.md' = @('EWMA','IsoForest','Z-Score','Regresja','TTT')
    'GRAZYNA_EXPRESS_VS_FASTIFY.md' = @('Express','Fastify','express-server.ts','fastify-server.ts')
    'GRAZYNA_FASTIFY_MIGRATION.md' = @('Fastify','migration','express-server.ts','fastify-server.ts')
    'GRAZYNA_BACKEND_FIX.ts' = @('listen(', 'health', 'express', 'cluster')
    'GRAZYNA_WORKER_THREADS.ts' = @('Worker', 'worker_threads', 'tasks.worker', 'parentPort')
    'GRAZYNA_LARGE_OBJECT_DIAG.ts' = @('heap', 'large object', 'gc', 'memoryUsage')
}

function Ensure-Dir([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) {
        if (-not $WhatIf) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
        Write-Info "[mkdir] $path"
    }
}

function Get-CandidateFiles([string]$root, [string[]]$names) {
    Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $ExcludeRegex -and ($names -contains $_.Name) }
}

function Test-ContentHint([string]$filePath, [string[]]$hints) {
    if (-not (Test-Path -LiteralPath $filePath)) { return $false }
    try {
        $raw = Get-Content -LiteralPath $filePath -Raw -ErrorAction Stop
        foreach ($h in $hints) {
            if ($raw -match [regex]::Escape($h)) { return $true }
        }
    } catch {}
    return $false
}

$Report = [System.Collections.Generic.List[Object]]::new()

foreach ($rule in $Rules) {
    $destDir = Join-Path $Root $rule.Dest
    Ensure-Dir $destDir
    $canonicalPath = Join-Path $destDir $rule.Canonical

    if (Test-Path -LiteralPath $canonicalPath) {
        $Report.Add([pscustomobject]@{ Canonical=$rule.Canonical; Status='OK'; Source=$canonicalPath; Dest=$canonicalPath; Note='Już na miejscu' })
        continue
    }

    $searchNames = @($rule.Canonical) + $rule.Aliases
    $candidates = Get-CandidateFiles -root $Root -names $searchNames

    $picked = $null
    if ($candidates.Count -eq 1) {
        $picked = $candidates[0]
    } elseif ($candidates.Count -gt 1) {
        $picked = $candidates |
            Sort-Object @{Expression={ if ($_.FullName -match '\\docs\\|\\backend\\|\\scripts\\|\\infra\\') { 0 } else { 1 } }},
                        @{Expression={ $_.FullName.Length }} |
            Select-Object -First 1
    }

    if (-not $picked -and $ContentHints.ContainsKey($rule.Canonical)) {
        $hints = $ContentHints[$rule.Canonical]
        $picked = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch $ExcludeRegex -and
                $_.Extension -in '.md','.ts','.js','.ps1','.txt' -and
                (Test-ContentHint -filePath $_.FullName -hints $hints)
            } |
            Sort-Object @{Expression={ $_.FullName.Length }} |
            Select-Object -First 1
    }

    if ($picked) {
        $targetPath = $canonicalPath
        if ($picked.FullName -ieq $targetPath) {
            $Report.Add([pscustomobject]@{ Canonical=$rule.Canonical; Status='OK'; Source=$picked.FullName; Dest=$targetPath; Note='Już zgodny' })
            continue
        }

        if ($WhatIf) {
            Write-Host "[move] $($picked.FullName) -> $targetPath" -ForegroundColor Yellow
        } else {
            Move-Item -LiteralPath $picked.FullName -Destination $targetPath -Force
            Write-Ok "[move] $($picked.Name) -> $targetPath"
        }

        $Report.Add([pscustomobject]@{ Canonical=$rule.Canonical; Status='MOVED'; Source=$picked.FullName; Dest=$targetPath; Note='Przeniesiono/ujednolicono nazwę' })
    } else {
        Write-WarnX "[missing] $($rule.Canonical)"
        $Report.Add([pscustomobject]@{ Canonical=$rule.Canonical; Status='MISSING'; Source=''; Dest=$canonicalPath; Note='Nie znaleziono po nazwie/aliasie/wzorcu treści' })
    }
}

$reportDir = Join-Path $Root 'reports'
Ensure-Dir $reportDir
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$jsonPath = Join-Path $reportDir "repo_organizer_report_$ts.json"
$csvPath  = Join-Path $reportDir "repo_organizer_report_$ts.csv"
$Report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$Report | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Ok "Raport JSON: $jsonPath"
Write-Ok "Raport CSV : $csvPath"

if ($VerboseReport) {
    $Report | Sort-Object Status, Canonical | Format-Table -AutoSize
}