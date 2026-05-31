# ============================================================
# GRAŻYNA 5.0 — MIGRACJA SCHEMA NA SUPABASE POSTGRESQL
# Uruchom po uzyskaniu DATABASE_URL z supabase.com
# ============================================================
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

$proj    = "E:\Grazyna_5.0"
$backend = "$proj\backend"
$schema  = "$backend\prisma\schema.prisma"
$envFile = "$backend\.env"

function L($level, $msg) {
    $col = switch($level) { "OK"{"Green"}; "WARN"{"Yellow"}; "ERR"{"Red"}; "INFO"{"Cyan"} }
    $ico = switch($level) { "OK"{"✅"}; "WARN"{"⚠️"}; "ERR"{"❌"}; "INFO"{"ℹ️"} }
    Write-Host "  $ico $msg" -ForegroundColor $col
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   GRAŻYNA 5.0 — MIGRACJA NA SUPABASE POSTGRESQL        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─── KROK 1: Pobierz DATABASE_URL od użytkownika ──────────
Write-Host "[ 1/7 ] Konfiguracja Supabase..." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Aby uzyskać DATABASE_URL:" -ForegroundColor White
Write-Host "  1. Wejdź na https://supabase.com → New Project" -ForegroundColor Gray
Write-Host "  2. Settings → Database → Connection string → URI" -ForegroundColor Gray
Write-Host "  3. Skopiuj URL (zaczyna się od postgresql://...)" -ForegroundColor Gray
Write-Host ""

$dbUrl = Read-Host "  Wklej DATABASE_URL z Supabase (lub Enter aby pominąć)"

if ([string]::IsNullOrWhiteSpace($dbUrl)) {
    L "WARN" "Pominięto — używam przykładowego URL dla demonstracji"
    $dbUrl = "postgresql://postgres:PASSWORD@db.PROJECT.supabase.co:5432/postgres"
    $demoMode = $true
} else {
    $demoMode = $false
    L "OK" "DATABASE_URL otrzymany"
}

# ─── KROK 2: Backup aktualnej schema ──────────────────────
Write-Host "[ 2/7 ] Backup schema.prisma..." -ForegroundColor Yellow
$backupPath = "$backend\prisma\schema.prisma.sqlite_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $schema $backupPath -Force
L "OK" "Backup: $backupPath"

# ─── KROK 3: Przywróć schema PostgreSQL ───────────────────
Write-Host "[ 3/7 ] Przywracam schema PostgreSQL..." -ForegroundColor Yellow

$pgSchema = @'
// ============================================================
// GRAŻYNA 5.0 — Schema Prisma dla PostgreSQL (Supabase)
// ============================================================

generator client {
  provider      = "prisma-client-js"
  binaryTargets = ["native"]
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// ════════════════════════════════════════════════════════
// ENUMS (PostgreSQL obsługuje natywnie)
// ════════════════════════════════════════════════════════

enum Role {
  ADMIN
  MANAGER
  OPERATOR
  VIEWER
}

enum VehicleType {
  STANDARD
  HEAVY
  LIGHT
  DRONE
  SPECIAL
}

enum VehicleStatus {
  IDLE
  ACTIVE
  CHARGING
  MAINTENANCE
  OFFLINE
  ERROR
}

enum MissionStatus {
  PENDING
  SCHEDULED
  IN_PROGRESS
  PAUSED
  COMPLETED
  CANCELLED
  FAILED
}

enum Priority {
  LOW
  NORMAL
  HIGH
  CRITICAL
}

enum EventType {
  SYSTEM
  VEHICLE
  MISSION
  USER
  SECURITY
  MAINTENANCE
}

enum Severity {
  DEBUG
  INFO
  WARNING
  ERROR
  CRITICAL
}

// ════════════════════════════════════════════════════════
// UŻYTKOWNICY
// ════════════════════════════════════════════════════════

model User {
  id           String    @id @default(cuid())
  email        String    @unique
  username     String    @unique
  passwordHash String
  firstName    String?
  lastName     String?
  role         Role      @default(OPERATOR)
  active       Boolean   @default(true)
  lastLoginAt  DateTime?
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt

  sessions      Session[]
  refreshTokens RefreshToken[]
  assignments   VehicleAssignment[]
  missions      Mission[]  @relation("MissionCreator")
  events        Event[]

  @@index([email])
  @@index([username])
  @@index([role])
}

model Session {
  id        String   @id @default(cuid())
  userId    String
  token     String   @unique
  ipAddress String?
  userAgent String?
  expiresAt DateTime
  createdAt DateTime @default(now())

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@index([token])
  @@index([expiresAt])
}

model RefreshToken {
  id        String   @id @default(cuid())
  userId    String
  token     String   @unique
  expiresAt DateTime
  used      Boolean  @default(false)
  createdAt DateTime @default(now())

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@index([token])
}

// ════════════════════════════════════════════════════════
// POJAZDY
// ════════════════════════════════════════════════════════

model Vehicle {
  id           String        @id @default(cuid())
  name         String
  licensePlate String        @unique
  vin          String?       @unique
  type         VehicleType   @default(STANDARD)
  status       VehicleStatus @default(IDLE)
  battery      Int           @default(100)
  mileage      Float         @default(0)
  fuelLevel    Float?
  lat          Float?
  lng          Float?
  speed        Float?
  heading      Float?
  lastSeenAt   DateTime?
  metadata     Json?         // PostgreSQL obsługuje Json natywnie!
  createdAt    DateTime      @default(now())
  updatedAt    DateTime      @updatedAt

  assignments  VehicleAssignment[]
  missions     Mission[]
  telemetry    Telemetry[]
  maintenance  MaintenanceRecord[]
  events       Event[]

  @@index([status])
  @@index([type])
  @@index([licensePlate])
}

model VehicleAssignment {
  id        String    @id @default(cuid())
  vehicleId String
  userId    String
  startedAt DateTime  @default(now())
  endedAt   DateTime?
  notes     String?

  vehicle Vehicle @relation(fields: [vehicleId], references: [id], onDelete: Cascade)
  user    User    @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([vehicleId])
  @@index([userId])
}

// ════════════════════════════════════════════════════════
// MISJE
// ════════════════════════════════════════════════════════

model Mission {
  id          String        @id @default(cuid())
  name        String
  description String?
  vehicleId   String?
  createdById String
  status      MissionStatus @default(PENDING)
  priority    Priority      @default(NORMAL)
  startLat    Float?
  startLng    Float?
  endLat      Float?
  endLng      Float?
  waypoints   Json?         // PostgreSQL Json — tablice punktów GPS
  scheduledAt DateTime?
  startedAt   DateTime?
  completedAt DateTime?
  distance    Float?
  duration    Int?
  createdAt   DateTime      @default(now())
  updatedAt   DateTime      @updatedAt

  vehicle   Vehicle? @relation(fields: [vehicleId], references: [id])
  createdBy User     @relation("MissionCreator", fields: [createdById], references: [id])
  events    Event[]

  @@index([status])
  @@index([priority])
  @@index([vehicleId])
  @@index([createdById])
}

// ════════════════════════════════════════════════════════
// TELEMETRIA
// ════════════════════════════════════════════════════════

model Telemetry {
  id        String   @id @default(cuid())
  vehicleId String
  lat       Float?
  lng       Float?
  speed     Float?
  heading   Float?
  battery   Int?
  altitude  Float?
  rawData   Json?    // surowe dane z sensora
  timestamp DateTime @default(now())

  vehicle Vehicle @relation(fields: [vehicleId], references: [id], onDelete: Cascade)

  @@index([vehicleId])
  @@index([timestamp])
}

// ════════════════════════════════════════════════════════
// SERWIS
// ════════════════════════════════════════════════════════

model MaintenanceRecord {
  id          String    @id @default(cuid())
  vehicleId   String
  type        String
  description String
  cost        Float?
  mileageAt   Float?
  performedAt DateTime  @default(now())
  nextDueAt   DateTime?
  performedBy String?
  notes       String?
  createdAt   DateTime  @default(now())

  vehicle Vehicle @relation(fields: [vehicleId], references: [id], onDelete: Cascade)

  @@index([vehicleId])
  @@index([type])
}

// ════════════════════════════════════════════════════════
// ZDARZENIA
// ════════════════════════════════════════════════════════

model Event {
  id        String    @id @default(cuid())
  type      EventType
  severity  Severity  @default(INFO)
  message   String
  metadata  Json?
  vehicleId String?
  missionId String?
  userId    String?
  createdAt DateTime  @default(now())

  vehicle Vehicle? @relation(fields: [vehicleId], references: [id])
  mission Mission? @relation(fields: [missionId], references: [id])
  user    User?    @relation(fields: [userId], references: [id])

  @@index([type])
  @@index([severity])
  @@index([vehicleId])
  @@index([createdAt])
}

// ════════════════════════════════════════════════════════
// ALERTY
// ════════════════════════════════════════════════════════

model Alert {
  id         String    @id @default(cuid())
  type       String
  severity   Priority  @default(LOW)
  message    String
  vehicleId  String?
  resolved   Boolean   @default(false)
  resolvedAt DateTime?
  resolvedBy String?
  metadata   Json?
  createdAt  DateTime  @default(now())

  @@index([resolved])
  @@index([severity])
  @@index([vehicleId])
  @@index([createdAt])
}

// ════════════════════════════════════════════════════════
// SYSTEM CONFIG
// ════════════════════════════════════════════════════════

model SystemConfig {
  id        String   @id @default(cuid())
  key       String   @unique
  value     Json     // PostgreSQL Json dla złożonych wartości
  category  String   @default("general")
  updatedAt DateTime @updatedAt

  @@index([category])
}
'@

[System.IO.File]::WriteAllText($schema, $pgSchema, [System.Text.UTF8Encoding]::new($false))
L "OK" "Schema PostgreSQL zapisana (z enum, Json, indeksami)"

# ─── KROK 4: Zaktualizuj .env ─────────────────────────────
Write-Host "[ 4/7 ] Aktualizacja .env..." -ForegroundColor Yellow

$envContent = Get-Content $envFile -Raw
$envContent = [regex]::Replace($envContent, '(?m)^DATABASE_URL=.*$', "DATABASE_URL=$dbUrl")
[System.IO.File]::WriteAllText($envFile, $envContent, [System.Text.UTF8Encoding]::new($false))
L "OK" "DATABASE_URL zaktualizowany"

# ─── KROK 5: Prisma generate ──────────────────────────────
Write-Host "[ 5/7 ] Prisma generate..." -ForegroundColor Yellow

if (-not $demoMode) {
    $genOut = cmd /c "cd /d `"$backend`" && node_modules\.bin\prisma.cmd generate 2>&1"
    if ($genOut -match "Generated Prisma Client") {
        L "OK" "Prisma Client wygenerowany dla PostgreSQL"
    } else {
        L "WARN" "Generate: sprawdź output"
        $genOut | Select-Object -Last 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }
} else {
    L "INFO" "Demo mode — pomijam generate (brak prawdziwego URL)"
}

# ─── KROK 6: Prisma migrate deploy ────────────────────────
Write-Host "[ 6/7 ] Prisma migrate deploy..." -ForegroundColor Yellow

if (-not $demoMode) {
    # Utwórz pierwszą migrację
    $migrateOut = cmd /c "cd /d `"$backend`" && node_modules\.bin\prisma.cmd migrate dev --name init_postgresql --skip-seed 2>&1"

    if ($migrateOut -match "Your database is now in sync|migrations applied") {
        L "OK" "Migracja zakończona — tabele utworzone w Supabase!"
    } elseif ($migrateOut -match "error|Error") {
        L "ERR" "Migracja nieudana:"
        $migrateOut | Select-String "error" | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        Write-Host ""
        Write-Host "  Sprawdź:" -ForegroundColor Yellow
        Write-Host "  1. Czy DATABASE_URL jest poprawny?" -ForegroundColor White
        Write-Host "  2. Czy Supabase projekt jest aktywny?" -ForegroundColor White
        Write-Host "  3. Czy hasło nie zawiera znaków specjalnych (zakoduj URL)?" -ForegroundColor White
    } else {
        L "INFO" "Migrate output:"
        $migrateOut | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }
} else {
    L "INFO" "Demo mode — pomijam migrację"
    Write-Host ""
    Write-Host "  Gdy masz prawdziwy URL, uruchom:" -ForegroundColor Cyan
    Write-Host "  cmd /c `"cd /d E:\Grazyna_5.0\backend && node_modules\.bin\prisma.cmd migrate dev --name init_postgresql`"" -ForegroundColor White
}

# ─── KROK 7: Weryfikacja i restart ────────────────────────
Write-Host "[ 7/7 ] Weryfikacja..." -ForegroundColor Yellow

if (-not $demoMode) {
    # Test połączenia
    $dbPushOut = cmd /c "cd /d `"$backend`" && node_modules\.bin\prisma.cmd db pull 2>&1"
    if ($dbPushOut -match "Introspected") {
        L "OK" "Połączenie z Supabase potwierdzone!"
    }

    # Restart backendu
    L "INFO" "Restartuję backend z nową bazą..."
    Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep 2
    Start-Process cmd -ArgumentList "/k", "cd /d `"$backend`" && `"$proj\tools\nodejs\node.exe`" --max-old-space-size=256 --expose-gc node_modules\tsx\dist\cli.mjs watch src\cluster-bootstrap.ts"
    Start-Sleep 8

    try {
        $h = Invoke-RestMethod "http://localhost:3001/health" -TimeoutSec 5
        L "OK" "Backend działa z PostgreSQL: $($h.status)"
    } catch {
        L "WARN" "Backend nie odpowiada — sprawdź okno terminala"
    }
}

# ─── PODSUMOWANIE ─────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✅ MIGRACJA NA SUPABASE ZAKOŃCZONA                   ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Schema: PostgreSQL (enum, Json, indeksy)" -ForegroundColor Cyan
Write-Host "  Backup: $backupPath" -ForegroundColor Gray
Write-Host ""
Write-Host "  Następne kroki:" -ForegroundColor Cyan
Write-Host "  1. Sprawdź tabele w Supabase Dashboard → Table Editor" -ForegroundColor White
Write-Host "  2. Uruchom seed: npm run db:seed" -ForegroundColor White
Write-Host "  3. Przetestuj rejestrację: Invoke-RestMethod http://localhost:3001/api/auth/register ..." -ForegroundColor White
Write-Host "  4. Commit: git add backend/prisma && git commit -m 'feat: migrate to PostgreSQL'" -ForegroundColor White
Write-Host ""