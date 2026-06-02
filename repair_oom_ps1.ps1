param(
    [string]$Path = "E:\Grazyna_5.0\GRAZYNA_OOM_PREDICTOR.ps1"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Error "Plik nie istnieje: $Path"
    exit 1
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = "$Path.bak_$timestamp"

Copy-Item -LiteralPath $Path -Destination $backupPath -Force
Write-Host "Backup zapisany: $backupPath" -ForegroundColor Yellow

# Wczytaj cały plik jako tekst
$text = Get-Content -LiteralPath $Path -Raw

# =========================
# 1) Naprawa encji HTML
# =========================
$text = $text -replace '&lt;', '<'
$text = $text -replace '&gt;', '>'
$text = $text -replace '&nbsp;', ' '
$text = $text -replace '&amp;', '&'
$text = $text -replace '&quot;', '"'
$text = $text -replace '&#39;', "'"

# =========================
# 2) Naprawa najczęstszych mojibake / popsutych znaków
# =========================

# Długie myślniki / cudzysłowy / elipsy
$text = $text -replace 'â€”', '-'
$text = $text -replace 'â€“', '-'
$text = $text -replace 'â€¦', '...'
$text = $text -replace 'â€˜', "'"
$text = $text -replace 'â€™', "'"
$text = $text -replace 'â€œ', '"'
$text = $text -replace 'â€�', '"'

# Box drawing / separatory
$text = $text -replace 'â”€â”€â”€+', '---'
$text = $text -replace '─+', '---'

# Niekiedy trafiają się niewidzialne / nietypowe spacje
$text = $text -replace "`u00A0", ' '   # NBSP
$text = $text -replace "`u2007", ' '
$text = $text -replace "`u202F", ' '

# =========================
# 3) Zamiana emoji / uszkodzonych ikon na ASCII
# =========================

# Uszkodzone emoji z logów
$text = $text -replace 'đź”®', '[OOM]'
$text = $text -replace 'đź’ľ', '[MEM]'
$text = $text -replace 'đźš¨', '[ALERT]'

# Jeśli w pliku są poprawne emoji/unicode, też zamieńmy na ASCII-safe
$text = $text -replace '🔮', '[OOM]'
$text = $text -replace '💾', '[MEM]'
$text = $text -replace '🚨', '[ALERT]'
$text = $text -replace '⚠️', '[WARN]'
$text = $text -replace '⚠', '[WARN]'

# =========================
# 4) Dodatkowe korekty konkretnych znanych fragmentów
# =========================

# TTT krytyczny z HTML
$text = $text -replace 'TTT krytyczny:\s*&lt;\s*60s', 'TTT krytyczny: <60s'

# Jeśli ostrzeżenie jest rozwalone przez &nbsp;/mojibake
$text = $text -replace 'âš.*?OSTRZE', '[WARN] OSTRZE'
$text = $text -replace 'OSTRZEĹ»ENIE', 'OSTRZEZENIE'
$text = $text -replace 'OSTRZEŻENIE', 'OSTRZEZENIE'

# Długi myślnik w komunikacie alertu
$text = $text -replace '\s+â€”\s+', ' - '
$text = $text -replace '\s+—\s+', ' - '

# =========================
# 5) Zamiana całych najbardziej problematycznych linii na wersje bezpieczne
#    (na podstawie Twoich błędów parsera)
# =========================

$lines = $text -split "`r?`n"

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    # Separator OOM header
    if ($line -match 'Write-Host\s*\(".*OOM\s+#\$iteration\s+@\s+\$ts') {
        $lines[$i] = '    Write-Host ("--- OOM #$iteration @ $ts (uptime: ${uptime}min) ---") -ForegroundColor Cyan'
        continue
    }

    # OOM risk z uszkodzonym emoji
    if ($line -match 'Write-Host\s*\(".*OOM RISK:\s*\[\{0\}\]\s*\{1\}%".*-f\s*\$fpBar,\s*\$fpPct') {
        $lines[$i] = '    Write-Host ("  [OOM] OOM RISK: [{0}] {1}%" -f $fpBar, $fpPct) -ForegroundColor Magenta'
        continue
    }

    # RSS / MEM linia z uszkodzonym emoji
    if ($line -match 'Write-Host\s*\(".*RSS:\s*\{0,5\}MB.*LOS:.*\(\{3\}%\).*"-f') {
        $lines[$i] = '    Write-Host ("  [MEM] RSS: {0,5}MB  LOS:{1}KB/{2}KB ({3}%)  GC:{4}" -f $rssMb, $losUsedKb, $losTotalKb, $losPct, $gcMode) -ForegroundColor Gray'
        continue
    }

    # Alert heap OOM z popsutym ostrzeżeniem
    if ($line -match '\$alerts\s*\+=\s*".*Heap OOM za \$\(\$tttHeap95\.text\).*"') {
        $lines[$i] = '        $alerts += "[WARN] OSTRZEZENIE: Heap OOM za $($tttHeap95.text) - monitoruj"'
        continue
    }
}

$text = [string]::Join([Environment]::NewLine, $lines)

# =========================
# 6) Zapis jako UTF-8 z BOM
# =========================
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($Path, $text, $utf8Bom)

Write-Host "Plik naprawiony i zapisany jako UTF-8 BOM: $Path" -ForegroundColor Green

# =========================
# 7) Parser check po naprawie
# =========================
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    $Path,
    [ref]$tokens,
    [ref]$errors
) | Out-Null

if ($errors.Count -eq 0) {
    Write-Host "PARSER: OK" -ForegroundColor Green
} else {
    Write-Host "PARSER: znaleziono bledy po naprawie:" -ForegroundColor Red
    foreach ($e in $errors) {
        $msg = $e.Message
        $lineNo = $e.Extent.StartLineNumber
        $colNo = $e.Extent.StartColumnNumber
        Write-Host ("- Linia {0}, kolumna {1}: {2}" -f $lineNo, $colNo, $msg) -ForegroundColor Red
    }
}