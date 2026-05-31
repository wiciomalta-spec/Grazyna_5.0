# 🚀 GRAŻYNA 5.0 — Sentinel + Deployment Strategies + IsoForest Cold-Start

---

## 1. REDIS SENTINEL NA HETZNER — KROK PO KROKU

### Architektura (3 serwery Hetzner)

```
Hetzner CX21 (€4.35) — Master + App
  └── Redis Master :6379
  └── Sentinel :26379
  └── GRAŻYNA Backend :3001

Hetzner CX11 (€3.29) — Replica 1
  └── Redis Replica :6379
  └── Sentinel :26379

Hetzner CX11 (€3.29) — Replica 2
  └── Redis Replica :6379
  └── Sentinel :26379

TOTAL: €10.93/mies | HA: automatyczny failover w <10s
```

### Krok 1: Utwórz serwery na Hetzner

```bash
# Hetzner Cloud Console → New Server
# OS: Ubuntu 24.04
# Type: CX21 (master), CX11 (replica1), CX11 (replica2)
# Network: Private Network (10.0.0.0/24)
#   master:   10.0.0.1
#   replica1: 10.0.0.2
#   replica2: 10.0.0.3

# Firewall rules (Hetzner Firewall):
# Inbound: 22 (SSH), 80, 443, 3001
# Private: 6379, 26379 (tylko między serwerami)
```

### Krok 2: Zainstaluj Redis na wszystkich serwerach

```bash
# Na KAŻDYM serwerze (master + replica1 + replica2):
apt update && apt install -y redis-server

# Wygeneruj hasło Redis
REDIS_PASS=$(openssl rand -base64 32)
echo "REDIS_PASSWORD=$REDIS_PASS"  # zapisz!
```

### Krok 3: Konfiguracja Redis Master (10.0.0.1)

```bash
# /etc/redis/redis.conf na MASTER
cat > /etc/redis/redis.conf << EOF
bind 0.0.0.0
port 6379
requirepass TWOJE_HASLO_REDIS
masterauth TWOJE_HASLO_REDIS
maxmemory 256mb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
save 900 1
save 300 10
hz 20
lazyfree-lazy-eviction yes
EOF

systemctl restart redis-server
systemctl enable redis-server

# Test
redis-cli -a TWOJE_HASLO_REDIS ping  # → PONG
```

### Krok 4: Konfiguracja Redis Replica (10.0.0.2 i 10.0.0.3)

```bash
# /etc/redis/redis.conf na KAŻDEJ REPLICE
cat > /etc/redis/redis.conf << EOF
bind 0.0.0.0
port 6379
requirepass TWOJE_HASLO_REDIS
masterauth TWOJE_HASLO_REDIS
replicaof 10.0.0.1 6379
replica-read-only yes
maxmemory 256mb
maxmemory-policy allkeys-lru
appendonly yes
EOF

systemctl restart redis-server

# Weryfikacja replikacji
redis-cli -a TWOJE_HASLO_REDIS info replication
# Powinno pokazać: role:slave, master_host:10.0.0.1
```

### Krok 5: Konfiguracja Sentinel (na WSZYSTKICH 3 serwerach)

```bash
# /etc/redis/sentinel.conf na KAŻDYM serwerze
cat > /etc/redis/sentinel.conf << EOF
port 26379
bind 0.0.0.0
sentinel monitor grazyna-master 10.0.0.1 6379 2
sentinel auth-pass grazyna-master TWOJE_HASLO_REDIS
sentinel down-after-milliseconds grazyna-master 5000
sentinel failover-timeout grazyna-master 60000
sentinel parallel-syncs grazyna-master 1
sentinel announce-ip $(hostname -I | awk '{print $1}')
sentinel announce-port 26379
EOF

# Uruchom Sentinel
redis-sentinel /etc/redis/sentinel.conf &

# Lub jako systemd service:
cat > /etc/systemd/system/redis-sentinel.service << EOF
[Unit]
Description=Redis Sentinel
After=network.target

[Service]
ExecStart=/usr/bin/redis-sentinel /etc/redis/sentinel.conf
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable redis-sentinel
systemctl start redis-sentinel
```

### Krok 6: Zaktualizuj GRAŻYNA backend

```typescript
// backend/src/config/redis.ts
import Redis from 'ioredis';

export function createRedisClient() {
  if (process.env.NODE_ENV === 'production' && process.env.REDIS_SENTINELS) {
    // Sentinel mode (produkcja)
    return new Redis({
      sentinels: [
        { host: '10.0.0.1', port: 26379 },
        { host: '10.0.0.2', port: 26379 },
        { host: '10.0.0.3', port: 26379 },
      ],
      name:             'grazyna-master',
      password:         process.env.REDIS_PASSWORD,
      sentinelPassword: process.env.REDIS_PASSWORD,
      retryStrategy:    (times) => Math.min(times * 100, 3000),
      enableReadyCheck: true,
    });
  }

  // Standalone mode (dev)
  return new Redis({
    url:           process.env.REDIS_URL || 'redis://127.0.0.1:6379',
    retryStrategy: (times) => Math.min(times * 100, 3000),
  });
}
```

### Krok 7: Test failover

```bash
# Na master (10.0.0.1) — symuluj awarię
redis-cli -a TWOJE_HASLO_REDIS DEBUG sleep 30

# Na replica1 — obserwuj failover
redis-cli -p 26379 sentinel masters
# Po ~5s: jedna z replik zostaje nowym masterem

# Sprawdź kto jest teraz masterem
redis-cli -p 26379 sentinel get-master-addr-by-name grazyna-master
```

---

## 2. BLUE-GREEN vs ROLLING vs CANARY

### Porównanie strategii

| Kryterium | Blue-Green | Rolling | Canary |
|---|---|---|---|
| **Downtime** | 0s | 0s | 0s |
| **Rollback** | ✅ Natychmiastowy | ⚠️ Trudny | ✅ Łatwy |
| **Zasoby** | 2× serwery | 1× serwery | 1× serwery |
| **Ryzyko** | Niskie | Średnie | Bardzo niskie |
| **Złożoność** | Średnia | Niska | Wysoka |
| **Testowanie prod** | ❌ Nie | ❌ Nie | ✅ Tak (% ruchu) |
| **Dla GRAŻYNA** | ✅ **Rekomendowane** | ⚠️ OK | ❌ Overkill |

### Blue-Green (aktualny deploy.sh)

```
Stan 1:  Blue :3001 (100% ruchu)
Deploy:  Green :3002 buduje się
Stan 2:  Green :3002 zdrowy → Nginx przełącza
Stan 3:  Green :3002 (100% ruchu), Blue zatrzymany
Rollback: Nginx przełącza z powrotem na Blue (jeśli jeszcze działa)

Czas przełączenia: <1s (nginx -s reload)
Czas rollback:     <1s
```

### Rolling Deployment

```
Stan 1:  Worker1 :3001 v1, Worker2 :3001 v1, Worker3 :3001 v1
Deploy:  Worker1 → v2 (restart), Worker2 → v2, Worker3 → v2
Stan 2:  Wszystkie workery v2

Zalety:  Nie potrzeba 2× zasobów
Wady:    Przez chwilę v1 i v2 działają równolegle
         Problemy z migracjami DB (v1 i v2 muszą być kompatybilne)

# Implementacja z cluster.js:
cluster.on('exit', (worker) => {
  // Restart z nowym kodem
  cluster.fork();
});
// Restart po jednym workerze:
Object.values(cluster.workers).forEach((w, i) => {
  setTimeout(() => w?.kill('SIGTERM'), i * 5000);
});
```

### Canary Deployment

```
Stan 1:  100% ruchu → v1
Deploy:  5% ruchu → v2 (canary), 95% → v1
Monitor: Metryki v2 vs v1 (błędy, latencja, heap)
Stan 2:  25% → v2, 75% → v1
Stan 3:  100% → v2 (jeśli OK)

# Nginx config dla Canary:
upstream backend_v1 { server localhost:3001 weight=95; }
upstream backend_v2 { server localhost:3002 weight=5;  }

# Lub z split_clients:
split_clients "${remote_addr}${http_user_agent}" $backend {
    5%    "http://localhost:3002";  # canary
    *     "http://localhost:3001";  # stable
}
```

### Rekomendacja dla GRAŻYNA 5.0

```
DEV/Staging:  Blue-Green (prosty, szybki rollback)
PROD v1:      Blue-Green (deploy.sh już gotowy)
PROD v2+:     Canary (gdy masz >1000 users i chcesz testować)
```

---

## 3. ISOLATION FOREST COLD-START — IMPLEMENTACJA

### Problem w liczbach

```
Twój klaster restartuje się:
  - Normalny restart: ~10s
  - Deploy: ~30s
  - Crash: ~5s + restart ~10s = ~15s

IsoForest wymaga:
  - Min. próbek: 20
  - Próbkowanie: co 10s
  - Cold-start: 20 × 10s = 200s = ~3.3 minuty bez IsoForest

W tym czasie: tylko EWMA + Z-Score chronią klaster
```

### Implementacja AdaptiveAnomalyDetector (gotowa do użycia)

```typescript
// backend/src/adaptive-detector.ts

import { IsolationForest } from './redis-isolation-forest';

interface EWMAState {
  value:    number;
  variance: number;
}

export class AdaptiveAnomalyDetector {
  private forest:      IsolationForest;
  private ewmaStates:  Map<string, EWMAState> = new Map();
  private history:     number[][] = [];
  private isWarmed:    boolean = false;
  private sampleCount: number = 0;
  private readonly WARMUP = 20;
  private readonly ALPHA  = 0.3;

  constructor() {
    this.forest = new IsolationForest(100, 64);
  }

  // Załaduj historię z Redis przy starcie
  async warmup(redisHistory: string[]): Promise<void> {
    if (redisHistory.length >= this.WARMUP) {
      const vectors = redisHistory
        .slice(0, 100)
        .map(h => JSON.parse(h))
        .map(m => this.normalize(m));

      this.history = vectors;
      this.forest.fit(vectors);
      this.isWarmed = true;
      this.sampleCount = vectors.length;
      console.log(`[Detector] Warm-up OK: ${vectors.length} próbek z Redis`);
    } else {
      console.log(`[Detector] Cold-start: ${redisHistory.length}/${this.WARMUP} próbek — tryb EWMA`);
    }
  }

  detect(metrics: {
    heapPct: number;
    elMaxMs: number;
    rssMB:   number;
    gcMinor: number;
  }): {
    isAnomaly:  boolean;
    score:      number;
    method:     'ewma' | 'isoforest';
    confidence: number;
    details:    string;
  } {
    const vec = this.normalize(metrics);
    this.history.push(vec);
    this.sampleCount++;

    // Ogranicz historię
    if (this.history.length > 300) this.history.shift();

    // Trenuj IsoForest gdy mamy dość danych
    if (!this.isWarmed && this.history.length >= this.WARMUP) {
      this.forest.fit(this.history);
      this.isWarmed = true;
      console.log('[Detector] IsoForest aktywny po warm-up');
    }

    // Retrain co 50 próbek
    if (this.isWarmed && this.sampleCount % 50 === 0) {
      this.forest.fit(this.history.slice(-200));
    }

    const ewmaHeap = this.updateEWMA('heap', metrics.heapPct);
    const ewmaEl   = this.updateEWMA('el',   metrics.elMaxMs);

    if (this.isWarmed) {
      const isoScore  = this.forest.anomalyScore(vec);
      const ewmaAnom  = ewmaHeap.isAnomaly || ewmaEl.isAnomaly;
      const combined  = isoScore > 0.65 || ewmaAnom;
      const confidence = Math.min(this.history.length / 100, 1.0);

      return {
        isAnomaly:  combined,
        score:      isoScore,
        method:     'isoforest',
        confidence: Math.round(confidence * 100),
        details:    `IsoForest(${isoScore.toFixed(3)}) EWMA(${ewmaHeap.score.toFixed(1)}σ)`,
      };
    }

    // Cold-start: tylko EWMA
    const ewmaScore = Math.max(ewmaHeap.score, ewmaEl.score);
    const confidence = this.history.length / this.WARMUP;

    return {
      isAnomaly:  ewmaHeap.isAnomaly || ewmaEl.isAnomaly,
      score:      Math.min(ewmaScore / 10, 1.0),
      method:     'ewma',
      confidence: Math.round(confidence * 100),
      details:    `EWMA cold-start (${this.history.length}/${this.WARMUP} próbek)`,
    };
  }

  private normalize(m: { heapPct: number; elMaxMs: number; rssMB: number; gcMinor: number }): number[] {
    return [
      Math.min(m.heapPct / 100, 1),
      Math.min(m.elMaxMs / 500, 1),
      Math.min(m.rssMB   / 300, 1),
      Math.min(m.gcMinor / 50,  1),
    ];
  }

  private updateEWMA(key: string, value: number): { isAnomaly: boolean; score: number } {
    const state = this.ewmaStates.get(key) || { value, variance: 0 };
    const newVal = this.ALPHA * value + (1 - this.ALPHA) * state.value;
    const diff   = value - state.value;
    const newVar = 0.1 * diff * diff + 0.9 * state.variance;
    this.ewmaStates.set(key, { value: newVal, variance: newVar });
    const std   = Math.sqrt(newVar);
    const score = std > 0 ? Math.abs(value - newVal) / std : 0;
    return { isAnomaly: score > 2.5, score };
  }

  get status() {
    return {
      method:     this.isWarmed ? 'isoforest' : 'ewma',
      samples:    this.history.length,
      warmup:     `${Math.min(this.history.length, this.WARMUP)}/${this.WARMUP}`,
      confidence: `${Math.round(Math.min(this.history.length / 100, 1) * 100)}%`,
      isWarmed:   this.isWarmed,
    };
  }
}

// Singleton
export const detector = new AdaptiveAnomalyDetector();
```

### Endpoint status detektora

```typescript
// GET /api/system/detector
app.get('/api/system/detector', (req, res) => {
  res.json({
    ...detector.status,
    interpretation: {
      ewma:      'Cold-start — EWMA chroni przed spikes',
      isoforest: 'Pełna ochrona — wielowymiarowe anomalie',
    },
  });
});
```

### Timeline cold-start z implementacją

```
t=0s:   Klaster startuje
t=0s:   EWMA aktywny → chroni przed spikes (confidence: 0%)
t=0s:   Próba warm-up z Redis history
        → Jeśli ≥20 próbek: IsoForest natychmiast (confidence: 20%)
        → Jeśli <20 próbek: EWMA fallback
t=10s:  1 próbka → EWMA (confidence: 1%)
t=20s:  2 próbki → EWMA (confidence: 2%)
...
t=200s: 20 próbek → IsoForest aktywny! (confidence: 20%)
t=1000s:100 próbek → IsoForest pełna dokładność (confidence: 100%)
```