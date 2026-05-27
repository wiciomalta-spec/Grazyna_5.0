Set-Location -Path "E:\Grazyna_5.0"

# Backup istniejących plików
If (Test-Path ".\backend\Dockerfile") {
  Copy-Item -Path ".\backend\Dockerfile" -Destination ".\backend\Dockerfile.bak_$(Get-Date -Format yyyyMMddHHmmss)"
}
If (Test-Path ".\backend\prisma\schema.prisma") {
  Copy-Item -Path ".\backend\prisma\schema.prisma" -Destination ".\backend\prisma\schema.prisma.bak_$(Get-Date -Format yyyyMMddHHmmss)"
}
If (Test-Path ".\docker-compose.prod.yml") {
  Copy-Item -Path ".\docker-compose.prod.yml" -Destination ".\docker-compose.prod.yml.bak_$(Get-Date -Format yyyyMMddHHmmss)"
}
If (Test-Path ".\nginx\conf.d\default.conf") {
  Copy-Item -Path ".\nginx\conf.d\default.conf" -Destination ".\nginx\conf.d\default.conf.bak_$(Get-Date -Format yyyyMMddHHmmss)"
}

# Ensure directories exist
New-Item -ItemType Directory -Path ".\nginx\conf.d" -Force | Out-Null
New-Item -ItemType Directory -Path ".\backend\prisma" -Force | Out-Null

# Write files (replace placeholders with actual content if running interactively)
# If you saved files manually, skip the Set-Content steps below.

# Dockerfile
@"
PASTE_DOCKERFILE_CONTENT_HERE
"@ | Set-Content -Path ".\backend\Dockerfile" -Encoding UTF8

# schema.prisma (only generator block replacement recommended)
@"
PASTE_SCHEMA_PRISMA_GENERATOR_BLOCK_HERE
"@ | Out-File -FilePath ".\backend\prisma\schema.prisma" -Encoding UTF8 -Force

# docker-compose
@"
PASTE_DOCKER_COMPOSE_CONTENT_HERE
"@ | Set-Content -Path ".\docker-compose.prod.yml" -Encoding UTF8

# nginx config
@"
PASTE_NGINX_CONF_HERE
"@ | Set-Content -Path ".\nginx\conf.d\default.conf" -Encoding UTF8

# Remove problematic node_modules volume if exists
docker compose -f docker-compose.prod.yml down
# If you created a named volume earlier that hides node_modules, remove it:
docker volume ls | Select-String "backend-node-modules" | ForEach-Object {
  $vol = ($_ -split '\s+')[1]
  docker volume rm $vol -Force
}

# Rebuild backend with no cache
docker compose -f docker-compose.prod.yml build --no-cache backend

# Start services
docker compose -f docker-compose.prod.yml up -d

# Tail backend logs
Start-Sleep -Seconds 3
docker compose -f docker-compose.prod.yml ps
docker logs --tail 200 -f $(docker compose -f docker-compose.prod.yml ps -q backend)
