param(
    [int]$Port = 8081
)

# =========================
# KONFIGURACJA I STAN
# =========================

$global:GrazynaHttp = @{
    Listener      = $null
    Routes        = @{}   # klucz: "METHOD PATH", wartość: [ScriptBlock]
    Middlewares   = @()   # opcjonalnie
    IsRunning     = $false
    LogFile       = "$PSScriptRoot\logs\http-backend.log"
}

if (-not (Test-Path (Split-Path $GrazynaHttp.LogFile))) {
    New-Item -ItemType Directory -Path (Split-Path $GrazynaHttp.LogFile) -Force | Out-Null
}

function Write-GrazynaHttpLog {
    param(
        [string]$Level,
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $global:GrazynaHttp.LogFile -Value $line
}

# =========================
# REJESTRACJA ROUTÓW
# =========================

function Register-GrazynaRoute {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ScriptBlock]$Handler
    )

    $key = ("{0} {1}" -f $Method.ToUpper(), $Path.TrimEnd('/'))
    $global:GrazynaHttp.Routes[$key] = $Handler
    Write-GrazynaHttpLog "INFO" "Zarejestrowano route: $key"
}

# =========================
# POMOCNICZE: ODCZYT REQUEST
# =========================

function Get-GrazynaRequestBody {
    param(
        [Parameter(Mandatory)]$Request
    )

    if (-not $Request.HasEntityBody) {
        return $null
    }

    $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    $body   = $reader.ReadToEnd()
    $reader.Dispose()
    return $body
}

function Send-GrazynaResponse {
    param(
        [Parameter(Mandatory)]$Context,
        [int]$StatusCode = 200,
        [string]$ContentType = "application/json; charset=utf-8",
        [string]$Body = ""
    )

    $response = $Context.Response
    $response.StatusCode = $StatusCode
    $response.ContentType = $ContentType

    if ($Body -ne $null) {
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
    }

    $response.OutputStream.Close()
}

# =========================
# DISPATCHER
# =========================

function Invoke-GrazynaRoute {
    param(
        [Parameter(Mandatory)]$Context
    )

    $request = $Context.Request
    $method  = $request.HttpMethod.ToUpper()
    $path    = $request.Url.AbsolutePath.TrimEnd('/')

    if ([string]::IsNullOrWhiteSpace($path)) { $path = "/" }

    $key = ("{0} {1}" -f $method, $path)
    Write-GrazynaHttpLog "INFO" "Żądanie: $key"

    $bodyRaw = Get-GrazynaRequestBody -Request $request
    $bodyJson = $null
    if ($bodyRaw) {
        try {
            $bodyJson = $bodyRaw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-GrazynaHttpLog "WARN" "Nie udało się zdeserializować JSON: $($_.Exception.Message)"
        }
    }

    $event = @{
        Method     = $method
        Path       = $path
        Headers    = $request.Headers
        BodyRaw    = $bodyRaw
        BodyJson   = $bodyJson
        Context    = $Context
        Timestamp  = Get-Date
    }

    if ($global:GrazynaHttp.Routes.ContainsKey($key)) {
        $handler = $global:GrazynaHttp.Routes[$key]
        try {
            & $handler -Event $event
        } catch {
            Write-GrazynaHttpLog "ERROR" "Błąd w handlerze route $key: $($_.Exception.Message)"
            Send-GrazynaResponse -Context $Context -StatusCode 500 -Body (@{ error = "Internal server error" } | ConvertTo-Json)
        }
    } else {
        Write-GrazynaHttpLog "WARN" "Brak handlera dla route: $key"
        Send-GrazynaResponse -Context $Context -StatusCode 404 -Body (@{ error = "Not found" } | ConvertTo-Json)
    }
}

# =========================
# GŁÓWNA PĘTLA SERWERA
# =========================

function Start-GrazynaHttpBackend {
    param(
        [int]$Port = 8081
    )

    if ($global:GrazynaHttp.IsRunning) {
        Write-Host "Grazyna HTTP backend już działa na porcie $Port."
        return
    }

    $prefix = "http://localhost:$Port/"
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($prefix)

    try {
        $listener.Start()
    } catch {
        Write-Host "Nie udało się uruchomić listenera: $($_.Exception.Message)"
        Write-GrazynaHttpLog "ERROR" "Nie udało się uruchomić listenera: $($_.Exception.Message)"
        return
    }

    $global:GrazynaHttp.Listener  = $listener
    $global:GrazynaHttp.IsRunning = $true

    Write-Host "Grazyna HTTP backend uruchomiony na $prefix"
    Write-GrazynaHttpLog "INFO" "Backend uruchomiony na $prefix"

    while ($global:GrazynaHttp.IsRunning) {
        try {
            $context = $listener.GetContext()
            Invoke-GrazynaRoute -Context $context
        } catch {
            Write-GrazynaHttpLog "ERROR" "Błąd w pętli serwera: $($_.Exception.Message)"
        }
    }

    $listener.Stop()
    $listener.Close()
    Write-GrazynaHttpLog "INFO" "Backend zatrzymany."
}

function Stop-GrazynaHttpBackend {
    if ($global:GrazynaHttp.IsRunning -and $global:GrazynaHttp.Listener -ne $null) {
        $global:GrazynaHttp.IsRunning = $false
        Write-Host "Zatrzymuję Grazyna HTTP backend..."
    } else {
        Write-Host "Backend nie jest uruchomiony."
    }
}

# =========================
# DOMYŚLNE ROUTY (PRZYKŁADY)
# =========================

# Healthcheck – do dashboardu
Register-GrazynaRoute -Method GET -Path "/health" -Handler {
    param($Event)
    $body = @{
        status    = "ok"
        timestamp = (Get-Date).ToString("o")
        service   = "GRAZYNA-HTTP-BACKEND"
    } | ConvertTo-Json

    Send-GrazynaResponse -Context $Event.Context -StatusCode 200 -Body $body
}

# Endpoint eventowy – np. z dashboardu / agentów
Register-GrazynaRoute -Method POST -Path "/event" -Handler {
    param($Event)

    # Tu możesz wpiąć centralny dispatcher Grażyny:
    # np. $Event.BodyJson.type, $Event.BodyJson.payload itd.

    Write-GrazynaHttpLog "INFO" ("Odebrano event: " + ($Event.BodyRaw))

    $body = @{
        received = $true
        timestamp = (Get-Date).ToString("o")
    } | ConvertTo-Json

    Send-GrazynaResponse -Context $Event.Context -StatusCode 200 -Body $body
}

# Start automatyczny przy uruchomieniu skryptu
if ($MyInvocation.PSScriptRoot -ne "") {
    Start-GrazynaHttpBackend -Port $Port
}
