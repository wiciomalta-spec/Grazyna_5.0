# 🗄️ GRAŻYNA 5.0 — Supabase Migration End-to-End Plan

## Dlaczego Supabase?

```
✅ Darmowy tier: 500MB DB, 2 CPU, 1GB RAM
✅ PostgreSQL 15 (pełne wsparcie enum, Json, JSONB)
✅ Auto-backup co 24h
✅ Dashboard z Table Editor
✅ REST API auto-generowane
✅ Realtime subscriptions (bonus!)
✅ Zero DevOps — managed service
✅ Prisma pełne wsparcie
```

---

## FAZA 1: Konto i projekt Supabase (15 minut)

```
1. Wejdź na https://supabase.com
2. Sign up (GitHub OAuth — najszybciej)
3. New Project:
   - Name: grazyna-5-0
   - Database Password: [zapisz bezpiecznie!]
   - Region: Central EU (Frankfurt) ← najbliżej Polski
4. Poczekaj ~2 minuty na inicjalizację
5. Settings → Database → Connection string → URI
   Skopiuj: postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres
```

---

## FAZA 2: Przygotowanie lokalne (10 minut)

```powershell
# Krok 1: Uruchom skrypt migracji
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& "E:\Grazyna_5.0\GRAZYNA_SUPABASE_MIGRATION.ps1"
# → Podaj DATABASE_URL z Supabase

# Krok 2: Weryfikacja schema
Get-Content "E:\Grazyna_5.0\backend\prisma\schema.prisma" | Select-Object -First 20

# Krok 3: Sprawdź .env
Get-Content "E:\Grazyna_5.0\backend\.env" | Select-String "DATABASE_URL"
# Powinno być: DATABASE_URL=postgresql://postgres:...@db.xxx.supabase.co:5432/postgres
```

---

## FAZA 3: Prisma Migrate (5 minut)

```powershell
cd E:\Grazyna_5.0\backend

# Generuj klienta Prisma dla PostgreSQL
cmd /c "node_modules\.bin\prisma.cmd generate"

# Utwórz i zastosuj migrację
cmd /c "node_modules\.bin\prisma.cmd migrate dev --name init_supabase"

# Oczekiwany output:
# ✓ Generated Prisma Client
# ✓ Your database is now in sync with your Prisma schema.
# Done in 8.5s

# Weryfikacja — sprawdź tabele w Supabase Dashboard
# Table Editor → powinieneś widzieć: User, Vehicle, Mission, Event, Alert...
```

---

## FAZA 4: Seed danych testowych (5 minut)

```powershell
# Utwórz plik seed
$seedContent = @'
import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

async function main() {
  console.log("Seeding Supabase...");

  // Admin user
  const hash = await bcrypt.hash("Admin1234!", 12);
  const admin = await prisma.user.upsert({
    where: { email: "admin@grazyna.pl" },
    update: {},
    create: {
      email:        "admin@grazyna.pl",
      username:     "admin",
      passwordHash: hash,
      firstName:    "Admin",
      lastName:     "GRAŻYNA",
      role:         "ADMIN",
    },
  });
  console.log("✅ Admin:", admin.email);

  // Test vehicles
  const vehicles = await Promise.all([
    prisma.vehicle.upsert({
      where: { licensePlate: "WA-001-GR" },
      update: {},
      create: { name:"Pojazd Alpha", licensePlate:"WA-001-GR", type:"STANDARD", status:"IDLE", battery:100 },
    }),
    prisma.vehicle.upsert({
      where: { licensePlate: "WA-002-GR" },
      update: {},
      create: { name:"Pojazd Beta",  licensePlate:"WA-002-GR", type:"DRONE",    status:"ACTIVE", battery:85 },
    }),
    prisma.vehicle.upsert({
      where: { licensePlate: "WA-003-GR" },
      update: {},
      create: { name:"Pojazd Gamma", licensePlate:"WA-003-GR", type:"HEAVY",    status:"MAINTENANCE", battery:60 },
    }),
  ]);
  console.log(`✅ Pojazdy: ${vehicles.length}`);

  // System config
  await prisma.systemConfig.upsert({
    where: { key: "app.version" },
    update: {},
    create: { key:"app.version", value:JSON.stringify("5.0.0"), category:"system" },
  });

  console.log("✅ Seed zakończony!");
}

main().catch(console.error).finally(() => prisma.$disconnect());
'@
$seedContent | Out-File "E:\Grazyna_5.0\backend\prisma\seed.ts" -Encoding UTF8

# Uruchom seed
cmd /c "cd /d E:\Grazyna_5.0\backend && node_modules\.bin\prisma.cmd db seed"
# Lub bezpośrednio:
cmd /c "cd /d E:\Grazyna_5.0\backend && E:\Grazyna_5.0\tools\nodejs\node.exe node_modules\tsx\dist\cli.mjs prisma\seed.ts"
```

---

## FAZA 5: Restart i weryfikacja (5 minut)

```powershell
# Restart backendu z PostgreSQL
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3

Start-Process cmd -ArgumentList "/k", "cd /d E:\Grazyna_5.0\backend && E:\Grazyna_5.0\tools\nodejs\node.exe --max-old-space-size=256 --expose-gc node_modules\tsx\dist\cli.mjs watch src\cluster-bootstrap.ts"
Start-Sleep 10

# Test 1: Health
Invoke-RestMethod "http://localhost:3001/health" | ConvertTo-Json

# Test 2: Rejestracja
$ts = Get-Date -Format "HHmmss"
$reg = Invoke-RestMethod "http://localhost:3001/api/auth/register" `
    -Method POST -ContentType "application/json" `
    -Body "{`"email`":`"test$ts@grazyna.pl`",`"password`":`"Test1234!`",`"username`":`"user$ts`"}"
Write-Host "✅ Rejestracja: $($reg.user.email)" -ForegroundColor Green

# Test 3: Logowanie
$login = Invoke-RestMethod "http://localhost:3001/api/auth/login" `
    -Method POST -ContentType "application/json" `
    -Body "{`"email`":`"test$ts@grazyna.pl`",`"password`":`"Test1234!`"}"
Write-Host "✅ Token: $($login.token.Substring(0,30))..." -ForegroundColor Green

# Test 4: Sprawdź w Supabase Dashboard
Write-Host "🌐 Sprawdź: https://supabase.com → Table Editor → User" -ForegroundColor Cyan
```

---

## FAZA 6: Commit i push (2 minuty)

```powershell
cd E:\Grazyna_5.0

# Dodaj zmiany
git add backend/prisma/schema.prisma
git add backend/prisma/seed.ts
git add backend/.env  # UWAGA: usuń z .gitignore jeśli chcesz commitować

# Lepiej: dodaj .env.example bez haseł
@"
DATABASE_URL=postgresql://postgres:PASSWORD@db.PROJECT.supabase.co:5432/postgres
REDIS_URL=redis://127.0.0.1:6379
JWT_SECRET=GENERATE_WITH_openssl_rand_base64_32
CORS_ORIGIN=http://localhost:5173
NODE_ENV=development
PORT=3001
LOG_LEVEL=debug
NODE_OPTIONS=--max-old-space-size=256 --expose-gc
UV_THREADPOOL_SIZE=16
"@ | Out-File "E:\Grazyna_5.0\backend\.env.example" -Encoding UTF8

git add backend/.env.example
git commit -m "feat: migrate to Supabase PostgreSQL - schema, seed, env.example"
git push origin main
```

---

## FAZA 7: Produkcja — zmienne środowiskowe

```bash
# Na Hetzner (backend/.env.production)
NODE_ENV=production
PORT=3001
DATABASE_URL=postgresql://postgres:[PASS]@db.[PROJECT].supabase.co:5432/postgres
REDIS_URL=redis://:password@localhost:6379
JWT_SECRET=[openssl rand -base64 32]
CORS_ORIGIN=https://twoja-domena.pl
LOG_LEVEL=warn
NODE_OPTIONS=--max-old-space-size=512
UV_THREADPOOL_SIZE=16
```

---

## Checklist End-to-End

```
□ Konto Supabase utworzone
□ Projekt grazyna-5-0 aktywny (Frankfurt)
□ DATABASE_URL skopiowany
□ GRAZYNA_SUPABASE_MIGRATION.ps1 uruchomiony
□ prisma migrate dev --name init_supabase OK
□ Tabele widoczne w Supabase Dashboard
□ Seed danych uruchomiony (admin + 3 pojazdy)
□ Backend zrestartowany z PostgreSQL
□ Rejestracja działa (HTTP 201)
□ Logowanie działa (JWT token)
□ .env.example commitowany
□ git push origin main
□ k6 test na PostgreSQL (porównaj z SQLite)
```

---

## Porównanie wydajności SQLite vs PostgreSQL (oczekiwane)

| Metryka | SQLite (dev) | PostgreSQL (Supabase) |
|---|---|---|
| Rejestracja | ~5ms | ~50-100ms (sieć!) |
| Logowanie | ~100ms (bcrypt) | ~100ms (bcrypt) |
| Lista pojazdów | ~1ms | ~20-50ms |
| Concurrent writes | ❌ Blokuje | ✅ MVCC |
| JSON queries | ❌ Brak | ✅ JSONB |
| Backup | Ręczny | ✅ Auto co 24h |

> **Uwaga:** Supabase free tier ma ~50ms latencji sieciowej z Polski do Frankfurtu.
> Dla produkcji to akceptowalne. Dla dev — SQLite jest szybszy lokalnie.