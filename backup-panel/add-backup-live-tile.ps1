$PanelRoot = "E:\Grazyna_5.0\backup-panel"
$MainIndex = "E:\Grazyna_5.0\index.html"
$TileFile  = "E:\Grazyna_5.0\backup-live-tile.html"

$tileHtml = @"
<div class="tile" style="background:#111827;border:1px solid #334155;border-radius:18px;padding:16px;margin:12px 0;">
  <div style="font-size:20px;font-weight:700;color:#93c5fd;">🛡 Backup Live</div>
  <div style="color:#94a3b8;margin:8px 0;">Podglad backupow, wolnego miejsca i integralnosci.</div>
  <button onclick="window.open('http://127.0.0.1:' + (localStorage.getItem('grazyna_backup_port') || '8765') + '/dashboard.html','_blank')" style="background:#2563eb;color:#fff;border:none;border-radius:12px;padding:10px 14px;cursor:pointer;">
    Otworz Backup Live
  </button>
</div>
<script>
fetch('backup-panel/dashboard-port.txt?t=' + Date.now())
  .then(r => r.text())
  .then(p => localStorage.setItem('grazyna_backup_port', p.trim()))
  .catch(() => {});
</script>
"@

if (Test-Path -LiteralPath $MainIndex) {
    $content = Get-Content -LiteralPath $MainIndex -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch 'Backup Live') {
        $updated = $content -replace '</body>', ($tileHtml + "`n</body>")
        Set-Content -Path $MainIndex -Value $updated -Encoding UTF8
        Write-Host "OK: dodano kafelek Backup Live do $MainIndex"
    } else {
        Write-Host "INFO: kafelek Backup Live juz istnieje"
    }
} else {
    Set-Content -Path $TileFile -Value $tileHtml -Encoding UTF8
    Write-Host "INFO: nie znaleziono $MainIndex, utworzono gotowy kafelek w $TileFile"
}
