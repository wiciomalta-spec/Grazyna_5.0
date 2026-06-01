import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

const errorRate      = new Rate('error_rate');
const healthDuration = new Trend('health_duration_ms', true);
const authDuration   = new Trend('auth_duration_ms',   true);
const apiDuration    = new Trend('api_duration_ms',    true);
const totalReqs      = new Counter('total_requests');

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3001';

export const options = {
  scenarios: {
    smoke:  { executor:'constant-vus', vus:2,   duration:'30s', startTime:'0s'   },
    load:   { executor:'ramping-vus',  startVUs:0, stages:[{duration:'30s',target:20},{duration:'60s',target:20},{duration:'30s',target:0}], startTime:'35s'  },
    stress: { executor:'ramping-vus',  startVUs:0, stages:[{duration:'30s',target:50},{duration:'60s',target:100},{duration:'30s',target:0}], startTime:'165s' },
    spike:  { executor:'ramping-vus',  startVUs:0, stages:[{duration:'10s',target:200},{duration:'30s',target:200},{duration:'10s',target:0}], startTime:'295s' },
  },
  thresholds: {
    'http_req_duration':                      ['p(95)<500','p(99)<1000'],
    'http_req_duration{endpoint:health}':     ['p(95)<50'],
    'http_req_duration{endpoint:api}':        ['p(95)<200'],
    'http_req_duration{endpoint:auth}':       ['p(95)<500'],
    'health_duration_ms':                     ['p(95)<50'],
    'error_rate':                             ['rate<0.05'],
  },
};

export function setup() {
  const ts  = Date.now();
  const res = http.post(`${BASE_URL}/api/auth/register`,
    JSON.stringify({ email:`k6_${ts}@grazyna.pl`, password:'K6Test1234!', username:`k6u_${ts}` }),
    { headers:{ 'Content-Type':'application/json' } });
  const body = (res.status===201||res.status===200) ? JSON.parse(res.body) : {};
  return { token:body.token, email:`k6_${ts}@grazyna.pl`, password:'K6Test1234!' };
}

export default function(data) {
  totalReqs.add(1);
  const h = { 'Content-Type':'application/json', 'Authorization': data.token ? `Bearer ${data.token}` : '' };

  group('health', () => {
    const r = http.get(`${BASE_URL}/health`, { tags:{ endpoint:'health' } });
    healthDuration.add(r.timings.duration);
    errorRate.add(r.status !== 200);
    check(r, { 'health 200': r => r.status===200, 'health <50ms': r => r.timings.duration<50 });
  });
  sleep(0.1);

  group('api', () => {
    const r = http.get(`${BASE_URL}/api`, { tags:{ endpoint:'api' } });
    apiDuration.add(r.timings.duration);
    errorRate.add(r.status !== 200);
    check(r, { 'api 200': r => r.status===200, 'api <200ms': r => r.timings.duration<200 });
  });
  sleep(0.1);

  group('auth', () => {
    if (!data.email) return;
    const r = http.post(`${BASE_URL}/api/auth/login`,
      JSON.stringify({ email:data.email, password:data.password }),
      { headers:h, tags:{ endpoint:'auth' } });
    authDuration.add(r.timings.duration);
    errorRate.add(r.status !== 200);
    check(r, { 'login 200': r => r.status===200, 'has token': r => !!JSON.parse(r.body)?.token });
    if (r.status===200) { const b=JSON.parse(r.body); if(b.token) data.token=b.token; }
  });
  sleep(0.2);

  group('metrics', () => {
    const r = http.get(`${BASE_URL}/metrics`, { tags:{ endpoint:'metrics' } });
    check(r, { 'metrics 200': r => r.status===200 });
  });

  sleep(0.5 + Math.random()*0.5);
}

export function handleSummary(data) {
  const p95  = data.metrics.http_req_duration?.values?.['p(95)']?.toFixed(2);
  const p99  = data.metrics.http_req_duration?.values?.['p(99)']?.toFixed(2);
  const rps  = data.metrics.http_reqs?.values?.rate?.toFixed(2);
  const err  = (data.metrics.error_rate?.values?.rate*100)?.toFixed(2);
  const hp95 = data.metrics.health_duration_ms?.values?.['p(95)']?.toFixed(2);
  const ap95 = data.metrics.auth_duration_ms?.values?.['p(95)']?.toFixed(2);
  return {
    'k6_results.json': JSON.stringify({ p95_ms:p95, p99_ms:p99, rps, error_pct:err, health_p95:hp95, auth_p95:ap95 }, null, 2),
    stdout: `\n=== GRAŻYNA 5.0 k6 Results ===\n p95:${p95}ms p99:${p99}ms RPS:${rps} Errors:${err}% /health:${hp95}ms /auth:${ap95}ms\n`,
  };
}
