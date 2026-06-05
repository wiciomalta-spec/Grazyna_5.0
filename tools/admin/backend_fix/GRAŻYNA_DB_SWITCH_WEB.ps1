# ============================================================
# GRAŻYNA 5.0 — DB SWITCH WEB GUI
# HTTP API do zarządzania DB (SQLite ↔ PostgreSQL)
# ============================================================

$proj = "E:\Grazyna_5.0"
$backendFix = "$proj\tools\admin\backend_fix"
$logFile = "$proj\logs\db_web.log"

Add-Type -AssemblyName System.Net.HttpListener

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8088/")
$listener.Start()

function Log($msg){
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content $logFile "[$ts] $msg"
}

function Send($ctx,$code,$body){
    $bytes = [Text.Encoding]::UTF8.GetBytes($body)
    $ctx.Response.StatusCode = $code
    $ctx.Response.ContentType = "application/json"
    $ctx.Response.OutputStream.Write($bytes,0,$bytes.Length)
    $ctx.Response.OutputStream.Close()
}

Log "WEB GUI START"

while ($true) {
    $ctx = $listener.GetContext()
    $path = $ctx.Request.Url.AbsolutePath.ToLower()

    switch ($path) {

        "/db/status" {
            $env = Get-Content "$proj\backend\.env"
            $prov = ($env | Select-String "DB_PROVIDER").ToString().Split("=")[1]
            Send $ctx 200 "{""provider"":""$prov""}"
        }

        "/db/switch/sqlite" {
            & "$backendFix\GRAZYNA_DB_SWITCH.ps1"
            Send $ctx 200 "{""status"":""switched to sqlite""}"
        }

        "/db/switch/postgres" {
            & "$backendFix\GRAZYNA_DB_SWITCH.ps1"
            Send $ctx 200 "{""status"":""switched to postgresql""}"
        }

        "/db/migrate" {
            & "$backendFix\GRAZYNA_DB_SWITCH.ps1"
            Send $ctx 200 "{""status"":""migrations executed""}"
        }

        "/db/enums" {
            & "$proj\backend\tools\prisma-enums-gen.ts"
            Send $ctx 200 "{""status"":""enums generated""}"
        }

        "/db/validate" {
            & "$proj\backend\tools\prisma-json-validator.ts"
            Send $ctx 200 "{""status"":""json validated""}"
        }

        "/db/test" {
            try {
                $r = Invoke-WebRequest "http://localhost:3001/health" -TimeoutSec 3
                Send $ctx 200 "{""backend"":""ok""}"
            } catch {
                Send $ctx 500 "{""backend"":""fail""}"
            }
        }

        default {
            Send $ctx 404 "{""error"":""unknown endpoint""}"
        }
    }
}