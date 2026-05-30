# ⚡ Express vs Fastify — Analiza dla GRAŻYNA 5.0

## Dane z Twoich metryk (rzeczywiste!)

```
Backend: Node.js v20.11.0
RSS: 60.3 MB
Heap: 15.1 MB / 16.1 MB (93.8%)
Event loop lag: 19ms (max spike: 869ms!)
GET /health avg: 2.3ms
GET /api avg: 862ms (problem z routingiem)
```

---

## 📊 Porównanie Wydajności

| Metryka | Express 4.18 | Fastify 4.x | Różnica |
|---|---|---|---|
| Req/sec (hello world) | ~15,000 | ~75,000 | **5× szybszy** |
| Req/sec (JSON) | ~12,000 | ~65,000 | **5.4× szybszy** |
| Latencja p50 | ~2ms | ~0.4ms | **5× niższa** |
| Latencja p99 | ~8ms | ~1.5ms | **5× niższa** |
| Memory (startup) | ~45MB | ~35MB | **22% mniej** |
| Cold start | ~800ms | ~400ms | **2× szybszy** |
| Throughput (MB/s) | ~180 | ~850 | **4.7× wyższy** |

> Źródło: fastify.io/benchmarks, TechEmpower Framework Benchmarks 2024

---

## 🔍 Analiza Twoich Metryk

### Problem 1: Event Loop Lag 869ms (KRYTYCZNY)
```
nodejs_eventloop_lag_max_seconds 0.869269503  ← SPIKE!
nodejs_eventloop_lag_seconds     0.0190031    ← aktualny
nodejs_eventloop_lag_p99_seconds 0.024756223  ← normalny
```
**Przyczyna w Express:** Synchroniczne middleware blokuje event loop.
**Fastify rozwiązanie:** Async-first design, schema validation w C++ (fast-json-stringify).

### Problem 2: Heap 93.8% (WYSOKI)
```
heap_used:  15.1 MB / 16.1 MB = 93.8%
```
**Express:** Brak wbudowanego schema validation → więcej obiektów JS w heap.
**Fastify:** JSON Schema kompilowany do kodu → mniej alokacji.

### Problem 3: /api 862ms response time
**Przyczyna:** Brak zarejestrowanego route → Express przechodzi przez WSZYSTKIE middleware.
**Fastify:** Radix tree router → O(1) lookup, nie O(n).

---

## 🏗️ Architektura Porównawcza

### Express (aktualny)
```typescript
// Middleware chain — sekwencyjne
app.use(helmet())
app.use(cors())
app.use(compression())
app.use(morgan())
app.use('/api', router)  // ← jeśli tu błąd → 404 po przejściu WSZYSTKICH middleware

// Brak wbudowanej walidacji → ręczny Zod
const parsed = DriverSchema.safeParse(req.body)  // JS validation
```

### Fastify (alternatywa)
```typescript
// Plugin system — równoległe, izolowane
await fastify.register(cors, { origin: true })
await fastify.register(helmet)

// Wbudowana walidacja JSON Schema (C++ ajv)
fastify.post('/drivers', {
  schema: {
    body: {
      type: 'object',
      required: ['firstName', 'lastName'],
      properties: {
        firstName: { type: 'string', minLength: 2 },
        lastName:  { type: 'string', minLength: 2 },
      }
    },
    response: {
      200: { type: 'object', properties: { id: { type: 'string' } } }
    }
  }
}, async (request, reply) => {
  return { id: 'created' }
})
```

---

## ✅ Zalety Express (aktualny stack)

| Zaleta | Opis |
|---|---|
| **Ekosystem** | 60,000+ middleware na npm |
| **Znajomość** | Największa baza wiedzy/tutoriali |
| **Prisma** | Pełne wsparcie, dużo przykładów |
| **Socket.io** | Natywna integracja |
| **Migracja** | Brak kosztów — już używasz |
| **TypeScript** | Dobre typy (@types/express) |
| **Stabilność** | 13+ lat produkcji |

## ✅ Zalety Fastify (alternatywa)

| Zaleta | Opis |
|---|---|
| **Wydajność** | 5× szybszy niż Express |
| **Schema validation** | Wbudowany, kompilowany do C++ |
| **TypeScript** | Natywny (nie @types) |
| **Plugin system** | Izolacja, enkapsulacja |
| **OpenAPI** | Auto-generowanie docs (@fastify/swagger) |
| **Hooks** | onRequest, preHandler, onSend, onError |
| **Serialization** | fast-json-stringify (3× szybszy) |

## ❌ Wady Express

| Wada | Wpływ na GRAŻYNA |
|---|---|
| Brak schema validation | Ręczny Zod w każdym route |
| Sekwencyjne middleware | Event loop lag spikes |
| Wolny JSON stringify | Większy heap usage |
| Brak wbudowanego DI | Ręczne zarządzanie zależnościami |

## ❌ Wady Fastify

| Wada | Wpływ na GRAŻYNA |
|---|---|
| Mniejszy ekosystem | Niektóre Express middleware nie działają |
| Inna filozofia | Wymaga przepisania routerów |
| Socket.io | Wymaga @fastify/websocket lub osobnego serwera |
| Krzywa uczenia | 2-4 tygodnie adaptacji |
| Migracja | ~40h pracy dla GRAŻYNA 5.0 |

---

## 🎯 Rekomendacja dla GRAŻYNA 5.0

### Krótkoterminowo (teraz): **Zostań przy Express + napraw problemy**

```typescript
// FIX 1: Kolejność middleware (najważniejsze!)
app.get('/health', healthHandler)  // ← PRZED app.use('/api', router)
app.get('/metrics', metricsHandler)
app.use('/api', router)            // ← router API
app.use(notFoundHandler)           // ← catch-all NA KOŃCU

// FIX 2: CORS dla :5174
cors({ origin: ['http://localhost:5173', 'http://localhost:5174'] })

// FIX 3: Event loop — unikaj synchronicznych operacji w middleware
// Zamiast: JSON.parse(bigData) synchronicznie
// Użyj: await parseAsync(bigData)
```

### Długoterminowo (v6.0): **Migracja do Fastify**

Kiedy warto migrować:
- Ruch > 1000 req/s
- Latencja p99 > 50ms
- Heap usage > 80% regularnie
- Potrzebujesz auto-generowanych OpenAPI docs

### Szybka wygrana bez migracji: **Express + Fastify JSON serializer**

```bash
npm install fast-json-stringify
```
```typescript
import stringify from 'fast-json-stringify'
const fastStringify = stringify({ type: 'object', properties: { ... } })
res.send(fastStringify(data))  // 3× szybszy JSON
```

---

## 📈 Prognoza po naprawie Express

| Metryka | Przed | Po naprawie Express | Po migracji Fastify |
|---|---|---|---|
| /health latency | 404 | ~1ms | ~0.3ms |
| /api latency | 862ms | ~5ms | ~1ms |
| Event loop lag | 19ms | ~5ms | ~2ms |
| Heap usage | 93.8% | ~70% | ~55% |
| RSS | 60MB | ~55MB | ~40MB |

---

## 🔧 Migracja Express → Fastify (jeśli zdecydujesz)

```bash
# 1. Instalacja
npm install fastify @fastify/cors @fastify/helmet @fastify/compress
npm install @fastify/swagger @fastify/swagger-ui
npm install fastify-socket.io  # lub @fastify/websocket

# 2. Struktura
backend/src/
├── app.ts          # fastify instance
├── plugins/        # cors, helmet, db, auth
├── routes/         # v1/vehicles, v1/drivers
└── schemas/        # JSON Schema definitions

# 3. Szacowany czas migracji
# - Routes:      ~16h
# - Middleware:  ~4h
# - Tests:       ~8h
# - Total:       ~28-40h
```