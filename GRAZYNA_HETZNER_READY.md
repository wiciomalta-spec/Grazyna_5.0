# 🚀 GRAŻYNA 5.0 — Redis + IsoForest vs EWMA + Checklist Hetzner

---

## 1. OPTYMALIZACJA REDIS POD KLASTER

### Aktualna konfiguracja Redis
```
Redis: 127.0.0.1:6379 (Docker, bez hasła w dev)
Użycie: fallback mode w workerach, IsoForest metrics
```

### Konfiguracja Redis dla klastra produkcyjnego

```bash
# redis.conf (produkcja)
maxmemory 256mb
maxmemory-policy allkeys-lru      # usuń najstarsze klucze gdy pełny
save 900 1                         # snapshot co 15min jeśli ≥1 zmiana
save 300 10                        # snapshot co 5min jeśli ≥10 zmian
appendonly yes                     # AOF dla durability
appendfsync everysec               # flush co sekundę (kompromis)
tcp-keepalive 300
timeout 0
hz 20                              # częstsze sprawdzanie (domyślnie 10)
lazyfree-lazy-eviction yes         # async eviction (nie blokuje)
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes

# Dla klastra 4 workerów:
databases 4                        # 1 DB per worker (izolacja)
# Worker 0 → DB 0, Worker 1 → DB 1, itd.
```

### Optymalne klucze Redis dla GRAŻYNA 5.0

```typescript
// Strategia kluczy — minimalizuj rozmiar, maksymalizuj TTL
const REDIS_CONFIG = {
  // Metryki workerów — krótki TTL (dane świeże)
  workerMetrics: { ttl: 30,   maxSize: '1KB'  },
  // Historia klastra — średni TTL
  clusterHistory:{ ttl: 3600, maxSize: '50KB' },
  // IsoForest wyniki — krótki TTL
  isoResult:     { ttl: 60,   maxSize: '2KB'  },
  // Alerty — długi TTL
  alerts:        { ttl: 86400,maxSize: '100KB'},
  // JWT blacklist — TTL = czas wygaśnięcia tokenu (15min)
  jwtBlacklist:  { ttl: 900,  maxSize: '1KB'  },
  // Session cache — TTL = session TTL
  sessions:      { ttl: 3600, maxSize: '2KB'  },
  // Rate limiting — krótki TTL
  rateLimit:     { ttl: 900,  maxSize: '100B' },
};
```

### Redis Pipeline — batch operacje (3× szybszy)

```typescript
// ❌ Wolno — 4 osobne round-trips
await redis.set('key1', 'val1');
await redis.set('key2', 'val2');
await redis.incr('counter');
await redis.expire('key1', 30);

// ✅ Szybko — 1 round-trip (pipeline)
const pipeline = redis.multi();
pipeline.set('key1', 'val1');
pipeline.set('key2', 'val2');
pipeline.incr('counter');
pipeline.expire('key1', 30);
await pipeline.exec();
```

### Redis Cluster vs Redis Sentinel

```
Twój klaster (4 workers, 1 serwer):
  → Redis Standalone wystarczy
  → Sentinel: HA dla 2+ serwerów
  → Redis Cluster: sharding dla >50GB danych

REKOMENDACJA: Redis Standalone + AOF + backup co godzinę
```

---

## 2. ISOLATION FOREST vs EWMA — PORÓWNANIE PRAKTYCZNE

### Dane z Twojej sesji

```
Sesja 1: EL Lag max = 869ms (spike przy starcie)
Sesja 2: EL Lag max = 35ms  (po naprawie)
Heap:    91.1% → 83.6%      (po optymalizacji)
```

### Jak każdy algorytm zachowałby się przy spike 869ms?

```
Historia EL max: [35, 28, 42, 31, 30, 35, 869, 35, 30]
                                          ↑ spike

EWMA (α=0.3):
  Przed spike: EWMA ≈ 33ms
  Po spike:    EWMA = 0.3×869 + 0.7×33 = 260ms + 23ms = 283ms
  AnomalyScore = |869 - 33| / std(5.1) = 163.9 >> 2.5
  ✅ WYKRYTY natychmiast (1 próbka)
  Czas reakcji: <1s

Isolation Forest (100 drzew):
  Wymaga min. 20 próbek do treningu
  Po treningu: score(869ms) ≈ 0.89 > 0.65
  ✅ WYKRYTY (po zebraniu historii)
  Czas reakcji: ~3-5 minut (zbieranie danych)

Z-Score:
  Z = (869 - 33) / 5.1 = 163.9
  ✅ WYKRYTY natychmiast
  Czas reakcji: <1s
```

### Porównanie na Twoich metrykach

| Scenariusz | EWMA | Z-Score | IsoForest | Regresja |
|---|---|---|---|---|
| **Spike EL 869ms** | ✅ Natychmiast | ✅ Natychmiast | ⚠️ Po 3min | ❌ Nie |
| **Heap trend 91%→95%** | ⚠️ Częściowo | ❌ Nie | ⚠️ Częściowo | ✅ TTT |
| **Wielowymiarowa anomalia** | ❌ Per metryka | ❌ Per metryka | ✅ Tak | ❌ Nie |
| **Worker X anomalny** | ❌ Nie | ❌ Nie | ✅ Per worker | ❌ Nie |
| **Fałszywe alarmy** | Niskie | Niskie | Średnie | Niskie |
| **Dane treningowe** | 3+ próbek | 5+ próbek | 20+ próbek | 5+ próbek |
| **CPU overhead** | <0.1ms | <0.1ms | ~1ms | <0.1ms |
| **Redis wymagany** | ❌ | ❌ | ✅ (distributed) | ❌ |

### Rekomendacja: używaj obu razem

```
EWMA + Z-Score → wykrywanie spików (natychmiastowe)
IsoForest      → wykrywanie wielowymiarowych anomalii (po 3min)
Regresja       → predykcja TTT (Time To Threshold)

Twój GRAZYNA_ML_CLUSTER_PREDICT.ps1 już to robi! ✅
```

### Wyniki praktyczne z Twojego systemu

```
Failure Probability przy aktualnych metrykach:
  Heap 83.6%:  → +0%  (próg 90%)
  EL max 35ms: → +0%  (próg 200ms)
  GC Major 0:  → +0%
  EWMA normal: → +0%
  IsoScore ~0.2→ +0%  (próg 0.6)
  ─────────────────────
  TOTAL: ~5-10% ← BEZPIECZNY ✅

Przy spike 869ms (jak w sesji 1):
  EL max 869ms: → +30% (>500ms)
  EWMA anomalia:→ +10%
  Z-Score >3σ:  → +5%
  IsoScore >0.8:→ +10%
  ─────────────────────
  TOTAL: ~55% ← OSTRZEŻENIE ⚠️
```

---

## 3. CHECKLIST GOTOWOŚCI NA HETZNER

### PRE-DEPLOY (lokalnie)

```powershell
# Uruchom przed deployem na Hetzner

$proj = "E:\Grazyna_5.0"
$backend = "$proj\backend"
$errors = @()

Write-Host "=== CHECKLIST HETZNER ===" -ForegroundColor Cyan

# 1. Testy backendu
Write-Host "[ 1 ] Testy..." -ForegroundColor Yellow
$testOut = cmd /c "cd /d `"$backend`" && node_modules\.bin\prisma.cmd validate 2>&1"
if ($testOut -match "error") { $errors += "Prisma schema błąd" }
else { Write-Host "  ✅ Prisma schema OK" -ForegroundColor Green }

# 2. Build TypeScript
Write-Host "[ 2 ] TypeScript build..." -ForegroundColor Yellow
$buildOut = cmd /c "cd /d `"$backend`" && node_modules\.bin\tsc.cmd --noEmit 2>&1"
if ($buildOut -match "error TS") { $errors += "TypeScript błędy: $buildOut" }
else { Write-Host "  ✅ TypeScript OK" -ForegroundColor Green }

# 3. npm audit
Write-Host "[ 3 ] Security audit..." -ForegroundColor Yellow
$auditOut = cmd /c "cd /d `"$backend`" && node_modules\.bin\npm.cmd audit --audit-level=high 2>&1"
if ($auditOut -match "high|critical") { Write-Host "  ⚠️  Vulnerabilities znalezione" -ForegroundColor Yellow }
else { Write-Host "  ✅ Brak krytycznych vulnerabilities" -ForegroundColor Green }

# 4. JWT_SECRET siła
Write-Host "[ 4 ] JWT_SECRET..." -ForegroundColor Yellow
$jwtSecret = (Get-Content "$backend\.env" | Select-String "JWT_SECRET=").Line -replace "JWT_SECRET=",""
if ($jwtSecret.Length -lt 32) { $errors += "JWT_SECRET za krótki (<32 znaków)" }
else { Write-Host "  ✅ JWT_SECRET OK ($($jwtSecret.Length) znaków)" -ForegroundColor Green }

# 5. CORS_ORIGIN
Write-Host "[ 5 ] CORS_ORIGIN..." -ForegroundColor Yellow
$cors = (Get-Content "$backend\.env" | Select-String "CORS_ORIGIN=").Line
if ($cors -match "localhost") { Write-Host "  ⚠️  CORS_ORIGIN wskazuje na localhost — zmień na domenę!" -ForegroundColor Yellow }
else { Write-Host "  ✅ CORS_ORIGIN OK" -ForegroundColor Green }

# 6. NODE_ENV
Write-Host "[ 6 ] NODE_ENV..." -ForegroundColor Yellow
$nodeEnv = (Get-Content "$backend\.env" | Select-String "NODE_ENV=").Line
if ($nodeEnv -match "development") { Write-Host "  ⚠️  NODE_ENV=development — zmień na production!" -ForegroundColor Yellow }
else { Write-Host "  ✅ NODE_ENV OK" -ForegroundColor Green }

# 7. Frontend build
Write-Host "[ 7 ] Frontend build..." -ForegroundColor Yellow
if (Test-Path "$proj\frontend\dist") {
    $distAge = (Get-Item "$proj\frontend\dist").LastWriteTime
    Write-Host "  ✅ dist/ istnieje ($(($distAge).ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Brak frontend/dist — uruchom: npm run build" -ForegroundColor Yellow
    $errors += "Brak frontend build"
}

# 8. Git status
Write-Host "[ 8 ] Git status..." -ForegroundColor Yellow
Push-Location $proj
$gitStatus = git status --short 2>&1
$gitCommit = git rev-parse --short HEAD 2>&1
Pop-Location
if ($gitStatus) { Write-Host "  ⚠️  Niezatwierdzone zmiany: $($gitStatus.Count) plików" -ForegroundColor Yellow }
else { Write-Host "  ✅ Git clean ($gitCommit)" -ForegroundColor Green }

# 9. Docker Compose prod
Write-Host "[ 9 ] Docker Compose prod..." -ForegroundColor Yellow
if (Test-Path "$proj\docker-compose.prod.yml") {
    Write-Host "  ✅ docker-compose.prod.yml istnieje" -ForegroundColor Green
} else { $errors += "Brak docker-compose.prod.yml" }

# 10. Prisma schema (postgresql)
Write-Host "[ 10 ] Prisma provider..." -ForegroundColor Yellow
$provider = (Get-Content "$backend\prisma\schema.prisma" | Select-String "provider").Line
if ($provider -match "sqlite") {
    Write-Host "  ⚠️  Provider=sqlite — zmień na postgresql przed deployem!" -ForegroundColor Yellow
} else { Write-Host "  ✅ Provider OK" -ForegroundColor Green }

# WYNIK
Write-Host ""
if ($errors.Count -eq 0) {
    Write-Host "✅ GOTOWY NA HETZNER!" -ForegroundColor Green
} else {
    Write-Host "❌ NIE GOTOWY — napraw:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  ❌ $_" -ForegroundColor Red }
}
```

### HETZNER SETUP (na serwerze)

```bash
#!/bin/bash
# Uruchom na świeżym Hetzner CX21 (Ubuntu 24.04)

# 1. Aktualizacja systemu
apt update && apt upgrade -y

# 2. Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker $USER

# 3. Docker Compose
apt install docker-compose-plugin -y

# 4. Nginx + Certbot
apt install nginx certbot python3-certbot-nginx -y

# 5. Utwórz użytkownika deploy
useradd -m -s /bin/bash deploy
usermod -aG docker deploy

# 6. Klonuj repo
mkdir -p /opt/grazyna
cd /opt/grazyna
git clone https://github.com/wiciomalta-spec/Grazyna_5.0.git .

# 7. Utwórz .env.production
cat > backend/.env << 'EOF'
NODE_ENV=production
PORT=3001
DATABASE_URL=postgresql://postgres:[PASS]@db.[PROJECT].supabase.co:5432/postgres
REDIS_URL=redis://:password@localhost:6379
JWT_SECRET=[WYGENERUJ: openssl rand -base64 32]
CORS_ORIGIN=https://twoja-domena.pl
LOG_LEVEL=warn
NODE_OPTIONS=--max-old-space-size=512
UV_THREADPOOL_SIZE=16
EOF

# 8. Start
docker-compose -f docker-compose.prod.yml up -d

# 9. SSL
certbot --nginx -d twoja-domena.pl -d api.twoja-domena.pl

# 10. Weryfikacja
curl https://api.twoja-domena.pl/health
```

### Nginx Config dla GRAŻYNA 5.0

```nginx
# /etc/nginx/conf.d/grazyna.conf

upstream backend {
    server localhost:3001;
    keepalive 32;
}

server {
    listen 80;
    server_name api.twoja-domena.pl;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.twoja-domena.pl;

    ssl_certificate     /etc/letsencrypt/live/api.twoja-domena.pl/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.twoja-domena.pl/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000" always;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
    limit_req zone=api burst=20 nodelay;

    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 60s;
    }

    # WebSocket dla Socket.io
    location /socket.io/ {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Metrics — tylko z localhost
    location /metrics {
        allow 127.0.0.1;
        deny all;
        proxy_pass http://backend;
    }
}

server {
    listen 443 ssl http2;
    server_name twoja-domena.pl;

    ssl_certificate     /etc/letsencrypt/live/twoja-domena.pl/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/twoja-domena.pl/privkey.pem;

    root /opt/grazyna/frontend/dist;
    index index.html;

    # Gzip
    gzip on;
    gzip_types text/plain application/javascript application/json text/css;
    gzip_min_length 1000;

    location / {
        try_files $uri $uri/ /index.html;
        expires 1h;
    }

    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### Monitoring na Hetzner

```bash
# Cron jobs (crontab -e)

# Backup bazy co godzinę
0 * * * * docker exec grazyna_postgres pg_dump -U grazyna grazyna_db | gzip > /backups/db-$(date +\%Y\%m\%d-\%H).sql.gz

# Usuń stare backupy (>7 dni)
0 2 * * * find /backups -name "*.sql.gz" -mtime +7 -delete

# Health check co 5 minut
*/5 * * * * curl -sf https://api.twoja-domena.pl/health || echo "ALERT: Backend down" | mail -s "GRAŻYNA DOWN" admin@twoja-domena.pl

# Certbot renewal
0 12 * * * certbot renew --quiet
```

---

## Podsumowanie gotowości

```
LOKALNIE (DEV):
  ✅ Backend :3001 działa
  ✅ Frontend :5173 działa
  ✅ SQLite dev.db zsync
  ✅ Redis :6379 działa
  ✅ Cluster 4 workers
  ✅ Worker Threads 8 total
  ✅ ML Predictor gotowy
  ✅ Git e9aed43 → main

DO ZROBIENIA PRZED HETZNER:
  □ Zmień provider na postgresql
  □ Utwórz konto Supabase
  □ Wygeneruj nowy JWT_SECRET (openssl rand -base64 32)
  □ Zmień CORS_ORIGIN na domenę
  □ NODE_ENV=production
  □ npm run build (frontend)
  □ Uruchom checklist PS1 powyżej
```
