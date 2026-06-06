\E:\Grazyna_5.0 = \"E:\Grazyna_5.0\"
\ = \"\E:\Grazyna_5.0\config\paths.json\"
\ = Get-Content \"\E:\Grazyna_5.0\tools\mapa\filemap.json\" | ConvertFrom-Json

if (-not (Test-Path \)) {
    Write-Host \"Brak pliku konfiguracyjnego paths.json - pomijam aktualizację.\" -ForegroundColor Yellow
    exit 0
}

\ = Get-Content \ | ConvertFrom-Json

foreach (\ in \.PSObject.Properties.Name) {

    \ = \.\

    if (-not (Test-Path \)) {

        \ = \ | Where-Object { \.Name -eq (Split-Path \ -Leaf) } | Select-Object -First 1

        if (\) {
            Write-Host \"Naprawiam: \ → \\" -ForegroundColor Yellow
            \.\ = \.Path
        } else {
            Write-Host \"Brak pliku: \\" -ForegroundColor Red
        }
    }
}

\ | ConvertTo-Json -Depth 5 | Out-File \ -Encoding UTF8

Write-Host \"Naprawa ścieżek zakończona.\"
