# healthcheck.ps1
$composeFile = "docker-compose.prod.yml"
$services = @(
    "grazyna-enterprise-api",
    "grazyna-enterprise-db",
    "grazyna-enterprise-cache",
    "grazyna_50-postgres-1",
    "grazyna_50-redis-1",
    "grazyna_50-grafana-1",
    "grazyna_50-prometheus-1"
)

Write-Host "Healthcheck start" -ForegroundColor Cyan

# 1. Ports and compose status
Write-Host "`n=== Docker Compose status ==="
docker compose -f $composeFile ps

# 2. Inspect API ports
Write-Host "`n=== API port mapping ==="
docker inspect grazyna-enterprise-api --format '{{json .NetworkSettings.Ports}}'

# 3. Check endpoints from host
$urls = @("http://localhost:8080/health","http://localhost:8080/docs","http://localhost:3000","http://localhost:9090")
foreach ($u in $urls) {
    try {
        $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 5
        Write-Host "$u -> $($r.StatusCode) $($r.StatusDescription)"
    } catch {
        Write-Host "$u -> ERROR: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 4. Tail logs for key services (last 200 lines)
Write-Host "`n=== Last logs (api, grafana, prometheus) ==="
foreach ($s in @("grazyna-enterprise-api","grazyna_50-grafana-1","grazyna_50-prometheus-1")) {
    Write-Host "`n--- $s ---"
    docker logs --tail 200 $s 2>&1 | Out-Host
}

# 5. Health endpoint inside container (if host mapping fails)
Write-Host "`n=== Internal container health check ==="
docker exec -it grazyna-enterprise-api curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/health

Write-Host "`nHealthcheck complete" -ForegroundColor Green
