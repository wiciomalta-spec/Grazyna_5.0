# 📊 GRAŻYNA 5.0 — Single Process vs Cluster + CI/CD Hetzner

## CZĘŚĆ 1: Single Process vs Cluster — Dane z Sesji

### Rzeczywiste metryki zebrane podczas sesji

| Metryka | Sesja 1 Cluster | Sesja 2 Cluster | Sesja 3 Single | Sesja 4 Single |
|---|---|---|---|---|
| **Stabilność** | ❌ Crash po 26s | ❌ Crash po 26s | ✅ 2.2h uptime | ✅ 3600s+ |
| **EL Lag** | 19.0ms | 1.58ms | 2.12ms | 1.58ms |
| **EL Max** | **869ms** 🔴 | 35ms ✅ | 69ms ⚠️ | 35ms ✅ |
| **EL p99** | 24.8ms | 29.9ms | 28.9ms | 24.8ms |
| **Heap %** | 93.8% | 83.6% | 93.2% | 85.0% |
| **RSS** | 60.3MB | 86.4MB | 66.1MB | 60.0MB |
| **GC Minor** | 5× | 26× | 92× | 10× |
| **GC Major** | 0× | 1× | 1× | 0× |
| **Failure Prob** | 50% ⚠️ | 23% ✅ | 28% ✅ | 0% ✅ |
| **k6 errors** | 100% ❌ | 100% ❌ | 0% ✅ | 0% ✅ |
| **k6 RPS** | crash | crash | 394 ✅ | 313 ✅ |

### Analiza przyczyn crashu klastra

```
Root Cause (zidentyfikowany):
  1. EADDRINUSE :4001 — cluster-control port zajęty przy restarcie
  2. Brak uncaughtException handler w cluster-bootstrap.ts
  3. tsx watch + cluster = race condition przy restarcie
  4. Memory pressure pod k6 → GC pause → EL spike → crash

Dlaczego Single Process jest stabilniejszy:
  ✅ Jeden proces = jeden port = brak konfliktów
  ✅ tsx watch restartuje tylko jeden proces
  ✅ Brak IPC overhead między workerami
  ✅ Prostszy error handling
  ❌ Brak izolacji awarii (jeden crash = cały serwer)
  ❌ Nie wykorzystuje wielu CPU cores
```

### Kiedy używać czego

```
DEVELOPMENT:  Single Process (express-server.ts)
              → Stabilny, prosty debug, szybki restart

STAGING:      Single Process + PM2 (1 worker)
              → Testuj jak produkcja bez ryzyka

PRODUKCJA:    PM2 Cluster (N workers = CPU cores)
              → Stabilny cluster, graceful reload
              → NIE tsx watch!
```

### PM2 vs tsx watch w cluster mode

```
tsx watch:
  ❌ Dev tool — nie production-ready
  ❌ Restartuje przy każdej zmianie pliku
  ❌ Brak graceful shutdown
  ❌ Brak log rotation
  ❌ Crash kaskadowy przy EADDRINUSE

PM2:
  ✅ Production process manager
  ✅ Graceful reload (zero downtime)
  ✅ Log rotation wbudowany
  ✅ Monitoring dashboard
  ✅ Auto-restart z exponential backoff
  ✅ Cluster mode stabilny
  ✅ ecosystem.config.js
```

---

## CZĘŚĆ 2: Predykcja Awarii Heap — Wyniki Analizy

### Symulacja trendu (z analizy Python)

```
Próbka  Heap%   TTT→95%      Status
#1      83.6%   ∞ (stabilny) ✅ OK
#3      84.8%   2min 50s     ✅ OK
#7      87.1%   2min 17s     ✅ OK
#12     90.5%   1min 11s     ⚠️ WARN
#14     91.8%   50s          ⚠️ WARN (< 60s!)
#15     92.4%   41s          🔴 KRYT (< 60s!)
#19     94.8%   3s           🔴 KRYT
#20     95.2%   PRZEKROCZONY 🔴 OOM
```

**Kluczowy wniosek:** Przy tempie +0.65%/próbkę (co 10s):
- Alert 60s ahead → przy heap 92.4%
- Alert 5min ahead → przy heap 87.1%

### Progi dla klastra 4 workerów

```
METRYKA          WARN      CRITICAL   OOM
─────────────────────────────────────────
Heap %           >82%      >90%       >95%
EL Lag current   >20ms     >100ms     —
EL Lag max       >50ms     >200ms     —
GC Minor/run     >20×      >50×       —
GC Major/run     >1×       >3×        —
RSS              >150MB    >300MB     —
Failure Prob     >30%      >60%       >80%
TTT→OOM          <5min     <60s       PRZEKROCZONY
```

---

## CZĘŚĆ 3: CI/CD Pipeline dla Hetzner

### Architektura deploymentu

```
GitHub Push → GitHub Actions → Hetzner CX21
                ↓
         Lint + TypeScript
                ↓
         Tests (Vitest)
                ↓
         Build (tsc + vite)
                ↓
         npm audit (0 vuln ✅)
                ↓
         SSH → Hetzner
                ↓
         PM2 reload (zero downtime)
                ↓
         Health check /health
                ↓
         ✅ lub Auto-rollback
```

### ecosystem.config.js (PM2 — stabilny cluster)

```javascript
// E:\Grazyna_5.0\backend\ecosystem.config.js
module.exports = {
  apps: [{
    name:    'grazyna-backend',
    script:  'dist/express-server.js',  // skompilowany JS
    // Cluster mode — stabilny (nie tsx watch!)
    instances:  'max',   // liczba CPU cores
    exec_mode:  'cluster',
    // Memory management
    max_memory_restart: '400M',
    node_args: '--max-old-space-size=512 --expose-gc',
    // Crash recovery z backoff
    restart_delay:  3000,
    max_restarts:   10,
    min_uptime:     '10s',
    // Env
    env: {
      NODE_ENV: 'production',
      PORT:     3001,
    },
    // Logging
    log_file:        'logs/pm2-combined.log',
    error_file:      'logs/pm2-error.log',
    out_file:        'logs/pm2-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    // Monitoring
    pmx: true,
  }],
};
```

### GitHub Actions — Zoptymalizowany CI/CD dla Hetzner

```yaml
# .github/workflows/hetzner-deploy.yml
name: GRAŻYNA 5.0 — Deploy Hetzner

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  NODE_VERSION: '20.11.0'

jobs:
  # ── JOB 1: Quality Gate ──────────────────────────────────
  quality:
    name: 🔍 Quality Gate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: |
            backend/package-lock.json
            frontend/package-lock.json

      - name: Install deps (parallel)
        run: |
          cd backend  && npm ci --prefer-offline &
          cd frontend && npm ci --prefer-offline &
          wait

      - name: TypeScript check
        run: |
          cd backend  && npx tsc --noEmit &
          cd frontend && npx tsc --noEmit &
          wait

      - name: Security audit
        run: |
          cd backend  && npm audit --audit-level=high
          cd frontend && npm audit --audit-level=high

  # ── JOB 2: Build ─────────────────────────────────────────
  build:
    name: 🔨 Build
    runs-on: ubuntu-latest
    needs: quality
    outputs:
      version: ${{ steps.ver.outputs.version }}

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: |
            backend/package-lock.json
            frontend/package-lock.json

      - name: Get version
        id: ver
        run: echo "version=$(node -p "require('./backend/package.json').version")-$(git rev-parse --short HEAD)" >> $GITHUB_OUTPUT

      - name: Build backend
        run: cd backend && npm ci && npm run build
        env:
          NODE_ENV: production

      - name: Build frontend
        run: cd frontend && npm ci && npm run build
        env:
          VITE_API_URL: ${{ secrets.VITE_API_URL }}
          VITE_WS_URL:  ${{ secrets.VITE_WS_URL }}
          VITE_APP_VERSION: ${{ steps.ver.outputs.version }}

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-${{ steps.ver.outputs.version }}
          path: |
            backend/dist/
            frontend/dist/
          retention-days: 7

  # ── JOB 3: Deploy Hetzner ────────────────────────────────
  deploy:
    name: 🚀 Deploy Hetzner
    runs-on: ubuntu-latest
    needs: build
    environment:
      name: production
      url: https://grazyna.twoja-domena.pl

    steps:
      - uses: actions/checkout@v4

      - name: Download artifacts
        uses: actions/download-artifact@v4
        with:
          name: build-${{ needs.build.outputs.version }}

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host:     ${{ secrets.HETZNER_HOST }}
          username: deploy
          key:      ${{ secrets.HETZNER_SSH_KEY }}
          script: |
            set -e
            cd /opt/grazyna

            # 1. Backup DB
            docker exec grazyna_postgres pg_dump -U grazyna grazyna_db \
              > backups/db-$(date +%Y%m%d-%H%M%S).sql 2>/dev/null || true

            # 2. Pull latest
            git pull origin main

            # 3. Install deps
            cd backend && npm ci --production && cd ..

            # 4. Prisma migrate
            cd backend && npx prisma migrate deploy && cd ..

            # 5. PM2 reload (zero downtime!)
            pm2 reload ecosystem.config.js --update-env

            # 6. Health check
            sleep 5
            curl -sf http://localhost:3001/health || exit 1

            echo "✅ Deploy OK: $(date)"

      - name: Extended health check
        run: |
          sleep 10
          # Sprawdź /health
          curl -sf https://grazyna.twoja-domena.pl/health || exit 1
          # Sprawdź metryki
          HEAP=$(curl -sf https://grazyna.twoja-domena.pl/metrics | \
            grep "nodejs_heap_size_used_bytes " | awk '{print $2}')
          echo "Heap used: $HEAP bytes"
          echo "✅ Health check passed"

      - name: Auto-rollback on failure
        if: failure()
        uses: appleboy/ssh-action@v1
        with:
          host:     ${{ secrets.HETZNER_HOST }}
          username: deploy
          key:      ${{ secrets.HETZNER_SSH_KEY }}
          script: |
            cd /opt/grazyna
            git revert HEAD --no-edit
            pm2 reload ecosystem.config.js
            echo "🔙 Rollback executed"
```

### Optymalizacje CI/CD

```yaml
# Szybsze buildy — cache npm
- uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      backend/node_modules
      frontend/node_modules
    key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}

# Równoległe buildy
- name: Build parallel
  run: |
    cd backend  && npm run build &
    cd frontend && npm run build &
    wait

# Tylko deploy gdy zmienił się kod (nie docs)
on:
  push:
    branches: [main]
    paths:
      - 'backend/**'
      - 'frontend/**'
      - '!**/*.md'
      - '!docs/**'
```

### Hetzner Setup Script

```bash
#!/bin/bash
# Uruchom na świeżym Hetzner CX21 (Ubuntu 24.04)

# 1. System
apt update && apt upgrade -y
apt install -y nginx certbot python3-certbot-nginx git curl

# 2. Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# 3. PM2
npm install -g pm2
pm2 startup systemd -u deploy --hp /home/deploy

# 4. Docker (dla PostgreSQL + Redis)
curl -fsSL https://get.docker.com | sh
usermod -aG docker deploy

# 5. Deploy user
useradd -m -s /bin/bash deploy
mkdir -p /opt/grazyna /opt/grazyna/backups /opt/grazyna/logs
chown -R deploy:deploy /opt/grazyna

# 6. Clone repo
su - deploy -c "git clone https://github.com/wiciomalta-spec/Grazyna_5.0.git /opt/grazyna"

# 7. SSL
certbot --nginx -d grazyna.twoja-domena.pl

# 8. Start
su - deploy -c "cd /opt/grazyna/backend && npm ci --production && npm run build"
su - deploy -c "cd /opt/grazyna && pm2 start ecosystem.config.js"
su - deploy -c "pm2 save"

echo "✅ Hetzner setup complete!"
```

---

## Podsumowanie

### Single Process vs Cluster

| | Single Process | PM2 Cluster |
|---|---|---|
| **Dev stability** | ✅ Doskonały | ❌ tsx crash |
| **Prod stability** | ⚠️ Brak izolacji | ✅ Doskonały |
| **CPU utilization** | ❌ 1 core | ✅ N cores |
| **Memory** | ✅ Mniej | ⚠️ N× więcej |
| **Restart** | Prosty | Graceful |
| **Rekomendacja** | DEV | PROD |

### OOM Predictor — Kluczowe wnioski

```
1. Heap 91-94% = BEZPIECZNY przy --max-old-space-size=512
   (Node.js rozszerzy heap automatycznie do 512MB)

2. Alert 60s ahead = heap > 92.4% przy tempie +0.65%/10s

3. EL max 869ms = KRYTYCZNY (był w sesji 1, naprawiony)
   EL max 35ms  = OK (sesja 2+)

4. GC Minor ×92 = normalny przy 2.2h uptime

5. Large Object Space 100% = Prisma DMMF (stały, nie rośnie)

6. Failure Probability sesja 1: 50% (EL 869ms dominuje)
   Failure Probability sesja 2+: 10-28% = BEZPIECZNY
```