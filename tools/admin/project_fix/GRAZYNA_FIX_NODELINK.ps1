# ============================================================
# GRAŻYNA 5.0 — NAPRAWA node.exe HARDLINK → SYMLINK
# Uruchom jako Administrator po zatrzymaniu Node.js
# Data: 2026-05-29
# ============================================================

$dst = "E:\Grazyna_5.0\tools\nodejs\node.exe"
$src = "E:\Grazyna_5.0\tools\nvm\nodejs\node.exe"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║   GRAŻYNA 5.0 — NAPRAWA node.exe SYMLINK     ║" -ForegroundColor Yellow
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# ─── KROK 1: Sprawdź czy uruchomiony jako Admin ───
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ Uruchom PowerShell jako Administrator!" -ForegroundColor Red
    Write-Host "   Kliknij prawym na PowerShell → 'Uruchom jako administrator'" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Uruchomiono jako Administrator" -ForegroundColor Green

# ─── KROK 2: Zatrzymaj wszystkie procesy Node.js ───
Write-Host ""
Write-Host "[ 1/5 ] Zatrzymywanie procesów Node.js..." -ForegroundColor Yellow
$nodeProcs = Get-Process node -ErrorAction SilentlyContinue
if ($nodeProcs) {
    $nodeProcs | ForEach-Object {
        Write-Host "  → Zatrzymuję PID $($_.Id) ($($_.MainWindowTitle))" -ForegroundColor Gray
        $_ | Stop-Process -Force
    }
    Start-Sleep -Seconds 2
    Write-Host "  ✅ Procesy Node.js zatrzymane" -ForegroundColor Green
} else {
    Write-Host "  ✅ Brak aktywnych procesów Node.js" -ForegroundColor Green
}

# ─── KROK 3: Sprawdź źródłowy plik ───
Write-Host ""
Write-Host "[ 2/5 ] Weryfikacja pliku źródłowego..." -ForegroundColor Yellow
if (-not (Test-Path $src)) {
    Write-Host "  ❌ Plik źródłowy nie istnieje: $src" -ForegroundColor Red
    Write-Host "  Sprawdź czy tools\nvm\nodejs\node.exe istnieje!" -ForegroundColor Yellow
    exit 1
}
$srcSize = [math]::Round((Get-Item $src).Length / 1MB, 1)
Write-Host "  ✅ Źródło: $src ($srcSize MB)" -ForegroundColor Green

# ─── KROK 4: Przejmij własność i uprawnienia ───
Write-Host ""
Write-Host "[ 3/5 ] Przejmowanie własności node.exe..." -ForegroundColor Yellow
try {
    $result = takeown /f $dst /a 2>&1
    Write-Host "  → takeown: $result" -ForegroundColor Gray
    $result2 = icacls $dst /grant "Administrators:F" 2>&1
    Write-Host "  → icacls: $result2" -ForegroundColor Gray
    Write-Host "  ✅ Własność przejęta" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  takeown/icacls błąd: $_" -ForegroundColor Yellow
}

# ─── KROK 5: Usuń hardlink i utwórz symlink ───
Write-Host ""
Write-Host "[ 4/5 ] Zamiana hardlink → symlink..." -ForegroundColor Yellow

# Backup info
$dstItem = Get-Item $dst -ErrorAction SilentlyContinue
if ($dstItem) {
    Write-Host "  → Typ przed: LinkType='$($dstItem.LinkType)' Attributes=$($dstItem.Attributes)" -ForegroundColor Gray
}

try {
    Remove-Item $dst -Force -ErrorAction Stop
    Write-Host "  ✅ Stary hardlink usunięty" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Nie można usunąć: $_" -ForegroundColor Red
    Write-Host "  Spróbuj zamknąć wszystkie okna PowerShell i terminale, potem uruchom ponownie." -ForegroundColor Yellow
    exit 1
}

try {
    New-Item -ItemType SymbolicLink -Path $dst -Target $src -ErrorAction Stop | Out-Null
    Write-Host "  ✅ Symlink utworzony: $dst → $src" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Nie można utworzyć symlinka: $_" -ForegroundColor Red
    Write-Host "  Przywracam kopię..." -ForegroundColor Yellow
    Copy-Item $src $dst -Force
    Write-Host "  ✅ Przywrócono kopię node.exe" -ForegroundColor Green
    exit 1
}

# ─── KROK 6: Weryfikacja ───
Write-Host ""
Write-Host "[ 5/5 ] Weryfikacja..." -ForegroundColor Yellow
$newItem = Get-Item $dst
Write-Host "  LinkType:   '$($newItem.LinkType)'" -ForegroundColor Cyan
Write-Host "  Target:     '$($newItem.Target)'" -ForegroundColor Cyan
Write-Host "  Attributes: $($newItem.Attributes)" -ForegroundColor Cyan

if ($newItem.LinkType -eq "SymbolicLink") {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║   ✅ SYMLINK NAPRAWIONY POMYŚLNIE!           ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  node.exe → $($newItem.Target)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Teraz uruchom system:" -ForegroundColor Cyan
    Write-Host "  & 'E:\Grazyna_5.0\GRAZYNA_START.ps1'" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "  ⚠️  LinkType nie jest SymbolicLink — sprawdź ręcznie" -ForegroundColor Yellow
}