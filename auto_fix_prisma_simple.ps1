# auto_fix_prisma_simple.ps1
Set-StrictMode -Version Latest
$ProjectRoot = "E:\Grazyna_5.0"
Set-Location $ProjectRoot

$ReportsDir = Join-Path $ProjectRoot "monitor-reports"
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null

# Choose strategy: "A" = OpenSSL 3 (recommended), "B" = libssl1.1
$Strategy = "A"

# Backup originals
Copy-Item -Path ".\backend\Dockerfile" -Destination ".\backend\Dockerfile.pre_auto_fix.bak_$(Get-Date -Format yyyyMMddHHmmss)" -ErrorAction SilentlyContinue
Copy-Item -Path ".\backend\prisma\schema.prisma" -Destination ".\backend\prisma\schema.prisma.pre_auto_fix.bak_$(Get-Date -Format yyyyMMddHHmmss)" -ErrorAction SilentlyContinue

# Prepare new schema content (A = debian-openssl-3.0.x)
$SchemaA = @'
generator client {
  provider = "prisma-client-js"
  binaryTargets = ["native", "linux-musl", "debian-openssl-3.0.x"]
}
'@

# Prepare Dockerfile content (Debian runtime with libssl3)
$DockerfileA = @'
FROM node:20-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl build-essential git && rm -rf /var/lib/apt/lists/*
COPY package*.json package-lock.json ./
COPY prisma ./prisma/
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
RUN npm ci --no-audit --no-fund
RUN npx prisma generate --schema=./prisma/schema.prisma
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:20-slim AS runtime
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates libssl3 && rm -rf /var/lib/apt/lists/*
COPY package*.json package-lock.json ./
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
RUN npm ci --omit=dev --no-audit --no-fund
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/dist ./dist
EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 CMD wget --no-verbose --tries=1 --spider http://localhost:3001/api/health || exit 1
CMD ["node","dist/index.js"]
'@

# If you prefer libssl1.1 (Strategy B), adjust contents here (not recommended unless necessary)
$DockerfileB = @'
FROM node:20-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl build-essential git && rm -rf /var/lib/apt/lists/*
COPY package*.json package-lock.json ./
COPY prisma ./prisma/
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
RUN npm ci --no-audit --no-fund
RUN npx prisma generate --schema=./prisma/schema.prisma
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:20-slim AS runtime
WORKDIR /app
# try to install libssl1.1; may fail on newer distros
RUN apt-get update && apt-get install -y --no-install-recommends libssl1.1 openssl ca-certificates || true && rm -rf /var/lib/apt/lists/*
COPY package*.json package-lock.json ./
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
RUN npm ci --omit=dev --no-audit --no-fund
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/dist ./dist
EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 CMD wget --no-verbose --tries=1 --spider http://localhost:3001/api/health || exit 1
CMD ["node","dist/index.js"]
'@

# Apply chosen strategy by writing files directly
if ($Strategy -eq "A") {
    $SchemaA | Set-Content -Path ".\backend\prisma\schema.prisma" -Encoding UTF8
    $DockerfileA | Set-Content -Path ".\backend\Dockerfile" -Encoding UTF8
    Write-Host "Applied strategy A: schema + Dockerfile updated (libssl3)."
} else {
    $SchemaA | Set-Content -Path ".\backend\prisma\schema.prisma" -Encoding UTF8
    $DockerfileB | Set-Content -Path ".\backend\Dockerfile" -Encoding UTF8
    Write-Host "Applied strategy B: schema + Dockerfile updated (libssl1.1 attempt)."
}

# Remove problematic node_modules volume if exists
docker compose -f docker-compose.prod.yml down
$vols = docker volume ls --format "{{.Name}}"
if ($vols -match "backend-node-modules") {
    Write-Host "Removing volume backend-node-modules"
    docker volume rm backend-node-modules -f | Out-Null
}

# Build and capture logs
$buildLog = Join-Path $ReportsDir "build_after_patch.log"
docker compose -f docker-compose.prod.yml build --no-cache backend 2>&1 | Tee-Object -FilePath $buildLog

# Save tail and full logs
Get-Content $buildLog -Tail 200 | Out-File -FilePath (Join-Path $ReportsDir "build_after_patch.tail.log") -Encoding UTF8
Get-Content $buildLog | Out-File -FilePath (Join-Path $ReportsDir "build_after_patch.full.log") -Encoding UTF8

# Try to start backend and capture runtime logs
docker compose -f docker-compose.prod.yml up -d backend
Start-Sleep -Seconds 4
$cid = docker compose -f docker-compose.prod.yml ps -q backend
if ($cid) {
    docker logs --tail 200 $cid 2>&1 | Tee-Object -FilePath (Join-Path $ReportsDir "runtime_after_patch.log")
} else {
    docker compose -f docker-compose.prod.yml ps | Out-File -FilePath (Join-Path $ReportsDir "compose_ps_after_patch.log")
}

Write-Host "Done. Reports saved to: $ReportsDir"