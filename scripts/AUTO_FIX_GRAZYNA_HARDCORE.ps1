# =========================================================
# GRAZYNA AUTO-FIX HARDCORE + JSON REPORT
# =========================================================
$ErrorActionPreference = "SilentlyContinue"

$Root = (Get-Location).Path
$Report = [ordered]@{
  root = $Root
  timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  searched_paths = @()
  found = @{}
  copied = @{}
  patched = @{}
  missing = @()
}

Write-Host "ROOT = $Root" -ForegroundColor Cyan

# --- gdzie szukamy
$SearchRoots = @(
  $Root,
  $env:USERPROFILE,
  (Join-Path $env:USERPROFILE "Desktop"),
  (Join-Path $env:USERPROFILE "Documents"),
  (Join-Path $env:USERPROFILE "OneDrive"),
  "C:\Users\User\OneDrive"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$Report.searched_paths = $SearchRoots

function Find-LatestFile($Name) {
  foreach ($base in $SearchRoots) {
    $f = Get-ChildItem -Path $base -Recurse -File -Filter $Name -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending |
         Select-Object -First 1
    if ($f) { return $f.FullName }
  }
  return $null
}

function Ensure-Dir($Path) {
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

# =========================================================
# 1) KRYTYCZNE PLIKI
# =========================================================
$CriticalFiles = @(
  "ai_chat.py",
  "mega_panel.py"
)

foreach ($file in $CriticalFiles) {
  $target = Join-Path $Root $file
  if (-not (Test-Path $target)) {
    $src = Find-LatestFile $file
    if ($src) {
      Copy-Item $src $target -Force
      $Report.copied[$file] = $src
      Write-Host "[COPY] $file <- $src" -ForegroundColor Green
    } else {
      $Report.missing += $file
      Write-Host "[MISSING] $file" -ForegroundColor Red
    }
  } else {
    $Report.found[$file] = $target
    Write-Host "[OK] $file" -ForegroundColor Green
  }
}

# =========================================================
# 2) CONSOLE PATCH
# =========================================================
$ConsoleAI = Join-Path $Root "console_launcher\console_ai.py"
if (Test-Path $ConsoleAI) {
  $txt = Get-Content $ConsoleAI -Raw
  if ($txt -match "from\s+ai_chat\s+import\s+AIChat" -and
      -not ($txt -match "sys\.path\.insert")) {

$patch = @"
import os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

"@

    $new = $txt -replace "(?m)^\s*from\s+ai_chat\s+import\s+AIChat",
      ($patch + "`nfrom ai_chat import AIChat")

    Set-Content -Path $ConsoleAI -Value $new -Encoding UTF8
    $Report.patched["console_ai.py"] = "sys.path -> ROOT"
    Write-Host "[PATCH] console_ai.py" -ForegroundColor Yellow
  }
}

# =========================================================
# 3) RINGS + MANIFESTS
# =========================================================
Ensure-Dir (Join-Path $Root "rings")
Ensure-Dir (Join-Path $Root "manifests")

$Manifests = @(
  "rings_manifest.json",
  "commands_manifest.json",
  "aliases.json",
  "actions_state.json"
)

foreach ($mf in $Manifests) {
  $target = Join-Path $Root "manifests\$mf"
  if (-not (Test-Path $target)) {
    $src = Find-LatestFile $mf
    if ($src) {
      Copy-Item $src $target -Force
      $Report.copied[$mf] = $src
    } else {
      $Report.missing += $mf
    }
  } else {
    $Report.found[$mf] = $target
  }
}

# =========================================================
# 4) RAPORT JSON
# =========================================================
$ReportPath = Join-Path $Root "AUTO_FIX_REPORT.json"
$Report | ConvertTo-Json -Depth 6 | Set-Content $ReportPath -Encoding UTF8

Write-Host ""
Write-Host "=======================" -ForegroundColor Cyan
Write-Host "AUTO_FIX HARDCORE DONE ✅" -ForegroundColor Cyan
Write-Host "Raport: AUTO_FIX_REPORT.json" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
