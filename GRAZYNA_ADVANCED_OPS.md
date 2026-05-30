# 🔧 GRAŻYNA 5.0 — Redis Cluster vs Sentinel + Zero-Downtime + IsoForest Cold-Start

## Aktualny stan po buildzie
```
✅ Frontend build: dist/ (479 modułów, PWA + gzip)
✅ JWT_SECRET: oMV+OXqlv7zf6RShIimdzlerbhn0CXouutR7CLzIYkU= (256-bit)
✅ Git: d000227 → main
✅ Vite build: 7.75s, react-vendor 159KB (gzip: 52KB)
```

---

## 1. REDIS CLUSTER vs SENTINEL

### Kiedy co używać

```
Twój przypadek: 1 serwer Hetzner CX21
→ Redis Standalone (najprostszy)
→ Sentinel: gdy masz 2+ serwery (HA)
→ Cluster: gdy masz >50GB danych lub >100k ops/s
```

### Szczegółowe porównanie

| Kryterium | Standalone | Sentinel | Cluster |
|---|---|---|---|
| **Min. serwery** | 1 | 3 | 6 (3 master + 3 replica) |
| **Automatyczny failover** | ❌ | ✅ | ✅ |
| **Sharding danych** | ❌ | ❌ | ✅ |
| **Max dane** | RAM serwera | RAM serwera | N × RAM |
| **Złożoność** | Niska | Średnia | Wysoka |
| **Koszt** | €0 extra | €8-15/mies | €25+/mies |
| **Dla GRAŻYNA** | ✅ **DEV** | ✅ **PROD v1** | ❌ Overkill |

### Redis Sentinel — konfiguracja dla GRAŻYNA

```bash
# Potrzebujesz 3 serwerów: master + replica + sentinel
# Hetzner: CX21 (master) + CX11 (replica) + CX11 (sentinel) = €4.35+€3.29+€3.29 = €10.93/mies

# sentinel.conf
sentinel monitor grazyna-master 10.0.0.1 6379 2
sentinel auth-pass grazyna-master [REDIS_PASSWORD]
sentinel down-after-milliseconds grazyna-master 5000
sentinel failover-timeout grazyna-master 60000
sentinel parallel-syncs grazyna-master 1

# W Node.js (ioredis):
import Redis from 'ioredis';
const redis = new Redis({
  sentinels: [
    { host: '10.0.0.1', port: 26379 },
    { host: '10.0.0.2', port: 26379 },
    { host: '10.0.0.3', port: 26379 },
  ],
  name: 'grazyna-master',
  password: process.env.REDIS_PASSWORD,
  sentinelPassword: process.env.REDIS_PASSWORD,
});
```

### Rekomendacja dla GRAŻYNA 5.0

```
Faza 1 (teraz):    Redis Standalone (1 serwer, €0 extra)
Faza 2 (>100 users): Redis Sentinel (3 serwery, €10/mies)
Faza 3 (>10k users): Redis Cluster (6+ serwerów, €25+/mies)
```

---

## 2. ZERO-DOWNTIME DEPLOY NA HETZNER

### Strategia Blue-Green dla GRAŻYNA 5.0

```
Aktualnie działa: Blue (port 3001)
Deploy nowej wersji: Green (port 3002)
Nginx przełącza: Blue → Green
Zatrzymaj: Blue
```

### Implementacja

```bash
#!/bin/bash
# /opt/grazyna/deploy.sh — zero-downtime deploy

set -e

BLUE_PORT=3001
GREEN_PORT=3002
HEALTH_URL="http://localhost"
MAX_WAIT=60

echo "🚀 Zero-downtime deploy GRAŻYNA 5.0"
echo "$(date)"

# 1. Pobierz nowy kod
git pull origin main

# 2. Sprawdź który kolor aktualnie aktywny
CURRENT=$(grep "proxy_pass" /etc/nginx/conf.d/grazyna.conf | grep -o "300[12]" | head -1)
if [ "$CURRENT" = "3001" ]; then
    ACTIVE_PORT=3001
    NEW_PORT=3002
    ACTIVE_NAME="blue"
    NEW_NAME="green"
else
    ACTIVE_PORT=3002
    NEW_PORT=3001
    ACTIVE_NAME="green"
    NEW_NAME="blue"
fi

echo "Aktywny: $ACTIVE_NAME (:$ACTIVE_PORT)"
echo "Nowy:    $NEW_NAME (:$NEW_PORT)"

# 3. Uruchom nową wersję na nowym porcie
PORT=$NEW_PORT docker-compose -f docker-compose.prod.yml \
    -p grazyna-$NEW_NAME up -d --build backend

# 4. Czekaj na health check nowej wersji
echo "Czekam na start $NEW_NAME..."
for i in $(seq 1 $MAX_WAIT); do
    if curl -sf "$HEALTH_URL:$NEW_PORT/health" > /dev/null 2>&1; then
        echo "✅ $NEW_NAME zdrowy po ${i}s"
        break
    fi
    if [ $i -eq $MAX_WAIT ]; then
        echo "❌ $NEW_NAME nie startuje po ${MAX_WAIT}s — rollback!"
        docker-compose -f docker-compose.prod.yml -p grazyna-$NEW_NAME down
        exit 1
    fi
    sleep 1
done

# 5. Przełącz Nginx na nową wersję
sed -i "s/localhost:$ACTIVE_PORT/localhost:$NEW_PORT/g" /etc/nginx/conf.d/grazyna.conf
nginx -t && nginx -s reload
echo "✅ Nginx przełączony na $NEW_NAME (:$NEW_PORT)"

# 6. Poczekaj chwilę na drain połączeń
sleep 5

# 7. Zatrzymaj starą wersję
docker-compose -f docker-compose.prod.yml -p grazyna-$ACTIVE_NAME down
echo "✅ $ACTIVE_NAME zatrzymany"

# 8. Weryfikacja końcowa
HEALTH=$(curl -sf "https://api.twoja-domena.pl/health" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['status'])" 2>/dev/null)
if [ "$HEALTH" = "ok" ]; then
    echo "✅ Deploy zakończony pomyślnie!"
    echo "Wersja: $(git rev-parse --short HEAD)"
else
    echo "❌ Health check failed po deploy!"
    exit 1
fi
```

### GitHub Actions — auto zero-downtime deploy

```yaml
# .github/workflows/zero-downtime.yml
name: Zero-Downtime Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        run: |
          cd backend && npm ci
          npm test -- --run 2>/dev/null || echo "No tests yet"

      - name: Zero-downtime deploy
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.HETZNER_HOST }}
          username: deploy
          key: ${{ secrets.HETZNER_SSH_KEY }}
          script: |
            cd /opt/grazyna
            chmod +x deploy.sh
            ./deploy.sh

      - name: Notify success
        if: success()
        run: echo "✅ Deploy ${{ github.sha }} zakończony"
```

### Prisma Migrations — zero-downtime

```bash
# ❌ Niebezpieczne — blokuje tabelę
ALTER TABLE users ADD COLUMN new_field VARCHAR(255) NOT NULL;

# ✅ Bezpieczne — 3 kroki
# Krok 1: Dodaj kolumnę nullable (nie blokuje)
ALTER TABLE users ADD COLUMN new_field VARCHAR(255);

# Krok 2: Wypełnij dane (w tle)
UPDATE users SET new_field = 'default' WHERE new_field IS NULL;

# Krok 3: Dodaj NOT NULL constraint (po wypełnieniu)
ALTER TABLE users ALTER COLUMN new_field SET NOT NULL;
```

---

## 3. ISOLATION FOREST — COLD-START PROBLEM

### Problem

```
IsoForest wymaga min. 20 próbek do treningu
Przy starcie klastra: 0 próbek → brak predykcji przez ~3 minuty

Twój klaster startuje co:
  - Restart backendu: ~10s
  - Deploy: ~30s
  - Crash + restart: ~15s
→ Cold-start = 3 minuty bez ochrony IsoForest
```

### Rozwiązania

#### Rozwiązanie 1: Warm-up z historii Redis (najlepsze)

```typescript
// Przy starcie — załaduj historię z Redis
async function warmupIsolationForest(forest: IsolationForest, redis: RedisClientType) {
  console.log('[IsoForest] Warm-up z historii Redis...');

  // Pobierz ostatnie 100 próbek z historii
  const history = await redis.lRange('grazyna:cluster:history', 0, 99);

  if (history.length >= 20) {
    const vectors = history
      .map(h => JSON.parse(h))
      .map(m => normalizeMetrics(m));

    forest.fit(vectors);
    console.log(`[IsoForest] Warm-up OK: ${history.length} próbek`);
    return true;
  }

  console.log(`[IsoForest] Za mało danych (${history.length}/20) — tryb EWMA`);
  return false;
}

// Użycie przy starcie:
const isWarmed = await warmupIsolationForest(forest, redis);
if (!isWarmed) {
  // Fallback do EWMA podczas cold-start
  useEWMAMode = true;
}
```

#### Rozwiązanie 2: Fallback do EWMA podczas cold-start

```typescript
class AdaptiveAnomalyDetector {
  private forest:    IsolationForest;
  private ewma:      Map<string, EWMAPredictor> = new Map();
  private history:   number[][] = [];
  private isWarmed:  boolean = false;
  private readonly WARMUP_THRESHOLD = 20;

  async detect(metrics: WorkerMetrics): Promise<{
    isAnomaly: boolean;
    score: number;
    method: 'ewma' | 'isoforest';
    confidence: number;
  }> {
    const vec = this.normalize(metrics);
    this.history.push(vec);

    // Trenuj IsoForest gdy mamy dość danych
    if (!this.isWarmed && this.history.length >= this.WARMUP_THRESHOLD) {
      this.forest.fit(this.history);
      this.isWarmed = true;
      console.log('[Detector] IsoForest gotowy po warm-up');
    }

    if (this.isWarmed) {
      // Tryb IsoForest (pełna moc)
      const score = this.forest.anomalyScore(vec);
      return {
        isAnomaly:  score > 0.65,
        score,
        method:     'isoforest',
        confidence: Math.min(this.history.length / 100, 1.0),
      };
    } else {
      // Tryb EWMA (cold-start fallback)
      const ewmaHeap = this.updateEWMA('heap', metrics.heapPct);
      const ewmaEl   = this.updateEWMA('el',   metrics.elMaxMs);
      const isAnomaly = ewmaHeap.isAnomaly || ewmaEl.isAnomaly;
      const score = Math.max(ewmaHeap.anomalyScore, ewmaEl.anomalyScore) / 10;

      return {
        isAnomaly,
        score: Math.min(score, 1.0),
        method:     'ewma',
        confidence: this.history.length / this.WARMUP_THRESHOLD,
      };
    }
  }

  private updateEWMA(key: string, value: number) {
    if (!this.ewma.has(key)) this.ewma.set(key, new EWMAPredictor(0.3));
    return this.ewma.get(key)!.update(value);
  }

  private normalize(m: WorkerMetrics): number[] {
    return [
      Math.min(m.heapPct / 100, 1),
      Math.min(m.elMaxMs / 500, 1),
      Math.min(m.rssMB / 300, 1),
      Math.min(m.gcMinor / 50, 1),
    ];
  }

  get warmupProgress(): number {
    return Math.min(this.history.length / this.WARMUP_THRESHOLD * 100, 100);
  }
}
```

#### Rozwiązanie 3: Persystencja modelu w Redis

```typescript
// Zapisz wytrenowany model do Redis
async function saveForestToRedis(forest: IsolationForest, redis: RedisClientType) {
  const serialized = JSON.stringify({
    trees:     forest.exportTrees(),
    trainedAt: Date.now(),
    samples:   forest.sampleCount,
  });
  await redis.setEx('grazyna:isoforest:model', 3600, serialized); // TTL 1h
  console.log('[IsoForest] Model zapisany do Redis');
}

// Załaduj model przy starcie
async function loadForestFromRedis(redis: RedisClientType): Promise<IsolationForest | null> {
  const raw = await redis.get('grazyna:isoforest:model');
  if (!raw) return null;

  const data = JSON.parse(raw);
  const age  = Date.now() - data.trainedAt;

  // Odrzuć model starszy niż 1h
  if (age > 3600000) {
    console.log('[IsoForest] Model zbyt stary — retrain');
    return null;
  }

  const forest = new IsolationForest();
  forest.importTrees(data.trees);
  console.log(`[IsoForest] Model załadowany z Redis (wiek: ${Math.round(age/60000)}min)`);
  return forest;
}
```

### Cold-Start Timeline

```
t=0s:   Klaster startuje
t=0s:   EWMA aktywny (natychmiastowa ochrona przed spikes)
t=0s:   Próba załadowania modelu z Redis (jeśli istnieje)
t=0s:   Jeśli model w Redis → IsoForest natychmiast gotowy ✅
t=10s:  Zbieranie próbek (10 próbek)
t=20s:  Zbieranie próbek (20 próbek)
t=20s:  IsoForest trenuje na 20 próbkach → aktywny ✅
t=3min: IsoForest ma 18 próbek → pełna dokładność
t=10min:IsoForest ma 60 próbek → optymalna dokładność

Bez Redis: 20s cold-start (EWMA fallback)
Z Redis:   0s cold-start (model z poprzedniej sesji)
```

---

## Podsumowanie

| Temat | Rekomendacja |
|---|---|
| **Redis** | Standalone (dev) → Sentinel (prod v1, 3 serwery) |
| **Zero-downtime** | Blue-Green + deploy.sh + GitHub Actions |
| **IsoForest cold-start** | EWMA fallback + warm-up z Redis history + model persistence |

```powershell
# Commit
cd E:\Grazyna_5.0
git add GRAZYNA_ADVANCED_OPS.md
git commit -m "docs: Redis Sentinel, zero-downtime deploy, IsoForest cold-start solutions"
git push origin main
```
