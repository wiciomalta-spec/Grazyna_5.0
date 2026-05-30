# 🗄️ GRAŻYNA 5.0 — Diagnoza PostgreSQL + SQLite vs PostgreSQL + Prisma na Windows

---

## 1. DIAGNOZA PROBLEMU POSTGRESQL

### Co się stało?

```
DATABASE_URL=postgresql://grazyna:grazyna123@postgres:5432/grazyna_db
                                              ↑
                                    hostname "postgres" = Docker service name
                                    Działa TYLKO wewnątrz Docker network!
                                    Na hoście Windows → connection refused
```

### Przyczyny (w kolejności prawdopodobieństwa)

| # | Przyczyna | Diagnoza | Fix |
|---|---|---|---|
| 1 | **hostname `postgres` zamiast `localhost`** | `DATABASE_URL` wskazuje na Docker service | Zmień na `localhost` |
| 2 | **Docker Desktop API error 500** | `docker ps` zwraca błąd API | Restart Docker Desktop |
| 3 | **PostgreSQL nie uruchomiony** | `netstat` nie pokazuje :5432 | `docker-compose up -d postgres` |
| 4 | **Brak Docker network** | Backend poza Docker, DB w Docker | Użyj `localhost` + port mapping |

### Architektura problemu

```
❌ BŁĘDNA (aktualna):
┌─────────────────────────────────────────┐
│  Docker Network "grazyna_default"       │
│  ┌──────────┐    ┌──────────────────┐  │
│  │ postgres │    │ backend (Docker) │  │
│  │ :5432    │◄───│ host: "postgres" │  │
│  └──────────┘    └──────────────────┘  │
└─────────────────────────────────────────┘
         ↑
Windows Host: backend działa przez tsx (nie Docker!)
→ "postgres" hostname nie istnieje poza Docker network
→ Connection refused!

✅ POPRAWNA (dev bez Docker):
Windows Host
├── tsx backend → DATABASE_URL=postgresql://...@localhost:5432/...
└── Docker: postgres container z port mapping 5432:5432
    → localhost:5432 → container:5432 ✓
```

### Fix PostgreSQL (gdy Docker działa)

```powershell
# Krok 1: Napraw DATABASE_URL
$env = "E:\Grazyna_5.0\backend\.env"
(Get-Content $env -Raw) -replace "@postgres:5432", "@localhost:5432" |
    Out-File $env -Encoding UTF8

# Krok 2: Restart Docker Desktop (jeśli API error)
Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
Start-Sleep 5
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Start-Sleep 30

# Krok 3: Uruchom PostgreSQL
cd E:\Grazyna_5.0
docker-compose up -d postgres redis
Start-Sleep 10

# Krok 4: Weryfikacja
netstat -ano | findstr ":5432"
```

---

## 2. SQLITE vs POSTGRESQL — PORÓWNANIE DLA DEWELOPERA

### Szybkie porównanie

| Kryterium | SQLite (dev) | PostgreSQL (prod) |
|---|---|---|
| **Instalacja** | ✅ Zero (wbudowany w Prisma) | ❌ Docker lub instalacja |
| **Konfiguracja** | ✅ `file:./dev.db` | ❌ user/pass/host/port |
| **Prędkość startu** | ✅ Natychmiastowa | ❌ 5-30s (Docker) |
| **Migracje** | ✅ `prisma db push` | ✅ `prisma migrate dev` |
| **Dane testowe** | ✅ Łatwy reset (usuń plik) | ⚠️ `prisma migrate reset` |
| **Typy danych** | ⚠️ Ograniczone | ✅ Pełne (JSON, UUID, Array) |
| **Concurrent writes** | ❌ Blokuje przy wielu zapisach | ✅ MVCC (pełna współbieżność) |
| **Full-text search** | ❌ Brak | ✅ Wbudowany |
| **JSON queries** | ❌ Brak | ✅ JSONB |
| **Produkcja** | ❌ Nie nadaje się | ✅ Tak |
| **Prisma support** | ✅ Pełny | ✅ Pełny |
| **Port conflicts** | ✅ Brak | ⚠️ :5432 może być zajęty |

### Kiedy używać czego

```
DEV (lokalne):     SQLite ← TERAZ (szybko, zero konfiguracji)
STAGING:           PostgreSQL w Docker
PRODUKCJA:         PostgreSQL (managed: Supabase, Neon, RDS)
```

### Ograniczenia SQLite w Prisma (ważne!)

```prisma
// ❌ NIE DZIAŁA w SQLite:
model Vehicle {
  tags    String[]          // Array — tylko PostgreSQL
  meta    Json              // JSON — tylko PostgreSQL
  search  Unsupported("tsvector") // Full-text — tylko PostgreSQL
  id      String @default(dbgenerated("gen_random_uuid()")) // PostgreSQL UUID
}

// ✅ DZIAŁA w SQLite:
model Vehicle {
  id          String   @id @default(cuid())  // cuid zamiast UUID
  licensePlate String
  status      String   @default("active")
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}
```

### Schema.prisma — wersja kompatybilna SQLite+PostgreSQL

```prisma
// Użyj zmiennej środowiskowej dla providera
datasource db {
  provider = env("DB_PROVIDER")  // "sqlite" lub "postgresql"
  url      = env("DATABASE_URL")
}

// backend/.env (dev):
// DB_PROVIDER=sqlite
// DATABASE_URL=file:./dev.db

// backend/.env.production:
// DB_PROVIDER=postgresql
// DATABASE_URL=postgresql://grazyna:pass@localhost:5432/grazyna_db
```

---

## 3. PROBLEM: PRISMA BASH SCRIPT NA WINDOWS

### Co się stało?

```powershell
# To NIE działa na Windows:
node node_modules\.bin\prisma db push
#         ↑
# node_modules\.bin\prisma to BASH script (shebang #!/bin/sh)
# Node.js próbuje go wykonać jako JS → SyntaxError!

# Zawartość node_modules\.bin\prisma:
#!/bin/sh          ← bash shebang
basedir=$(dirname "$(echo "$0" | sed -e 's,\\,/,g')")
          ^^^^^^^
# SyntaxError: missing ) after argument list ← Node.js nie rozumie bash!
```

### Dlaczego tak jest?

```
npm tworzy dwa pliki w node_modules\.bin\:
  prisma      → bash script (dla Linux/Mac)
  prisma.cmd  → Windows batch script ← TO jest właściwe dla Windows!
  prisma.ps1  → PowerShell script (nowsze npm)
```

### Poprawne uruchamianie Prisma na Windows

```powershell
# ✅ Metoda 1: .cmd (najlepsza dla Windows)
cmd /c "cd /d E:\Grazyna_5.0\backend && node_modules\.bin\prisma.cmd db push"

# ✅ Metoda 2: npx (automatycznie wybiera właściwy)
cmd /c "cd /d E:\Grazyna_5.0\backend && npx prisma db push"

# ✅ Metoda 3: node + build/index.js (zawsze działa)
node E:\Grazyna_5.0\backend\node_modules\prisma\build\index.js db push

# ✅ Metoda 4: przez package.json scripts (npm run)
# W package.json: "db:push": "prisma db push"
npm run db:push  # npm automatycznie używa .cmd na Windows

# ❌ NIE DZIAŁA:
node node_modules\.bin\prisma db push  # bash script!
& ".\node_modules\.bin\prisma" db push # bash script!
```

### Dlaczego `npm run` działa a `node prisma` nie?

```
npm run db:push
    ↓
npm dodaje node_modules\.bin do PATH
    ↓
Na Windows: PATH zawiera prisma.cmd (nie prisma)
    ↓
cmd.exe uruchamia prisma.cmd ✅

node node_modules\.bin\prisma
    ↓
Node.js próbuje wykonać plik jako JavaScript
    ↓
Plik to bash script → SyntaxError ❌
```

---

## 4. KOMPLETNY FIX — WSZYSTKIE PROBLEMY NARAZ

```powershell
# ══════════════════════════════════════════════════════
# GRAŻYNA 5.0 — ONE-LINER FIX (wklej do PowerShell)
# ══════════════════════════════════════════════════════

$b = "E:\Grazyna_5.0\backend"
$n = "E:\Grazyna_5.0\tools\nodejs\node.exe"

# 1. SQLite dla dev
(Get-Content "$b\.env" -Raw) -replace "DATABASE_URL=.*", "DATABASE_URL=file:./dev.db" |
    Out-File "$b\.env" -Encoding UTF8

# 2. Schema → SQLite (usuń PostgreSQL-specific)
$s = Get-Content "$b\prisma\schema.prisma" -Raw
$s = $s -replace 'provider\s*=\s*"postgresql"', 'provider = "sqlite"'
$s = $s -replace '@db\.\w+(\(\d+\))?', ''
$s | Out-File "$b\prisma\schema.prisma" -Encoding UTF8

# 3. Prisma db push przez .cmd
Write-Host "Uruchamiam Prisma db push..." -ForegroundColor Cyan
$result = cmd /c "cd /d `"$b`" && node_modules\.bin\prisma.cmd db push --accept-data-loss 2>&1"
$result | Write-Host

# 4. Restart backend
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2
Start-Process cmd -ArgumentList "/k", "cd /d `"$b`" && `"$n`" --max-old-space-size=256 --expose-gc node_modules\tsx\dist\cli.mjs watch src\cluster-bootstrap.ts"
Write-Host "✅ Backend uruchamia się..." -ForegroundColor Green
```

---

## 5. STRATEGIA DŁUGOTERMINOWA

```
DEV (teraz):
  SQLite → zero konfiguracji, szybki reset
  prisma.cmd → poprawne uruchamianie na Windows

STAGING (gdy Docker działa):
  PostgreSQL w Docker
  DATABASE_URL=postgresql://...@localhost:5432/...  ← localhost nie "postgres"!
  docker-compose up -d postgres

PRODUKCJA:
  Supabase (darmowy tier) lub Neon.tech
  DATABASE_URL=postgresql://...@db.supabase.co:5432/postgres
  Zero konfiguracji Docker, SSL wbudowany
```