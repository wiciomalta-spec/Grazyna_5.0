# 🔍 GRAŻYNA 5.0 — PEŁNA ANALIZA PROJEKTU
> Wygenerowano: 2026-05-29

---

## 1. GIT STATUS

| Element | Status |
|---|---|
| Branch | `main` |
| Sync z origin | ✅ Up to date |
| Untracked files | ⚠️ `Nowy Python File.py` (21505 B) — nie dodany do git |
| Ostatni commit | `c631501 chore: ignore tools/__init__.py` |
| Remote | `https://github.com/wiciomalta-spec/Grazyna_5.0.git` |

**Historia commitów (ostatnie 15):**
```
c631501 chore: ignore tools/__init__.py
07f6aa8 chore: ignore tools/__init__.py
d78c449 chore: remove tools/ from git, add to gitignore
7d43de8 chore: ignore old backup folders
50d20ef chore: remove binary tools from git tracking
2758230 Merge branch 'main' (merge commit)
9c0ef45 fix: migracja Node.js na E:, naprawa srodowiska v5.0
2ba5839 pre-patch backup
2a8b020 pre-auto-fix backup
```

---

## 2. NODE.EXE SYMLINK — PROBLEM ⚠️

```
FullName: E:\Grazyna_5.0\tools\nodejs\node.exe
LinkType: (PUSTE — nie jest symlinklem!)
Target:   (PUSTE)
```

**Diagnoza:** `node.exe` w `tools\nodejs\` to **prawdziwy plik** (70 MB), NIE symlink.
- Node v20.11.0 działa poprawnie
- npm v10.9.8 działa poprawnie
- Problem: duplikacja — `tools\nodejs\node.exe` (70MB) i `tools\nvm\nodejs\node.exe` (70MB) to dwie kopie tego samego pliku

**Naprawa:** Zamienić `tools\nodejs\node.exe` na symlink do `tools\nvm\nodejs\node.exe` (oszczędność 70MB)

---

## 3. PORTY SIECIOWE — STATUS

| Port | Status | Opis |
|---|---|---|
| **3001** | ✅ LISTENING (PID 21656) | **Backend GRAŻYNA działa!** |
| **5174** | ✅ LISTENING (PID 21124) | **Frontend Vite działa!** (port 5174 zamiast 5173) |
| 80 | LISTENING (PID 4) | System Windows |
| 8443 | LISTENING (PID 4) | HTTPS system |
| 1883 | LISTENING (PID 5360) | MQTT broker |

> ✅ **Backend i Frontend już działają!** Backend na :3001, Frontend na :5174

---

## 4. MAPA STRUKTURY PROJEKTU

```
E:\Grazyna_5.0\
├── 📁 backend/                    ← GŁÓWNY BACKEND (Node.js/TypeScript/Express)
│   ├── src/
│   │   ├── index.ts               ← Entry point (12287 B)
│   │   ├── metrics.ts             ← Prometheus metrics
│   │   ├── config/database.ts     ← Konfiguracja PostgreSQL/Prisma
│   │   ├── controllers/
│   │   │   ├── auth.controller.ts ← Autentykacja JWT
│   │   │   ├── kernel.controller.ts ← Kernel systemu
│   │   │   └── vehicle.controller.ts ← Zarządzanie flotą
│   │   ├── middleware/auth.ts     ← JWT middleware
│   │   ├── routes/index.ts        ← Routing API
│   │   └── services/
│   │       ├── kernel.service.ts  ← Logika kernela
│   │       └── driver-fabric.service.ts ← Serwis kierowców
│   ├── prisma/schema.prisma       ← Schema bazy danych
│   ├── dist/                      ← Skompilowany JS (gotowy do uruchomienia)
│   ├── package.json               ← grazyna-backend v5.0.0
│   ├── tsconfig.json
│   ├── .env                       ← PORT=3001, DB, Redis, JWT
│   └── start_grazyna.bat          ← Skrypt startowy Windows
│
├── 📁 frontend/                   ← GŁÓWNY FRONTEND (React/Vite/TypeScript)
│   ├── src/
│   │   ├── App.tsx                ← Root komponent
│   │   ├── main.tsx               ← Entry point React
│   │   ├── pages/
│   │   │   ├── Dashboard.tsx      ← Dashboard (5667 B)
│   │   │   ├── Kernel.tsx         ← Panel kernela
│   │   │   └── Login.tsx          ← Logowanie
│   │   ├── core/
│   │   │   ├── RuntimeKernel.ts   ← Runtime kernel
│   │   │   ├── CapabilityRegistry.ts ← Rejestr możliwości
│   │   │   └── SelfHealingState.ts ← Auto-naprawa stanu
│   │   ├── services/api.ts        ← Axios API client
│   │   ├── store/
│   │   │   ├── authStore.ts       ← Zustand auth store
│   │   │   └── runtimeStore.ts    ← Runtime store
│   │   └── styles/
│   │       ├── GlobalStyles.tsx   ← Styled-components global
│   │       └── theme.ts           ← Motyw aplikacji
│   ├── package.json               ← grazyna-frontend v5.0.0
│   ├── vite.config.ts             ← Vite config (port 5173)
│   ├── tsconfig.json
│   └── .env                       ← VITE_API_URL=http://localhost:3001/api
│
├── 📁 tools/                      ← Narzędzia lokalne (portable)
│   ├── nodejs/                    ← Node.js v20.11.0 (portable)
│   │   └── node.exe               ← 70MB — NIE symlink (problem!)
│   ├── nvm/nodejs/                ← Duplikat Node.js (70MB)
│   └── PythonPortable/            ← Python 3.10 portable
│
├── 📁 core/                       ← Python core (CLI)
│   ├── autocomplete.py
│   ├── command_registry.py
│   └── intent_parser.py
│
├── 📁 grazyna-system/             ← ⚠️ DUPLIKAT całego projektu!
│   ├── backend/                   ← Kopia backendu
│   ├── frontend/                  ← Kopia frontendu
│   └── ...                        ← Stara wersja systemu
│
├── 📁 scripts/                    ← Skrypty PowerShell/bash
├── 📁 manifests/                  ← JSON manifesty systemu
├── 📁 monitoring/                 ← Grafana + Prometheus
├── 📁 nginx/                      ← Nginx config
├── 📁 prisma/                     ← Root-level schema (stub 102B)
├── 📁 ahe/                        ← Agent Host Environment
├── 📁 _backup_fixroot/            ← Backup
├── 📁 _OLD_nested_Grazyna_5.0_*/  ← Stara zagnieżdżona kopia
├── 📁 backup_pre_deploy_*/        ← Backup przed deployem
│
├── .env                           ← Root .env (PORT=3001)
├── main.py                        ← Python CLI entry (2250 B)
├── main_cli.py                    ← CLI rozszerzony (4074 B)
├── docker-compose.yml             ← Docker dev
├── docker-compose.prod.yml        ← Docker prod
└── README.md                      ← Dokumentacja (9095 B)
```

---

## 5. ANALIZA BŁĘDÓW I PROBLEMÓW

### 🔴 KRYTYCZNE

| # | Problem | Lokalizacja | Naprawa |
|---|---|---|---|
| 1 | **Duplikat projektu** | `grazyna-system/` = kopia całego projektu | Usunąć lub zarchiwizować |
| 2 | **Duplikat node.exe** | `tools/nodejs/` i `tools/nvm/nodejs/` | Zamienić na symlink |
| 3 | **Root prisma/schema.prisma** | Tylko 102B — stub, nie używany | Usunąć lub uzupełnić |
| 4 | **database.js w src/config/** | `backend/src/config/database.js` obok `database.ts` | Usunąć .js (konflikt) |

### 🟡 OSTRZEŻENIA

| # | Problem | Lokalizacja | Naprawa |
|---|---|---|---|
| 5 | `__init__.py` w katalogach TS | `backend/`, `backend/src/`, wszystkie podkatalogi | Usunąć (Python w projekcie Node.js) |
| 6 | `Nowy Python File.py` (21KB) | Root projektu | Dodać do .gitignore lub usunąć |
| 7 | `build-backend.log'` (z apostrofem) | Root | Usunąć (błędna nazwa) |
| 8 | `Nowy dokument tekstowy.txt` | Root i `backend/` | Usunąć |
| 9 | Frontend .env brakuje zmiennych | `frontend/.env` | Dodać VITE_ENV, VITE_DEBUG |
| 10 | `vite.env.d.ts` niezgodność | Deklaruje VITE_ENV/VITE_DEBUG, .env ich nie ma | Zsynchronizować |
| 11 | Duże pliki w root | `analiza_structury_20260528.csv` (25MB), `katalog.txt` (13MB), `drzewo_*.txt` (15MB) | Dodać do .gitignore |
| 12 | `metrics.ts` w root backend/ | `backend/metrics.ts` obok `backend/src/metrics.ts` | Usunąć duplikat z root |

### 🟢 OK

| Element | Status |
|---|---|
| Backend Node.js (dist/) | ✅ Skompilowany, działa na :3001 |
| Frontend Vite | ✅ Działa na :5174 |
| Node.js v20.11.0 | ✅ Spełnia wymóg >=18.0.0 |
| npm v10.9.8 | ✅ Spełnia wymóg >=9.0.0 |
| Git remote | ✅ Skonfigurowany |
| .env backend | ✅ Kompletny |
| .env frontend | ⚠️ Niekompletny (brak VITE_ENV, VITE_DEBUG) |

---

## 6. ZALEŻNOŚCI — ANALIZA

### Backend (`backend/package.json`)
- **Express** 4.18.2 + TypeScript 5.3.3 ✅
- **Prisma** 5.9.1 (ORM PostgreSQL) ✅
- **Socket.io** 4.6.1 (WebSocket) ✅
- **Bull** 4.12.2 (kolejki Redis) ✅
- **Winston** 3.11.0 (logging) ✅
- **tsx** 4.7.0 (dev runner) ✅
- ⚠️ `prom-client` w root `package.json` to v15.1.3, w backend to v14.2.0 — **niezgodność wersji!**

### Frontend (`frontend/package.json`)
- **React** 18.2.0 + Vite 5.1.0 ✅
- **Zustand** 4.5.0 (state management) ✅
- **styled-components** 6.1.8 ✅
- **react-query** 3.39.3 ⚠️ (stara wersja — TanStack Query v5 dostępny)
- **mapbox-gl** 3.1.2 + **react-leaflet** 4.2.1 ⚠️ (dwie biblioteki map — redundancja)
- **react-beautiful-dnd** 13.1.1 ⚠️ (niezalecany, brak wsparcia React 18)

---

## 7. KOMENDY DO URUCHOMIENIA

### Backend (już działa na :3001)
```powershell
cd E:\Grazyna_5.0\backend
# Dev mode (z hot-reload):
.\..\..\tools\nodejs\npm.cmd run dev
# LUB production (z dist/):
.\..\..\tools\nodejs\node.exe dist/index.js
```

### Frontend (już działa na :5174)
```powershell
cd E:\Grazyna_5.0\frontend
.\..\..\tools\nodejs\npm.cmd run dev
```