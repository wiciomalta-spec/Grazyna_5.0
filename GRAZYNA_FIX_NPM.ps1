# ============================================================
# GRAŻYNA 5.0 — FIX npm.cmd ODMOWA DOSTĘPU
# Błąd: Program 'npm.cmd' failed to run: Odmowa dostępu
# Przyczyna: npm.cmd jest zablokowany przez Windows lub
#            brakuje uprawnień do wykonania .cmd z PS
# ============================================================

$proj    = "E:\Grazyna_5.0"
$backend = "$proj\backend"
$nodeDir = "$proj\tools\nodejs"
$npmCmd  = "$nodeDir\npm.cmd"
$nodeExe = "$nodeDir\node.exe"

function Log($level, $msg) {
    $col = switch($level) { "OK"{"Green"}; "WARN"{"Yellow"}; "ERR"{"Red"}; "INFO"{"Cyan"} }
    $ico = switch($level) { "OK"{"✅"}; "WARN"{"⚠️"}; "ERR"{"❌"}; "INFO"{"ℹ️"} }
    Write-Host "  $ico $msg" -ForegroundColor $col
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║    GRAŻYNA 5.0 — FIX npm.cmd ODMOWA DOSTĘPU        ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

# ─── DIAGNOZA ─────────────────────────────────────────────
Write-Host "[ DIAGNOZA ]" -ForegroundColor Yellow

# Sprawdź atrybuty npm.cmd
$npmItem = Get-Item $npmCmd -ErrorAction SilentlyContinue
if ($npmItem) {
    Log "INFO" "npm.cmd istnieje: $($npmItem.FullName)"
    Log "INFO" "Rozmiar: $($npmItem.Length) B"
    Log "INFO" "Atrybuty: $($npmItem.Attributes)"

    # Sprawdź ACL
    $acl = Get-Acl $npmCmd
    Write-Host "  📋 Uprawnienia:" -ForegroundColor Cyan
    $acl.Access | ForEach-Object {
        Write-Host "     $($_.IdentityReference): $($_.FileSystemRights) ($($_.AccessControlType))" -ForegroundColor Gray
    }
} else {
    Log "ERR" "npm.cmd nie istnieje w $nodeDir!"
}

# Sprawdź ExecutionPolicy
$policy = Get-ExecutionPolicy -Scope Process
Log "INFO" "ExecutionPolicy (Process): $policy"
$policyMachine = Get-ExecutionPolicy -Scope LocalMachine
Log "INFO" "ExecutionPolicy (Machine): $policyMachine"

Write-Host ""
Write-Host "[ NAPRAWA — 5 metod ]" -ForegroundColor Yellow
Write-Host ""

# ─── METODA 1: Unblock-File ───────────────────────────────
Write-Host "[ 1/5 ] Unblock-File (usuń Zone.Identifier)..." -ForegroundColor Cyan
try {
    Get-ChildItem $nodeDir -Recurse | Unblock-File -ErrorAction SilentlyContinue
    Log "OK" "Unblock-File wykonany na $nodeDir"
} catch {
    Log "WARN" "Unblock-File: $_"
}

# ─── METODA 2: Napraw uprawnienia ACL ─────────────────────
Write-Host "[ 2/5 ] Naprawa uprawnień ACL..." -ForegroundColor Cyan
try {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $acl = Get-Acl $nodeDir
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $currentUser, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
    )
    $acl.SetAccessRule($rule)
    Set-Acl $nodeDir $acl
    Log "OK" "Uprawnienia FullControl nadane dla: $currentUser"
} catch {
    Log "WARN" "ACL fix: $_ (spróbuj jako Administrator)"
}

# ─── METODA 3: Użyj node.exe bezpośrednio zamiast npm.cmd ─
Write-Host "[ 3/5 ] Alternatywa: node.exe + npm script bezpośrednio..." -ForegroundColor Cyan

# Znajdź npm/npm.js
$npmJs = "$nodeDir\node_modules\npm\bin\npm-cli.js"
if (-not (Test-Path $npmJs)) {
    # Szukaj w innych lokalizacjach
    $npmJs = Get-ChildItem "$nodeDir" -Recurse -Filter "npm-cli.js" -ErrorAction SilentlyContinue |
             Select-Object -First 1 -ExpandProperty FullName
}

if ($npmJs) {
    Log "OK" "Znaleziono npm-cli.js: $npmJs"
    Log "INFO" "Możesz używać: & '$nodeExe' '$npmJs' install"
} else {
    Log "WARN" "npm-cli.js nie znaleziony"
}

# ─── METODA 4: Utwórz wrapper .bat ────────────────────────
Write-Host "[ 4/5 ] Tworzenie wrapper npm.bat..." -ForegroundColor Cyan

$npmBat = "$nodeDir\npm.bat"
$npmBatContent = @"
@echo off
"$nodeExe" "$npmJs" %*
"@

if ($npmJs) {
    $npmBatContent | Out-File $npmBat -Encoding ASCII
    Log "OK" "Utworzono npm.bat: $npmBat"
} else {
    # Fallback — użyj npm.cmd przez cmd.exe
    $npmBatContent = "@echo off`r`ncmd /c `"$npmCmd`" %*"
    $npmBatContent | Out-File $npmBat -Encoding ASCII
    Log "OK" "Utworzono npm.bat (fallback przez cmd.exe)"
}

# ─── METODA 5: Uruchom backend przez cmd.exe ──────────────
Write-Host "[ 5/5 ] Uruchamianie backendu przez cmd.exe..." -ForegroundColor Cyan

# Sprawdź czy backend ma node_modules
if (-not (Test-Path "$backend\node_modules")) {
    Log "WARN" "Brak node_modules — instaluję..."
    $installCmd = "cd /d `"$backend`" && `"$nodeExe`" `"$npmJs`" install"
    Start-Process cmd -ArgumentList "/c", $installCmd -Wait -NoNewWindow
}

# Uruchom dev przez cmd.exe (omija problem z .cmd w PS)
Log "INFO" "Uruchamiam backend przez cmd.exe..."
$devCmd = "cd /d `"$backend`" && `"$nodeExe`" `"$npmJs`" run dev"
Start-Process cmd -ArgumentList "/k", $devCmd -WindowStyle Normal

Log "OK" "Backend uruchomiony w nowym oknie cmd.exe"

# ─── PODSUMOWANIE ─────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║    ✅ FIX ZAKOŃCZONY                                ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Jeśli backend nie startuje, użyj ręcznie:" -ForegroundColor Cyan
Write-Host ""
Write-Host '  # Opcja A — przez cmd.exe:' -ForegroundColor White
Write-Host "  cmd /c `"cd /d E:\Grazyna_5.0\backend && E:\Grazyna_5.0\tools\nodejs\node.exe node_modules\.bin\tsx src\index.ts`"" -ForegroundColor Gray
Write-Host ""
Write-Host '  # Opcja B — przez node bezpośrednio:' -ForegroundColor White
Write-Host "  & 'E:\Grazyna_5.0\tools\nodejs\node.exe' 'E:\Grazyna_5.0\backend\node_modules\.bin\tsx' 'E:\Grazyna_5.0\backend\src\index.ts'" -ForegroundColor Gray
Write-Host ""
Write-Host '  # Opcja C — dist (już skompilowany):' -ForegroundColor White
Write-Host "  & 'E:\Grazyna_5.0\tools\nodejs\node.exe' 'E:\Grazyna_5.0\backend\dist\index.js'" -ForegroundColor Gray
Write-Host ""