# 🦞 GRAŻYNA 5.0 - System Zarządzania Flotą

> Zaawansowany system autonomicznego zarządzania flotą pojazdów z dashboardem w czasie rzeczywistym.

![Version](https://img.shields.io/badge/version-5.0.0-purple.svg)
![Node](https://img.shields.io/badge/node-%3E%3D18-green.svg)
![TypeScript](https://img.shields.io/badge/TypeScript-5.3-blue.svg)
![React](https://img.shields.io/badge/React-18.2-cyan.svg)

## 📋 Spis Treści

- [Szybki Start](#-szybki-start)
- [Wymagania](#-wymagania)
- [Instalacja](#-instalacja)
- [Architektura](#-architektura)
- [Hybrid Kernel](#-hybrid-kernel)
- [Konfiguracja](#-konfiguracja)
- [Uruchomienie](#-uruchomienie)
- [API Endpoints](#-api-endpoints)
- [Docker](#-docker)
- [Rozwiązywanie problemów](#-rozwiązywanie-problemów)

---

## 🚀 Szybki Start

```bash
# 1. Sklonuj/rozpakuj projekt
cd grazyna-system

# 2. Uruchom automatyczny instalator
chmod +x install.sh
./install.sh

# 3. Uruchom system
./start.sh
```

Otwórz w przeglądarce: **http://localhost:5173**

**Domyślne dane logowania:**
- Admin: `admin@grazyna.local` / `admin123`
- Operator: `operator@grazyna.local` / `operator123`

---

## 📦 Wymagania

| Komponent | Wersja | Wymagany |
|-----------|--------|----------|
| Node.js   | ≥ 18.x | ✅ |
| npm       | ≥ 9.x  | ✅ |
| Python    | ≥ 3.8  | ✅ |
| Docker    | ≥ 24.x | 🟡 Zalecany |
| PostgreSQL| ≥ 15   | ✅ (lub Docker) |
| Redis     | ≥ 7    | ✅ (lub Docker) |

---

## 💾 Instalacja

### Opcja A: Automatyczna (zalecana)

```bash
./install.sh
```

Skrypt automatycznie:
- ✓ Sprawdzi wymagania systemowe
- ✓ Zainstaluje zależności frontend i backend
- ✓ Skonfiguruje zmienne środowiskowe (.env)
- ✓ Uruchomi PostgreSQL + Redis w Docker
- ✓ Utworzy skrypty startowe

### Opcja B: Ręczna

```bash
# Frontend
cd frontend
npm install

# Backend
cd ../backend
npm install
npx prisma generate
npx prisma migrate dev --name init
npm run db:seed
```

---

## 🏗️ Architektura

```
grazyna-system/
├── 📁 frontend/              # React + TypeScript + Vite
│   ├── src/
│   │   ├── components/       # Komponenty UI
│   │   │   └── Layout/       # MainLayout, TopBar, Sidebar
│   │   ├── pages/            # Strony aplikacji
│   │   ├── styles/           # Theme + GlobalStyles
│   │   ├── services/         # API clients
│   │   ├── store/            # Zustand state
│   │   └── hooks/            # Custom React hooks
│   └── package.json
│
├── 📁 backend/               # Node.js + Express + Prisma
│   ├── src/
│   │   ├── controllers/      # Logika biznesowa
│   │   ├── routes/           # API routing
│   │   ├── middleware/       # Auth, validation
│   │   ├── config/           # Database, env
│   │   └── database/         # Seeds
│   ├── prisma/
│   │   └── schema.prisma     # Schema bazy danych
│   └── package.json
│
├── 🐳 docker-compose.yml     # Pełny stack
├── 📜 install.sh             # Instalator
├── ▶️ start.sh               # Uruchomienie
└── ⏹️ stop.sh                # Zatrzymanie
```

## 🧠 Hybrid Kernel

System został rozszerzony o warstwę autonomicznego rdzenia, która:
- profiluje środowisko wykonawcze,
- dobiera tryb pracy (`minimal`, `balanced`, `turbo`, `portable`, `autonomous`),
- utrzymuje katalog zdolności i sterowników hybrydowych,
- wspiera tryb degradacji i offline-first,
- posiada stronę `/kernel` do diagnostyki runtime.

### Endpointy kernel:
- `GET /api/kernel/profile`
- `GET /api/kernel/blueprint`
- `GET /api/kernel/drivers`
- `POST /api/kernel/adapt`

### Tryb portable:
```bash
chmod +x scripts/portable-start.sh
./scripts/portable-start.sh
```

### Stack technologiczny:

**Frontend:**
- React 18 + TypeScript 5
- Vite 5 (build tool + dev server)
- Styled Components 6
- Framer Motion (animacje)
- React Router 6
- Zustand (state management)
- Axios + Socket.IO Client
- Recharts (wykresy)
- React Leaflet + Mapbox (mapy)

**Backend:**
- Node.js 20 + Express 4
- TypeScript 5
- Prisma ORM 5
- PostgreSQL 15
- Redis 7 (cache)
- Socket.IO 4 (real-time)
- JWT + Bcrypt (auth)
- Zod (walidacja)
- Winston (logging)

---

## ⚙️ Konfiguracja

### Frontend (`frontend/.env`):

```env
VITE_API_URL=http://localhost:3001/api
VITE_WS_URL=ws://localhost:3001
VITE_APP_NAME=GRAŻYNA 5.0
VITE_APP_VERSION=5.0.0
VITE_MAP_API_KEY=your_mapbox_key_here
```

### Backend (`backend/.env`):

```env
NODE_ENV=development
PORT=3001
DATABASE_URL=postgresql://grazyna:grazyna123@localhost:5432/grazyna_db
REDIS_URL=redis://localhost:6379
JWT_SECRET=<generated-by-installer>
CORS_ORIGIN=http://localhost:5173
LOG_LEVEL=debug
```

---

## ▶️ Uruchomienie

### Development:

```bash
./start.sh
```

Otworzy:
- Frontend: http://localhost:5173
- Backend API: http://localhost:3001/api
- API Health: http://localhost:3001/api/health

### Manualne uruchomienie (osobne terminale):

```bash
# Terminal 1 - Backend
cd backend && npm run dev

# Terminal 2 - Frontend
cd frontend && npm run dev
```

### Zatrzymanie:

```bash
./stop.sh
```

---

## 🔌 API Endpoints

### Autoryzacja:

| Method | Endpoint | Opis | Auth |
|--------|----------|------|------|
| POST   | `/api/auth/login` | Logowanie | ❌ |
| POST   | `/api/auth/register` | Rejestracja | ❌ |
| GET    | `/api/auth/me` | Aktualny użytkownik | ✅ |

### Pojazdy:

| Method | Endpoint | Opis | Auth |
|--------|----------|------|------|
| GET    | `/api/vehicles` | Lista pojazdów | ✅ |
| GET    | `/api/vehicles/:id` | Szczegóły pojazdu | ✅ |
| POST   | `/api/vehicles` | Dodaj pojazd | ADMIN/MANAGER |
| PATCH  | `/api/vehicles/:id` | Aktualizuj pojazd | OPERATOR+ |
| DELETE | `/api/vehicles/:id` | Usuń pojazd | ADMIN |
| GET    | `/api/vehicles/stats/summary` | Statystyki | ✅ |

### Przykład użycia:

```bash
# Login
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@grazyna.local","password":"admin123"}'

# Lista pojazdów (z tokenem)
curl http://localhost:3001/api/vehicles \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### WebSocket Events:

```javascript
// Frontend connection
const socket = io('http://localhost:3001', {
  auth: { token: 'YOUR_JWT_TOKEN' }
});

socket.on('vehicle-update', (data) => {
  console.log('Vehicle update:', data);
});

socket.emit('subscribe-vehicle', vehicleId);
```

---

## 🐳 Docker

### Tylko bazy danych (development):

```bash
docker-compose up -d postgres redis
```

### Pełny stack produkcyjny:

```bash
docker-compose --profile production up -d
```

### Z PgAdmin (GUI dla bazy):

```bash
docker-compose --profile tools up -d
```
PgAdmin: http://localhost:5050 (`admin@grazyna.local` / `admin`)

### Komendy:

```bash
docker-compose ps              # Status kontenerów
docker-compose logs -f         # Logi w czasie rzeczywistym
docker-compose down            # Zatrzymaj
docker-compose down -v         # Zatrzymaj + usuń wolumeny
```

---

## 🧪 Testy

```bash
# Frontend
cd frontend
npm run test               # Vitest
npm run test:coverage      # Z coverage

# Backend
cd backend
npm run test
```

---

## 📊 Baza Danych

### Migracje:

```bash
cd backend
npx prisma migrate dev --name nazwa_migracji  # Nowa migracja
npx prisma migrate deploy                      # Produkcja
npx prisma studio                              # GUI przeglądarka
```

### Seed (przykładowe dane):

```bash
npm run db:seed
```

### Reset bazy:

```bash
npx prisma migrate reset
```

---

## 🔧 Rozwiązywanie problemów

### ❌ Port 5173/3001 zajęty:
```bash
# Linux/Mac
lsof -ti:5173 | xargs kill -9
lsof -ti:3001 | xargs kill -9

# Windows
netstat -ano | findstr :5173
taskkill /PID <PID> /F
```

### ❌ Błąd połączenia z PostgreSQL:
```bash
# Sprawdź czy działa
docker ps | grep postgres

# Restart
docker restart grazyna-postgres

# Logi
docker logs grazyna-postgres
```

### ❌ Prisma client nie wygenerowany:
```bash
cd backend
npx prisma generate
```

### ❌ Node modules problemy:
```bash
rm -rf node_modules package-lock.json
npm install
```

---

## 🤝 Role użytkowników

| Rola | Uprawnienia |
|------|-------------|
| **ADMIN** | Pełne uprawnienia, zarządzanie użytkownikami |
| **MANAGER** | Zarządzanie flotą i misjami |
| **OPERATOR** | Aktualizacja statusu pojazdów, misje |
| **VIEWER** | Tylko do odczytu |

---

## 📚 Dokumentacja dodatkowa

- [Prisma Docs](https://www.prisma.io/docs)
- [React Docs](https://react.dev)
- [Express Docs](https://expressjs.com)
- [Socket.IO Docs](https://socket.io/docs/v4)

---

## 📝 Licencja

MIT License - swobodne wykorzystanie komercyjne i niekomercyjne.

---

## 🦞 Autorzy

**GRAŻYNA 5.0 Team** - 2026

> "Autonomous fleet management, powered by intelligence."
![CI](https://github.com/wiciomalta-spec/Grazyna_5.0/actions/workflows/ci.yml/badge.svg)
![CI](https://github.com/wiciomalta-spec/Grazyna_5.0/actions/workflows/ci.yml/badge.svg)
