$PanelRoot = "E:\Grazyna_5.0\backup-panel"

function Get-FreePort {
    foreach ($p in 8765..8780) {
        try {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $p)
            $listener.Start()
            $listener.Stop()
            return $p
        } catch {}
    }
    return 9000
}

$port = Get-FreePort

Set-Location $PanelRoot
Start-Process "http://127.0.0.1:$port/dashboard.html"

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py }

if ($python.Name -eq "py") {
    & py -3 -m http.server $port
} else {
    & python -m http.server $port
}
