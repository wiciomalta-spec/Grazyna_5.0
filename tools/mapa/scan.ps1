\E:\Grazyna_5.0 = \"E:\Grazyna_5.0\"
\ = \"\E:\Grazyna_5.0\tools\mapa\filemap.json\"

\ = @()

Get-ChildItem -Path \E:\Grazyna_5.0 -Recurse -File | ForEach-Object {
    \ += [PSCustomObject]@{
        Name = \.Name
        Path = \.FullName
        Size = \.Length
        Modified = \.LastWriteTime
        Directory = \.DirectoryName
    }
}

\ | ConvertTo-Json -Depth 5 | Out-File \ -Encoding UTF8

Write-Host \"Mapa plików wygenerowana.\"
