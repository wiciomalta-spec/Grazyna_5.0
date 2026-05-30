# 🚀 GRAŻYNA 5.0 — Plan Migracji do Produkcji

## Aktualny stan (DEV)
```
✅ Backend:   Node.js + Express + Cluster (4 workers)
✅ Frontend:  React + Vite → http://localhost:5173
✅ DB:        SQLite (dev.db)
✅ Redis:     Docker :6379
✅ Auth:      JWT + Refresh Token
✅ Workers:   Worker Threads (tasks.worker.cjs)
✅ Monitor:   ML Predictor + Watchdog
✅ Git:       2bf7a25 → github.com/wiciomalta-spec/Grazyna_5.0
```

---

## Benchmark Klastra — Przed i Po Optymalizacji

### Metryki zebrane podczas sesji

| Metryka | Sesja 1 (przed) | Sesja 2 (po fix) | Sesja 3 (po optymalizacji) | Zmiana |
|---|---|---|---|---|
| EL Lag current | 19.0ms | 1.58ms | 1.58ms | **-92%** ✅ |
| EL Lag max | 869ms | 35ms | 35ms | **-96%** ✅ |
| EL Lag p99 | 24.8ms | 29.9ms | 29.9ms | +20% ⚠️ |
| Heap % | 93.8% | 91.1% | 83.6% | **-11%** ✅ |
| RSS | 60.3MB | 63.6MB | 86.4MB | +43% (cluster×4) |
| GET /health | 404 | 200 (2.28ms) | 200 (<1ms) | **NAPRAWIONE** ✅ |
| GET /api | 862ms | 2.5ms | 2.5ms | **-99.7%** ✅ |
| Cluster workers | 0 | 3 | 4 (AI scale) | **+4** ✅ |
| Worker Threads | 0 | 2 | 2×4=8 | **+8** ✅ |
| GC Minor | 5× | 26× | ~20× | normalny |
| GC Major | 0× | 1× | 0× | ✅ |

### Wnioski z benchmarku
```
✅ Największa poprawa: EL Lag 869ms → 35ms (-96%)
✅ Routing naprawiony: /health 404 → 200, /api 862ms → 2.5ms
✅ Heap stabilizacja: 93.8% → 83.6% (--max-old-space-size=256)
⚠️  RSS wzrósł: 60MB → 86MB (normalny wzrost przy 4 workerach)
⚠️  EL p99 lekko wzrósł: 24.8ms → 29.9ms (socket.io overhead)
```

---

## Plan Migracji do Produkcji (5 faz)

### FAZA 1: Infrastruktura (Tydzień 1)

```
Wybór hostingu:
  Opcja A: VPS (DigitalOcean/Hetzner) — ~$20/mies
    + Pełna kontrola
    + Tańszy przy dużym ruchu
    - Wymaga konfiguracji

  Opcja B: Railway.app — ~$5-20/mies
    + Zero DevOps
    + Auto-deploy z GitHub
    - Mniej kontroli

  Opcja C: Render.com — darmowy tier
    + Zero kosztów na start
    - Sleep po 15min bezczynności

REKOMENDACJA: Hetzner CX21 (2 CPU, 4GB RAM, 40GB SSD) = €4.35/mies
```

```powershell
# Sprawdź wymagania sprzętowe
# Backend (4 workers × ~22MB): ~88MB RAM
# Frontend (nginx): ~10MB RAM
# PostgreSQL: ~50MB RAM
# Redis: ~10MB RAM
# TOTAL: ~160MB RAM → Hetzner CX21 (4GB) wystarczy z zapasem
```

### FAZA 2: Baza Danych PostgreSQL (Tydzień 1)

```powershell
# Opcja A: Supabase (darmowy tier)
# 1. Utwórz konto: supabase.com
# 2. New Project → pobierz DATABASE_URL
# 3. Zaktualizuj schema.prisma

$schema = "E:\Grazyna_5.0\backend\prisma\schema.prisma"
$sc = Get-Content $schema -Raw

# Zmień provider
$sc = $sc -replace 'provider = "sqlite"', 'provider = "postgresql"'
$sc = $sc -replace 'url\s*=\s*"file:./dev.db"', 'url = env("DATABASE_URL")'

# Przywróć typy PostgreSQL (Json, enum)
# (użyj backup schema.prisma.bak_* jako referencji)

$sc | Out-File $schema -Encoding UTF8

# Migracja
$env:DATABASE_URL = "postgresql://postgres:[PASS]@db.[PROJECT].supabase.co:5432/postgres"
cmd /c "cd /d E:\Grazyna_5.0\backend && node_modules\.bin\prisma.cmd migrate dev --name prod_init"
```

### FAZA 3: Zmienne Środowiskowe Produkcyjne

```bash
# backend/.env.production
NODE_ENV=production
PORT=3001
DATABASE_URL=postgresql://grazyna:[PASS]@db.[PROJECT].supabase.co:5432/postgres
REDIS_URL=redis://:[PASS]@redis-host:6379
JWT_SECRET=[256-bit-random-secret]
CORS_ORIGIN=https://grazyna.twoja-domena.pl
LOG_LEVEL=warn
NODE_OPTIONS=--max-old-space-size=512
UV_THREADPOOL_SIZE=16

# frontend/.env.production
VITE_API_URL=https://api.grazyna.twoja-domena.pl/api
VITE_WS_URL=wss://api.grazyna.twoja-domena.pl
VITE_APP_NAME=GRAŻYNA 5.0
VITE_APP_VERSION=5.0.0
VITE_ENV=production
VITE_DEBUG=false
```

### FAZA 4: Docker Compose Produkcyjny

```yaml
# docker-compose.prod.yml (zaktualizowany)
version: '3.9'

services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
      - CORS_ORIGIN=${CORS_ORIGIN}
      - NODE_OPTIONS=--max-old-space-size=512
    ports:
      - "3001:3001"
    depends_on:
      redis:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '2'

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - backend
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 128mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./certbot/conf:/etc/letsencrypt
    depends_on:
      - backend
      - frontend
    restart: unless-stopped

volumes:
  redis_data:
```

### FAZA 5: CI/CD Auto-Deploy (GitHub Actions)

```yaml
# .github/workflows/deploy-prod.yml
name: Deploy Production

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build & Test
        run: |
          cd backend && npm ci && npm test
          cd ../frontend && npm ci && npm run build

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.PROD_HOST }}
          username: deploy
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/grazyna
            git pull origin main
            docker-compose -f docker-compose.prod.yml pull
            docker-compose -f docker-compose.prod.yml up -d --no-deps backend
            sleep 10
            curl -f http://localhost:3001/health || exit 1
            docker-compose -f docker-compose.prod.yml up -d --no-deps frontend nginx
            echo "✅ Deploy OK: $(date)"
```

---

## Checklist Migracji

```
INFRASTRUKTURA:
  □ Wybierz hosting (Hetzner CX21 rekomendowany)
  □ Skonfiguruj domenę + SSL (Let's Encrypt)
  □ Skonfiguruj firewall (tylko 80, 443, 22)

BAZA DANYCH:
  □ Utwórz konto Supabase/Neon
  □ Zaktualizuj schema.prisma (postgresql)
  □ Uruchom prisma migrate deploy
  □ Zweryfikuj dane testowe

BEZPIECZEŃSTWO:
  □ Wygeneruj nowy JWT_SECRET (256-bit)
  □ Ustaw CORS_ORIGIN na domenę produkcyjną
  □ Włącz rate limiting (express-rate-limit)
  □ Skonfiguruj helmet.js
  □ Włącz HTTPS (certbot)
  □ Ustaw SameSite=Strict dla cookies

MONITORING:
  □ Skonfiguruj Grafana + Prometheus
  □ Uruchom ML Predictor
  □ Skonfiguruj alerty (email/Slack)
  □ Ustaw backup bazy (cron + pg_dump)

WYDAJNOŚĆ:
  □ NODE_OPTIONS=--max-old-space-size=512
  □ Cluster workers = liczba CPU cores
  □ Redis maxmemory=128mb
  □ Nginx gzip compression
  □ Frontend build (vite build)

TESTY:
  □ Load test (k6 lub Artillery)
  □ Security scan (npm audit)
  □ Health check po deploy
  □ Rollback plan gotowy
```

---

## Szacowane koszty miesięczne

| Usługa | Tier | Koszt |
|---|---|---|
| Hetzner CX21 | 2 CPU, 4GB | €4.35 |
| Supabase | Free (500MB) | $0 |
| Redis (self-hosted) | Na VPS | $0 |
| Domena | .pl | ~$5 |
| **TOTAL** | | **~$10/mies** |

---

## Harmonogram

```
Tydzień 1: Infrastruktura + PostgreSQL + SSL
Tydzień 2: CI/CD + testy + monitoring
Tydzień 3: Load testing + security audit
Tydzień 4: Go-live + monitoring 24/7
```