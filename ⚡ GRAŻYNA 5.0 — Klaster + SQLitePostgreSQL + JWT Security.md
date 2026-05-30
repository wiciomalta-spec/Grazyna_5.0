# ⚡ GRAŻYNA 5.0 — Klaster + SQLite/PostgreSQL + JWT Security

## Twój aktualny stan
```
Cluster:  3 workers (AI SCALE UP → 4)
Workers:  2 Worker Threads per cluster worker
Heap:     83.6% (poprawa z 91%!)
RSS:      86.4 MB
Frontend: http://localhost:5173 ✅
Backend:  http://localhost:3001 ✅
Git:      09ea504 → main ✅
```

---

## 1. OPTYMALIZACJA WYDAJNOŚCI KLASTRA

### Aktualny stan klastra
```
Primary (PID 224564)
├── Worker 1 → Express :3001 + WorkerPool(2) + Redis
├── Worker 2 → Express :3001 + WorkerPool(2) + Redis
├── Worker 3 → Express :3001 + WorkerPool(2) + Redis
└── Worker 4 → Express :3001 + WorkerPool(2) + Redis (AI SCALE UP)

Total Worker Threads: 4 × 2 = 8 workerów
Total RSS: ~86MB (normalny dla 4 procesów)
```

### Optymalizacje klastra

#### A. Sticky Sessions dla Socket.io
```typescript
// backend/src/cluster-bootstrap.ts
// Problem: Socket.io wymaga sticky sessions w cluster mode
// Bez tego: klient może trafić do innego workera → rozłączenie WS

import cluster from 'cluster';
import { createServer } from 'net';

if (cluster.isPrimary) {
  // Sticky session routing — ten sam klient → ten sam worker
  const workers: any[] = [];

  function getWorkerByIP(ip: string) {
    const hash = ip.split('.').reduce((acc, oct) => acc + parseInt(oct), 0);
    return workers[hash % workers.length];
  }

  // TCP proxy z sticky routing
  const server = createServer({ pauseOnConnect: true }, (conn) => {
    const ip = conn.remoteAddress || '0.0.0.0';
    const worker = getWorkerByIP(ip);
    if (worker) worker.send('sticky-session:connection', conn);
  });
  server.listen(3001);
}
```

#### B. Optymalna liczba workerów
```typescript
import { cpus } from 'os';

// Reguła: liczba workerów = liczba CPU cores
// Twój system: sprawdź ile masz cores
const OPTIMAL_WORKERS = Math.max(2, cpus().length);

// Dla dev (1-2 cores): 2 workery
// Dla prod (4+ cores): 4+ workerów

// AI SCALE UP (aktualny) → dynamiczne skalowanie
// Monitoruj: jeśli CPU > 80% → dodaj worker
// Monitoruj: jeśli CPU < 20% przez 5min → usuń worker
```

#### C. Shared Memory między workerami (bez Redis)
```typescript
// Dla prostych danych — SharedArrayBuffer
const sharedBuffer = new SharedArrayBuffer(1024);
const sharedView = new Int32Array(sharedBuffer);

// Worker 1 zapisuje request count
Atomics.add(sharedView, 0, 1);

// Worker 2 czyta
const totalRequests = Atomics.load(sharedView, 0);
```

#### D. Load Balancing — Round Robin vs Least Connections
```
Aktualny (Node.js default): Round Robin
  → Każdy request → kolejny worker
  → Prosto, ale nie uwzględnia obciążenia

Lepszy dla GRAŻYNA: Least Connections
  → Request → worker z najmniejszą liczbą aktywnych połączeń
  → Lepszy dla długich operacji (raporty, GPS aggregation)
```

### Metryki klastra do monitorowania
```powershell
# Sprawdź obciążenie każdego workera
Invoke-RestMethod http://localhost:3001/api/system/workers | ConvertTo-Json -Depth 5

# Sprawdź CPU per process
Get-Process node | Select-Object Id, CPU, WorkingSet, @{N='MB';E={[math]::Round($_.WorkingSet/1MB,1)}}
```

---

## 2. SQLITE vs POSTGRESQL DLA PRODUKCJI

### Twoja aktualna sytuacja
```
DEV:  SQLite (file:./dev.db) ✅ działa
PROD: ? ← to musisz zdecydować
```

### Szczegółowe porównanie

| Kryterium | SQLite | PostgreSQL |
|---|---|---|
| **Concurrent writes** | ❌ 1 writer na raz | ✅ MVCC (wiele równoległych) |
| **Concurrent reads** | ✅ Wiele | ✅ Wiele |
| **Max rozmiar DB** | ✅ 281 TB (teoretycznie) | ✅ Nieograniczony |
| **JSON queries** | ❌ Brak | ✅ JSONB z indeksami |
| **Full-text search** | ❌ Brak | ✅ Wbudowany |
| **Replication** | ❌ Brak | ✅ Streaming replication |
| **Backup** | ✅ Kopiuj plik | ✅ pg_dump, WAL |
| **Cluster mode** | ❌ Jeden plik = jeden serwer | ✅ Wiele serwerów |
| **Prisma support** | ✅ Pełny (dev) | ✅ Pełny (prod) |
| **Koszt** | ✅ Zero | ✅ Zero (self-hosted) |
| **Managed** | ❌ Brak | ✅ Supabase/Neon/RDS |

### Kiedy SQLite wystarczy na produkcji?

```
✅ SQLite PROD OK gdy:
  - Jeden serwer (nie distributed)
  - < 100 concurrent users
  - Głównie odczyty (read-heavy)
  - Prosta aplikacja CRUD
  - Brak potrzeby replikacji

❌ SQLite NIE nadaje się gdy:
  - Cluster mode (wiele procesów piszących!)  ← TWÓJ PRZYPADEK!
  - > 100 concurrent writes
  - Potrzebujesz JSON queries
  - Potrzebujesz replikacji/HA
  - Potrzebujesz managed backup
```

### ⚠️ KRYTYCZNE dla GRAŻYNA 5.0

```
Twój klaster ma 4 workery → 4 procesy Node.js
Każdy może pisać do SQLite jednocześnie
→ SQLite WAL mode pomaga, ale nie eliminuje problemu
→ Na produkcji z klastrem: UŻYJ POSTGRESQL!
```

### Migracja SQLite → PostgreSQL (Supabase — darmowy)

```powershell
# Krok 1: Utwórz darmowe konto na supabase.com
# Krok 2: Pobierz DATABASE_URL z Settings → Database

# Krok 3: Zaktualizuj schema.prisma
$schema = "E:\Grazyna_5.0\backend\prisma\schema.prisma"
$sc = Get-Content $schema -Raw

# Zmień provider i URL
$sc = $sc -replace 'provider = "sqlite"', 'provider = "postgresql"'
$sc = $sc -replace 'url\s*=\s*"file:./dev.db"', 'url = env("DATABASE_URL")'

# Przywróć typy PostgreSQL
$sc = $sc -replace '// JSON string.*\n(\s+\w+\s+)String\?', '$1Json?'

$sc | Out-File $schema -Encoding UTF8

# Krok 4: Zaktualizuj .env
# DATABASE_URL=postgresql://postgres:[PASSWORD]@db.[PROJECT].supabase.co:5432/postgres

# Krok 5: Migracja
cmd /c "cd /d E:\Grazyna_5.0\backend && node_modules\.bin\prisma.cmd migrate dev --name init"
```

### Rekomendacja dla GRAŻYNA 5.0

```
DEV:     SQLite ← zostań (szybko, zero konfiguracji)
STAGING: PostgreSQL w Docker (docker-compose up -d postgres)
PROD:    Supabase (darmowy tier: 500MB, 2 CPU, 1GB RAM)
         LUB Neon.tech (darmowy tier: 3GB, serverless)
         LUB własny PostgreSQL na VPS
```

---

## 3. ZABEZPIECZENIE JWT PRZED ATAKAMI

### Znane ataki na JWT

#### Atak 1: Algorithm Confusion (alg:none)
```
Atakujący zmienia nagłówek: {"alg":"none"}
→ Serwer akceptuje token bez weryfikacji podpisu!

FIX: Zawsze określ dozwolone algorytmy
```
```typescript
// ❌ Podatne
jwt.verify(token, secret);

// ✅ Bezpieczne — tylko HS256
jwt.verify(token, secret, { algorithms: ['HS256'] });
```

#### Atak 2: JWT Secret Brute Force
```
Słaby secret "secret123" → można złamać w minuty
JWT secret powinien mieć min. 256 bitów (32 bajty)

FIX: Użyj silnego sekretu
```
```powershell
# Generuj silny secret (32 bajty = 256 bitów)
$secret = [System.Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
Write-Host "JWT_SECRET=$secret"
# Zapisz do backend/.env
```

#### Atak 3: Token Theft (kradzież tokenu)
```
Atakujący kradnie token z localStorage → pełny dostęp do wygaśnięcia

FIX A: Krótki TTL (15 minut) + Refresh Token
FIX B: Przechowuj w pamięci JS (nie localStorage, nie sessionStorage)
FIX C: HttpOnly cookie dla refresh token
```

#### Atak 4: CSRF (Cross-Site Request Forgery)
```
Atakujący nakłania użytkownika do wykonania żądania z jego tokenem

FIX: SameSite=Strict dla cookies + CSRF token dla mutacji
```

#### Atak 5: JWT Replay Attack
```
Atakujący przechwytuje ważny token i używa go wielokrotnie

FIX: Krótki TTL + Token Rotation + JTI (JWT ID) blacklist
```

### Kompletna implementacja bezpiecznego JWT

```typescript
// backend/src/middleware/auth.ts — BEZPIECZNA WERSJA

import jwt from 'jsonwebtoken';
import crypto from 'crypto';

const JWT_SECRET    = process.env.JWT_SECRET!;
const JWT_ALGORITHM = 'HS256' as const;
const ACCESS_TTL    = '15m';

// Blacklist dla unieważnionych tokenów (w Redis lub pamięci)
const tokenBlacklist = new Set<string>();

export function generateAccessToken(userId: string, role: string): string {
  return jwt.sign(
    {
      sub:  userId,
      role,
      type: 'access',
      jti:  crypto.randomUUID(),  // Unikalny ID tokenu (dla blacklist)
      iat:  Math.floor(Date.now() / 1000),
    },
    JWT_SECRET,
    {
      algorithm: JWT_ALGORITHM,
      expiresIn: ACCESS_TTL,
      issuer:    'grazyna-5.0',
      audience:  'grazyna-client',
    }
  );
}

export function verifyAccessToken(token: string): jwt.JwtPayload {
  // 1. Weryfikuj z określonym algorytmem (zapobiega alg:none)
  const payload = jwt.verify(token, JWT_SECRET, {
    algorithms: [JWT_ALGORITHM],  // ← KRYTYCZNE
    issuer:     'grazyna-5.0',
    audience:   'grazyna-client',
  }) as jwt.JwtPayload;

  // 2. Sprawdź typ tokenu
  if (payload.type !== 'access') {
    throw new Error('Invalid token type');
  }

  // 3. Sprawdź blacklist (dla wylogowanych tokenów)
  if (payload.jti && tokenBlacklist.has(payload.jti)) {
    throw new Error('Token has been revoked');
  }

  return payload;
}

export function revokeToken(jti: string): void {
  tokenBlacklist.add(jti);
  // W produkcji: zapisz do Redis z TTL = czas wygaśnięcia tokenu
}

// Middleware
export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Brak tokenu autoryzacji' });
  }

  const token = authHeader.slice(7);

  // Podstawowa walidacja długości (zapobiega DoS)
  if (token.length > 2048) {
    return res.status(401).json({ error: 'Token zbyt długi' });
  }

  try {
    const payload = verifyAccessToken(token);
    req.user = { id: payload.sub!, role: payload.role, jti: payload.jti };
    next();
  } catch (err: any) {
    const messages: Record<string, string> = {
      'TokenExpiredError':    'Token wygasł — odśwież',
      'JsonWebTokenError':    'Nieprawidłowy token',
      'NotBeforeError':       'Token jeszcze nieaktywny',
      'Invalid token type':   'Nieprawidłowy typ tokenu',
      'Token has been revoked': 'Token unieważniony',
    };
    const msg = messages[err.name] || messages[err.message] || 'Błąd autoryzacji';
    res.status(401).json({ error: msg });
  }
}
```

### Checklist bezpieczeństwa JWT

```
✅ Algorytm: HS256 z jawnym określeniem (nie "auto")
✅ Secret: min. 256 bitów (32 bajty losowe)
✅ TTL: Access 15min, Refresh 7 dni
✅ Typ tokenu: pole "type" w payload
✅ JTI: unikalny ID dla blacklisty
✅ Issuer/Audience: weryfikacja
✅ Refresh Token Rotation: każdy refresh = nowy token
✅ HttpOnly Cookie: dla refresh token
✅ SameSite=Strict: ochrona przed CSRF
✅ Długość tokenu: max 2048 znaków
✅ Rate limiting: max 5 prób logowania/min
```

### Rate Limiting dla auth endpoints

```typescript
import rateLimit from 'express-rate-limit';

// Max 5 prób logowania na 15 minut per IP
export const loginRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: { error: 'Zbyt wiele prób logowania — spróbuj za 15 minut' },
  standardHeaders: true,
  legacyHeaders: false,
  // Klucz: IP + email (bardziej precyzyjne)
  keyGenerator: (req) => `${req.ip}-${req.body?.email || 'unknown'}`,
});

// Max 3 rejestracje na godzinę per IP
export const registerRateLimit = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 3,
  message: { error: 'Zbyt wiele rejestracji z tego IP' },
});

// Użycie w routes:
// router.post('/auth/login', loginRateLimit, loginHandler);
// router.post('/auth/register', registerRateLimit, registerHandler);
```

---

## 4. SKRYPT KONFIGURACYJNY

```powershell
# Wklej do PowerShell — konfiguruje wszystkie zabezpieczenia

$backend = "E:\Grazyna_5.0\backend"
$envFile = "$backend\.env"

# 1. Generuj silny JWT_SECRET
$newSecret = [System.Convert]::ToBase64String(
    [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
)
$env = Get-Content $envFile -Raw
$env = $env -replace 'JWT_SECRET=.*', "JWT_SECRET=$newSecret"
[System.IO.File]::WriteAllText($envFile, $env, [System.Text.UTF8Encoding]::new($false))
Write-Host "✅ Nowy JWT_SECRET: $newSecret" -ForegroundColor Green

# 2. Sprawdź czy express-rate-limit jest zainstalowany
$pkgJson = Get-Content "$backend\package.json" | ConvertFrom-Json
if (-not $pkgJson.dependencies.'express-rate-limit') {
    Write-Host "Instaluję express-rate-limit..." -ForegroundColor Cyan
    cmd /c "cd /d `"$backend`" && node_modules\.bin\npm.cmd install express-rate-limit"
}

# 3. Sprawdź cluster workers
$workers = Invoke-RestMethod "http://localhost:3001/api/system/workers" -TimeoutSec 5
Write-Host "✅ Cluster: $($workers.clusterWorkers) workers" -ForegroundColor Green
Write-Host "✅ Worker Threads: $($workers.workerPool.workers)" -ForegroundColor Green

# 4. Restart po zmianie .env
Write-Host "Restartuję backend..." -ForegroundColor Cyan
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3
Start-Process cmd -ArgumentList "/k", "cd /d `"$backend`" && `"E:\Grazyna_5.0\tools\nodejs\node.exe`" --max-old-space-size=256 --expose-gc node_modules\tsx\dist\cli.mjs watch src\cluster-bootstrap.ts"
Start-Sleep 8
Invoke-RestMethod "http://localhost:3001/health" | ConvertTo-Json
```