// ============================================================
// GRAŻYNA 5.0 — k6 Load Test
// Instalacja: winget install k6 --source winget
// Uruchomienie: k6 run GRAZYNA_K6_LOADTEST.js
// Lub z opcjami: k6 run --vus 50 --duration 60s GRAZYNA_K6_LOADTEST.js
// ============================================================

import http from 'k6/http';
import ws   from 'k6/ws';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter, Gauge } from 'k6/metrics';

// ─── CUSTOM METRICS ───────────────────────────────────────
const errorRate      = new Rate('error_rate');
const authDuration   = new Trend('auth_duration_ms',   true);
const apiDuration    = new Trend('api_duration_ms',    true);
const healthDuration = new Trend('health_duration_ms', true);
const wsDuration     = new Trend('ws_duration_ms',     true);
const totalRequests  = new Counter('total_requests');
const activeUsers    = new Gauge('active_users');

// ─── KONFIGURACJA ─────────────────────────────────────────
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3001';
const WS_URL   = __ENV.WS_URL   || 'ws://localhost:3001';

// ─── SCENARIUSZE OBCIĄŻENIA ────────────────────────────────
export const options = {
  scenarios: {
    // Scenariusz 1: Smoke test (weryfikacja podstawowa)
    smoke: {
      executor:  'constant-vus',
      vus:       2,
      duration:  '30s',
      tags:      { scenario: 'smoke' },
      startTime: '0s',
    },

    // Scenariusz 2: Load test (normalny ruch)
    load: {
      executor:  'ramping-vus',
      startVUs:  0,
      stages: [
        { duration: '30s', target: 20  },  // ramp-up
        { duration: '60s', target: 20  },  // plateau
        { duration: '30s', target: 0   },  // ramp-down
      ],
      tags:      { scenario: 'load' },
      startTime: '35s',
    },

    // Scenariusz 3: Stress test (granica wytrzymałości)
    stress: {
      executor:  'ramping-vus',
      startVUs:  0,
      stages: [
        { duration: '30s', target: 50  },
        { duration: '60s', target: 100 },
        { duration: '30s', target: 0   },
      ],
      tags:      { scenario: 'stress' },
      startTime: '165s',
    },

    // Scenariusz 4: Spike test (nagły skok)
    spike: {
      executor:  'ramping-vus',
      startVUs:  0,
      stages: [
        { duration: '10s', target: 200 },  // nagły skok
        { duration: '30s', target: 200 },  // utrzymaj
        { duration: '10s', target: 0   },  // nagły spadek
      ],
      tags:      { scenario: 'spike' },
      startTime: '295s',
    },
  },

  // Progi akceptacji
  thresholds: {
    'http_req_duration':              ['p(95)<500', 'p(99)<1000'],
    'http_req_duration{endpoint:health}': ['p(95)<50'],
    'http_req_duration{endpoint:api}':    ['p(95)<200'],
    'http_req_duration{endpoint:auth}':   ['p(95)<500'],
    'error_rate':                     ['rate<0.05'],  // <5% błędów
    'http_req_failed':                ['rate<0.05'],
    'auth_duration_ms':               ['p(95)<500'],
    'api_duration_ms':                ['p(95)<200'],
    'health_duration_ms':             ['p(95)<50'],
  },
};

// ─── SETUP — rejestracja użytkownika testowego ─────────────
export function setup() {
  const ts = Date.now();
  const payload = JSON.stringify({
    email:    `k6test_${ts}@grazyna.pl`,
    password: 'K6Test1234!',
    username: `k6user_${ts}`,
  });

  const res = http.post(`${BASE_URL}/api/auth/register`, payload, {
    headers: { 'Content-Type': 'application/json' },
    tags:    { endpoint: 'setup' },
  });

  if (res.status !== 201 && res.status !== 200) {
    console.error(`Setup failed: ${res.status} ${res.body}`);
    return { token: null, email: null, password: null };
  }

  const body = JSON.parse(res.body);
  console.log(`✅ Setup: użytkownik ${body.user?.email || 'OK'} zarejestrowany`);

  return {
    token:    body.token,
    email:    `k6test_${ts}@grazyna.pl`,
    password: 'K6Test1234!',
  };
}

// ─── GŁÓWNA FUNKCJA TESTOWA ────────────────────────────────
export default function(data) {
  activeUsers.add(1);
  totalRequests.add(1);

  const headers = {
    'Content-Type':  'application/json',
    'Authorization': data.token ? `Bearer ${data.token}` : '',
  };

  // ── GROUP 1: Health Check ──────────────────────────────
  group('health', () => {
    const res = http.get(`${BASE_URL}/health`, {
      tags: { endpoint: 'health' },
    });

    healthDuration.add(res.timings.duration);
    errorRate.add(res.status !== 200);

    check(res, {
      'health: status 200':    (r) => r.status === 200,
      'health: has status ok': (r) => JSON.parse(r.body)?.status === 'ok',
      'health: <50ms':         (r) => r.timings.duration < 50,
    });
  });

  sleep(0.1);

  // ── GROUP 2: API Root ──────────────────────────────────
  group('api', () => {
    const res = http.get(`${BASE_URL}/api`, {
      tags: { endpoint: 'api' },
    });

    apiDuration.add(res.timings.duration);
    errorRate.add(res.status !== 200);

    check(res, {
      'api: status 200': (r) => r.status === 200,
      'api: <200ms':     (r) => r.timings.duration < 200,
    });
  });

  sleep(0.1);

  // ── GROUP 3: Auth — Login ──────────────────────────────
  group('auth', () => {
    if (!data.email) return;

    const loginRes = http.post(
      `${BASE_URL}/api/auth/login`,
      JSON.stringify({ email: data.email, password: data.password }),
      { headers, tags: { endpoint: 'auth' } }
    );

    authDuration.add(loginRes.timings.duration);
    errorRate.add(loginRes.status !== 200);

    check(loginRes, {
      'login: status 200':  (r) => r.status === 200,
      'login: has token':   (r) => !!JSON.parse(r.body)?.token,
      'login: <500ms':      (r) => r.timings.duration < 500,
    });

    // Aktualizuj token
    if (loginRes.status === 200) {
      const body = JSON.parse(loginRes.body);
      if (body.token) data.token = body.token;
    }
  });

  sleep(0.2);

  // ── GROUP 4: System Workers ────────────────────────────
  group('workers', () => {
    const res = http.get(`${BASE_URL}/api/system/workers`, {
      headers,
      tags: { endpoint: 'workers' },
    });

    apiDuration.add(res.timings.duration);
    errorRate.add(res.status !== 200 && res.status !== 401);

    check(res, {
      'workers: status 200 or 401': (r) => r.status === 200 || r.status === 401,
      'workers: <200ms':            (r) => r.timings.duration < 200,
    });
  });

  sleep(0.1);

  // ── GROUP 5: Metrics endpoint ──────────────────────────
  group('metrics', () => {
    const res = http.get(`${BASE_URL}/metrics`, {
      tags: { endpoint: 'metrics' },
    });

    check(res, {
      'metrics: status 200': (r) => r.status === 200,
      'metrics: has heap':   (r) => r.body.includes('nodejs_heap_size_used_bytes'),
    });
  });

  sleep(0.5 + Math.random() * 0.5);  // 0.5-1s między iteracjami
}

// ─── TEARDOWN ──────────────────────────────────────────────
export function teardown(data) {
  console.log('✅ Load test zakończony');
  console.log(`   Token: ${data.token ? 'OK' : 'BRAK'}`);
}

// ─── HANDLERY LIFECYCLE ────────────────────────────────────
export function handleSummary(data) {
  const summary = {
    timestamp:   new Date().toISOString(),
    scenarios:   Object.keys(options.scenarios),
    metrics: {
      http_req_duration_p95: data.metrics.http_req_duration?.values?.['p(95)']?.toFixed(2) + 'ms',
      http_req_duration_p99: data.metrics.http_req_duration?.values?.['p(99)']?.toFixed(2) + 'ms',
      error_rate:            (data.metrics.error_rate?.values?.rate * 100)?.toFixed(2) + '%',
      total_requests:        data.metrics.http_reqs?.values?.count,
      req_per_sec:           data.metrics.http_reqs?.values?.rate?.toFixed(2),
      health_p95:            data.metrics.health_duration_ms?.values?.['p(95)']?.toFixed(2) + 'ms',
      auth_p95:              data.metrics.auth_duration_ms?.values?.['p(95)']?.toFixed(2) + 'ms',
      api_p95:               data.metrics.api_duration_ms?.values?.['p(95)']?.toFixed(2) + 'ms',
    },
    thresholds_passed: Object.entries(data.metrics)
      .filter(([, m]) => m.thresholds)
      .every(([, m]) => Object.values(m.thresholds).every(t => t.ok)),
  };

  return {
    'k6_results.json': JSON.stringify(summary, null, 2),
    stdout: `
╔══════════════════════════════════════════════════════════╗
║   GRAŻYNA 5.0 — k6 Load Test Results                     ║
╚══════════════════════════════════════════════════════════╝

  Total requests:    ${summary.metrics.total_requests}
  Req/sec:           ${summary.metrics.req_per_sec}
  Error rate:        ${summary.metrics.error_rate}

  Latency p95:       ${summary.metrics.http_req_duration_p95}
  Latency p99:       ${summary.metrics.http_req_duration_p99}

  /health p95:       ${summary.metrics.health_p95}
  /auth p95:         ${summary.metrics.auth_p95}
  /api p95:          ${summary.metrics.api_p95}

  Thresholds:        ${summary.thresholds_passed ? '✅ PASSED' : '❌ FAILED'}
`,
  };
}