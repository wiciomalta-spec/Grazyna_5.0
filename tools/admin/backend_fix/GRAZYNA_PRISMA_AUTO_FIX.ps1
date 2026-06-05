# auto_fix_prisma.ps1
# Uruchom w E:\Grazyna_5.0
Set-StrictMode -Version Latest
$ProjectRoot = "E:\Grazyna_5.0"
Set-Location $ProjectRoot

# --- Konfiguracja ---
$Strategy = "A"   # "A" = debian-openssl-3.0.x (zalecane), "B" = libssl1.1
$MaxAttempts = 6
$SleepBetweenAttemptsSec = 6
$ReportsDir = Join-Path $ProjectRoot "monitor-reports"
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null

# --- Patchy (inline) ---
$PatchDockerfileDebian = @"
*** Begin Patch
*** Update File: backend/Dockerfile
@@
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
 # runtime libs
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
*** End Patch
"@

$PatchDockerfileLibssl11 = @"
*** Begin Patch
*** Update File: backend/Dockerfile
@@
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
 # runtime libs (libssl1.1)
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
*** End Patch
"@

$PatchSchemaA = @"
*** Begin Patch
*** Update File: backend/prisma/schema.prisma
@@
 generator client {
   provider = "prisma-client-js"
-  binaryTargets = ["native", "linux-musl", "debian-openssl-1.1.x"]
+  binaryTargets = ["native", "linux-musl", "debian-openssl-3.0.x"]
 }
*** End Patch
"@

$PatchSchemaB = @"
*** Begin Patch
*** Update File: backend/prisma/schema.prisma
@@
 generator client {
   provider = "prisma-client-js"
-  binaryTargets = ["native", "linux-musl", "debian-openssl-1.1.x"]
+  binaryTargets = ["native", "linux-musl", "debian-openssl-1.1.x"]
 }
*** End Patch
"@

# --- Helpers ---
function Write-Report($name, $text) {
    $path = Join-Path $ReportsDir $name
    $text | Out-File -FilePath $path -Encoding UTF8
    Write-Host "Wrote report: $path"
}

function Apply-PatchText($patchText) {
    # Create a temporary patch file and apply with git apply if repo exists, otherwise overwrite files directly
    $tmp = Join-Path $env:TEMP ("patch_" + [guid]::NewGuid().ToString() + ".diff")
    $patchText | Out-File -FilePath $tmp -Encoding UTF8
    if (Test-Path ".git") {
        git apply $tmp
        if ($LASTEXITCODE -ne 0) { throw "git apply failed" }
    } else {
        # fallback: attempt to parse and write minimal changes (simple replace for schema and Dockerfile)
        if ($patchText -match "Update File: backend/prisma/schema.prisma") {
            # replace generator block
            $schemaPath = Join-Path $ProjectRoot "backend\prisma\schema.prisma"
            (Get-Content $schemaPath) -replace 'generator client \{[\s\S]*?\}' , 'generator client {`n  provider = "prisma-client-js"`n  binaryTargets = ["native", "linux-musl", "debian-openssl-3.0.x"]`n}' | Set-Content $schemaPath
        } elseif ($patchText -match "Update File: backend/Dockerfile") {
            # overwrite Dockerfile with recommended runtime (simple approach)
            $dockerfilePath = Join-Path $ProjectRoot "backend\Dockerfile"
            $newContent = @"
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
"@
            $newContent | Set-Content -Path $dockerfilePath -Encoding UTF8
        }
    }
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}

# --- Main loop ---
$attempt = 0
while ($attempt -lt $MaxAttempts) {
    $attempt++
    Write-Host "Attempt $attempt / $MaxAttempts - $(Get-Date -Format o)"

    # 1) backup important files
    Copy-Item -Path ".\backend\Dockerfile" -Destination ".\backend\Dockerfile.bak_$((Get-Date).ToString('yyyyMMddHHmmss'))" -ErrorAction SilentlyContinue
    Copy-Item -Path ".\backend\prisma\schema.prisma" -Destination ".\backend\prisma\schema.prisma.bak_$((Get-Date).ToString('yyyyMMddHHmmss'))" -ErrorAction SilentlyContinue

    # 2) choose patch
    if ($Strategy -eq "A") {
        Write-Host "Applying strategy A (OpenSSL 3 / debian-openssl-3.0.x)"
        Apply-PatchText $PatchSchemaA
        Apply-PatchText $PatchDockerfileDebian
    } else {
        Write-Host "Applying strategy B (libssl1.1)"
        Apply-PatchText $PatchSchemaB
        Apply-PatchText $PatchDockerfileLibssl11
    }

    # 3) remove problematic node_modules volume if exists (safe attempt)
    docker compose -f docker-compose.prod.yml down
    $vols = docker volume ls --format "{{.Name}}"
    if ($vols -match "backend-node-modules") {
        Write-Host "Removing volume backend-node-modules"
        docker volume rm backend-node-modules -f | Out-Null
    }

    # 4) build backend (capture output)
    $buildLog = Join-Path $ReportsDir ("build_attempt_$attempt.log")
    docker compose -f docker-compose.prod.yml build --no-cache backend 2>&1 | Tee-Object -FilePath $buildLog

    # 5) analyze build log for errors
    $logTail = Get-Content $buildLog -Tail 200 -ErrorAction SilentlyContinue
    $logText = ($logTail -join "`n")
    Write-Report ("build_attempt_$attempt.tail.log") $logText

    if ($logText -match "PrismaClientInitializationError" -or $logText -match "libssl.so.1.1" -or $logText -match "libssl.so.3" -or $logText -match "Unknown binary target") {
        Write-Host "Detected Prisma / libssl related error in build logs."
        # save full build log
        Get-Content $buildLog | Out-File -FilePath (Join-Path $ReportsDir ("build_attempt_$attempt.full.log")) -Encoding UTF8
        # attempt to start container to capture runtime logs
        docker compose -f docker-compose.prod.yml up -d backend
        Start-Sleep -Seconds 3
        $cid = docker compose -f docker-compose.prod.yml ps -q backend
        if ($cid) {
            docker logs --tail 200 $cid 2>&1 | Tee-Object -FilePath (Join-Path $ReportsDir ("runtime_attempt_$attempt.log"))
        }
        Write-Host "Sleeping $SleepBetweenAttemptsSec seconds before next attempt..."
        Start-Sleep -Seconds $SleepBetweenAttemptsSec
        continue
    } else {
        # build succeeded (no obvious prisma/libssl errors)
        Write-Host "Build appears successful. Starting backend..."
        docker compose -f docker-compose.prod.yml up -d backend
        Start-Sleep -Seconds 3
        $cid = docker compose -f docker-compose.prod.yml ps -q backend
        if ($cid) {
            docker logs --tail 200 $cid 2>&1 | Tee-Object -FilePath (Join-Path $ReportsDir ("runtime_attempt_$attempt.log"))
            Write-Host "Backend container id: $cid"
            Write-Report ("success_attempt_$attempt.txt") "Build and start succeeded on attempt $attempt at $(Get-Date -Format o). See logs."
            break
        } else {
            Write-Host "No backend container id found after start. Check compose ps."
            docker compose -f docker-compose.prod.yml ps | Out-File -FilePath (Join-Path $ReportsDir ("compose_ps_attempt_$attempt.txt"))
            Start-Sleep -Seconds $SleepBetweenAttemptsSec
            continue
        }
    }
}

Write-Host "Auto-fix loop finished. Reports saved to: $ReportsDir"