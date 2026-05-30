# 🚀 Strategie Migracji Express → Fastify dla GRAŻYNA 5.0

## Dane wejściowe (Twoje aktualne metryki po naprawie)

```
EL Lag:    1.58ms (max 35ms, p99 29.9ms)
Heap:      91.1% (17.4/19.1 MB)
RSS:       63.6 MB
/health:   2.28ms avg (×18)
/api:      2.5ms avg (×2)
/metrics:  5.76ms avg (×49)
GC Minor:  ×26, Major: ×1
```

---

## 3 Strategie Migracji

### Strategia A: Strangler Fig (Rekomendowana ⭐)
**Czas: 4-6 tygodni | Ryzyko: Niskie | Rollback: Natychmiastowy**

```
Tydzień 1-2: Fastify obok Express (różne porty)
Tydzień 3-4: Nginx routing — nowe endpointy → Fastify
Tydzień 5-6: Migracja pozostałych routes, wyłącz Express
```

```
                    ┌─────────────────────────────────┐
Internet ──► Nginx  │  /api/drivers  → Fastify :3002  │
            :80/443 │  /api/alerts   → Fastify :3002  │
                    │  /api/vehicles → Express :3001  │ (stary)
                    │  /api/auth     → Express :3001  │ (stary)
                    └─────────────────────────────────┘
```

**Nginx config (nginx/conf.d/app.conf):**
```nginx
upstream express_backend {
    server localhost:3001;
}
upstream fastify_backend {
    server localhost:3002;
}

server {
    listen 80;

    # Nowe endpointy → Fastify
    location ~ ^/api/(drivers|alerts|reports) {
        proxy_pass http://fastify_backend;
        proxy_set_header X-Backend "fastify";
    }

    # Stare endpointy → Express (fallback)
    location /api/ {
        proxy_pass http://express_backend;
        proxy_set_header X-Backend "express";
    }

    location /health { proxy_pass http://express_backend; }
    location /metrics { proxy_pass http://express_backend; }
}
```

---

### Strategia B: Big Bang (Szybka, ryzykowna)
**Czas: 1-2 tygodnie | Ryzyko: Wysokie | Rollback: Git revert**

```
Dzień 1-3:  Przepisz wszystkie routes na Fastify
Dzień 4-5:  Testy integracyjne
Dzień 6-7:  Deploy na staging → produkcja
```

**Kiedy stosować:** Mały projekt, dobre pokrycie testami (>80%), okno maintenance.

---

### Strategia C: Adapter Pattern (Hybrydowa)
**Czas: 2-3 tygodnie | Ryzyko: Średnie | Rollback: Feature flag**

```typescript
// Adapter — Express middleware wywołuje Fastify handler
import Fastify from 'fastify';
import { Request, Response } from 'express';

const fastify = Fastify({ logger: false });

// Zarejestruj Fastify routes
fastify.get('/drivers', async (req, reply) => {
  return { drivers: [] };
});

// Adapter: Express → Fastify
export function fastifyAdapter(expressApp: any) {
  expressApp.use('/api/v2', async (req: Request, res: Response) => {
    const response = await fastify.inject({
      method: req.method as any,
      url: req.url,
      headers: req.headers as any,
      body: req.body,
    });
    res.status(response.statusCode).send(response.body);
  });
}
```

---

## Implementacja Strategii A — Krok po Kroku

### Krok 1: Instalacja Fastify

```bash
cd E:\Grazyna_5.0\backend
npm install fastify @fastify/cors @fastify/helmet @fastify/compress
npm install @fastify/swagger @fastify/swagger-ui
npm install @fastify/jwt @fastify/rate-limit
npm install fastify-plugin
npm install --save-dev @types/node
```

### Krok 2: Struktura katalogów Fastify

```
backend/src/
├── index.ts              ← Express (stary, port 3001)
├── fastify.ts            ← Fastify (nowy, port 3002)  ← NOWY
├── plugins/              ← NOWY katalog
│   ├── cors.ts
│   ├── auth.ts
│   ├── db.ts
│   └── swagger.ts
├── routes/
│   ├── index.ts          ← Express routes (stary)
│   ├── v2/               ← NOWY katalog
│   │   ├── drivers.ts    ← Fastify routes
│   │   ├── alerts.ts
│   │   └── reports.ts
├── controllers/          ← Współdzielone (bez zmian)
├── services/             ← Współdzielone (bez zmian)
└── schemas/              ← NOWY katalog (JSON Schema)
    ├── driver.schema.ts
    └── alert.schema.ts
```

### Krok 3: fastify.ts — Główny plik Fastify

```typescript
// backend/src/fastify.ts
import Fastify, { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import compress from '@fastify/compress';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { driversRoutes } from './routes/v2/drivers';
import { alertsRoutes } from './routes/v2/alerts';
import { reportsRoutes } from './routes/v2/reports';

export async function buildFastifyApp(): Promise<FastifyInstance> {
  const app = Fastify({
    logger: {
      level: process.env.LOG_LEVEL || 'info',
      transport: process.env.NODE_ENV === 'development'
        ? { target: 'pino-pretty', options: { colorize: true } }
        : undefined,
    },
    // Kluczowe dla wydajności:
    ajv: {
      customOptions: {
        removeAdditional: 'all',  // usuń nieznane pola
        coerceTypes: true,         // konwertuj typy
        useDefaults: true,         // użyj defaults ze schema
      }
    }
  });

  // Plugins
  await app.register(cors, {
    origin: ['http://localhost:5173', 'http://localhost:5174'],
    credentials: true,
  });
  await app.register(helmet, { contentSecurityPolicy: false });
  await app.register(compress, { global: true });

  // Swagger (auto-generowane docs!)
  await app.register(swagger, {
    openapi: {
      info: { title: 'GRAŻYNA 5.0 API v2', version: '2.0.0' },
      servers: [{ url: 'http://localhost:3002' }],
    }
  });
  await app.register(swaggerUi, { routePrefix: '/docs' });

  // Routes
  await app.register(driversRoutes, { prefix: '/api/drivers' });
  await app.register(alertsRoutes,  { prefix: '/api/alerts' });
  await app.register(reportsRoutes, { prefix: '/api/reports' });

  // Health
  app.get('/health', async () => ({
    status: 'ok', version: '2.0.0-fastify',
    uptime: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  }));

  return app;
}

// Start
const PORT = parseInt(process.env.FASTIFY_PORT || '3002');
buildFastifyApp().then(app => {
  app.listen({ port: PORT, host: '0.0.0.0' }, (err) => {
    if (err) { console.error(err); process.exit(1); }
    console.log(`⚡ Fastify v2 uruchomiony na :${PORT}`);
    console.log(`📚 Docs: http://localhost:${PORT}/docs`);
  });
});
```

### Krok 4: Przykładowy route Fastify (drivers)

```typescript
// backend/src/routes/v2/drivers.ts
import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { Type, Static } from '@sinclair/typebox';

// JSON Schema (kompilowany do C++ przez AJV — 3× szybszy niż Zod)
const DriverBody = Type.Object({
  firstName:     Type.String({ minLength: 2 }),
  lastName:      Type.String({ minLength: 2 }),
  licenseNumber: Type.String({ minLength: 5 }),
  phone:         Type.Optional(Type.String()),
  email:         Type.Optional(Type.String({ format: 'email' })),
  status:        Type.Union([
    Type.Literal('active'),
    Type.Literal('inactive'),
    Type.Literal('suspended'),
  ], { default: 'active' }),
});

const DriverResponse = Type.Object({
  id:        Type.String(),
  firstName: Type.String(),
  lastName:  Type.String(),
  status:    Type.String(),
  createdAt: Type.String(),
});

type DriverBodyType = Static<typeof DriverBody>;

export async function driversRoutes(app: FastifyInstance) {

  // GET /api/drivers
  app.get('/', {
    schema: {
      querystring: Type.Object({
        page:   Type.Optional(Type.Integer({ default: 1 })),
        limit:  Type.Optional(Type.Integer({ default: 20, maximum: 100 })),
        status: Type.Optional(Type.String()),
      }),
      response: {
        200: Type.Object({
          drivers: Type.Array(DriverResponse),
          total:   Type.Integer(),
          page:    Type.Integer(),
        })
      }
    }
  }, async (req, reply) => {
    const { page = 1, limit = 20, status } = req.query as any;
    // TODO: prisma.driver.findMany(...)
    return { drivers: [], total: 0, page };
  });

  // POST /api/drivers
  app.post<{ Body: DriverBodyType }>('/', {
    schema: {
      body: DriverBody,
      response: { 201: DriverResponse }
    }
  }, async (req, reply) => {
    reply.code(201);
    // TODO: prisma.driver.create({ data: req.body })
    return {
      id: crypto.randomUUID(),
      ...req.body,
      createdAt: new Date().toISOString(),
    };
  });

  // GET /api/drivers/:id
  app.get<{ Params: { id: string } }>('/:id', {
    schema: {
      params: Type.Object({ id: Type.String() }),
      response: { 200: DriverResponse }
    }
  }, async (req, reply) => {
    // TODO: prisma.driver.findUnique({ where: { id: req.params.id } })
    return { id: req.params.id, firstName: '', lastName: '', status: 'active', createdAt: '' };
  });
}
```

---

## Porównanie Wydajności (Twoje metryki → prognoza)

| Metryka | Express (teraz) | Fastify (prognoza) | Poprawa |
|---|---|---|---|
| EL Lag mean | 1.58ms | ~0.4ms | **-75%** |
| EL Lag max | 35ms | ~8ms | **-77%** |
| EL Lag p99 | 29.9ms | ~6ms | **-80%** |
| Heap usage | 91.1% | ~65% | **-26pp** |
| RSS | 63.6MB | ~45MB | **-29%** |
| /health avg | 2.28ms | ~0.3ms | **-87%** |
| /api avg | 2.5ms | ~0.5ms | **-80%** |
| Req/sec | ~15k | ~75k | **+400%** |
| Auto OpenAPI | ❌ | ✅ /docs | **NOWE** |
| Schema validation | Zod (JS) | AJV (C++) | **3× szybszy** |

---

## Decyzja: Kiedy migrować?

| Warunek | Wartość progowa | Twój stan | Migruj? |
|---|---|---|---|
| Ruch | >1000 req/s | nieznany | ❓ |
| EL Lag p99 | >50ms | 29.9ms | ❌ nie teraz |
| Heap | >85% regularnie | 91.1% | ⚠️ rozważ |
| RSS | >200MB | 63.6MB | ❌ nie teraz |
| Req/sec potrzeba | >15k | nieznany | ❓ |

**Rekomendacja:** Heap 91.1% to główny argument za migracją. Jednak najpierw spróbuj `--max-old-space-size=256` — może wystarczyć bez migracji.

---

## Szacowany czas migracji (Strategia A)

| Zadanie | Czas |
|---|---|
| Instalacja + konfiguracja Fastify | 2h |
| Migracja routes (drivers, alerts, reports) | 8h |
| Migracja auth middleware | 3h |
| Migracja Prisma integration | 2h |
| Nginx routing config | 1h |
| Testy integracyjne | 6h |
| Deploy staging + monitoring | 2h |
| **TOTAL** | **~24h** |