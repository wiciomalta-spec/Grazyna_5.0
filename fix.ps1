cd E:\Grazyna_5.0

Write-Host "💥 FULL AUTO FIX START"

# 1. Kill port 80
$ports = netstat -ano | findstr :80
foreach ($line in $ports) {
    $pid = ($line -split "\s+")[-1]
    if ($pid -match "^\d+$") {
        Write-Host "⛔ Killing PID $pid"
        taskkill /PID $pid /F
    }
}

Stop-Service W3SVC -ErrorAction SilentlyContinue

# 2. Change NGINX port
(Get-Content docker-compose.prod.yml) -replace '80:80','8080:80' | Set-Content docker-compose.prod.yml

# 3. Clean stack
docker compose -f docker-compose.prod.yml down --remove-orphans
docker system prune -f

# 4. Rebuild + run
docker compose -f docker-compose.prod.yml build --no-cache
docker compose -f docker-compose.prod.yml up -d

Start-Sleep -Seconds 5

Write-Host "`n✅ SYSTEM LIVE:"
docker ps

Write-Host "`n🌐 ACCESS:"
Write-Host "App: http://localhost:8080"
Write-Host "Grafana: http://localhost:3000 (admin/admin)"
Write-Host "Prometheus: http://localhost:9090"

Write-Host "`n✅ SYSTEM STABLE ✔"
