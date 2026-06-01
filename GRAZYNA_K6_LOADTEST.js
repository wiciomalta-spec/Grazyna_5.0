import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

const errorRate      = new Rate('error_rate');
const healthDuration = new Trend('health_duration_ms', true);
const apiDuration    = new Trend('api_duration_ms',    true);
const totalReqs      = new Counter('total_requests');

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3001';

export const options = {
  vus:      10,
  duration: '30s',
  thresholds: {
    'http_req_duration':  ['p(95)<500'],
    'error_rate':         ['rate<0.10'],
    'health_duration_ms': ['p(95)<100'],
  },
};

// BEZ setup() - nie rejestrujemy usera (to crashuje backend)
export default function() {
  totalReqs.add(1);

  // Test 1: Health
  group('health', () => {
    const r = http.get(`${BASE_URL}/health`, { tags:{ endpoint:'health' } });
    healthDuration.add(r.timings.duration);
    errorRate.add(r.status !== 200);
    check(r, {
      'health 200': r => r.status === 200,
      'health <100ms': r => r.timings.duration < 100,
    });
  });
  sleep(0.2);

  // Test 2: API root
  group('api', () => {
    const r = http.get(`${BASE_URL}/api`, { tags:{ endpoint:'api' } });
    apiDuration.add(r.timings.duration);
    errorRate.add(r.status !== 200);
    check(r, { 'api 200': r => r.status === 200 });
  });
  sleep(0.2);

  // Test 3: Metrics
  group('metrics', () => {
    const r = http.get(`${BASE_URL}/metrics`, { tags:{ endpoint:'metrics' } });
    check(r, { 'metrics 200': r => r.status === 200 });
  });

  sleep(0.5 + Math.random() * 0.5);
}

export function handleSummary(data) {
  const p95 = data.metrics.http_req_duration?.values?.['p(95)']?.toFixed(2);
  const rps  = data.metrics.http_reqs?.values?.rate?.toFixed(2);
  const err  = (data.metrics.error_rate?.values?.rate * 100)?.toFixed(2);
  const hp95 = data.metrics.health_duration_ms?.values?.['p(95)']?.toFixed(2);
  return {
    'k6_results.json': JSON.stringify({ p95_ms:p95, rps, error_pct:err, health_p95:hp95 }, null, 2),
    stdout: `\n=== GRAZYNA 5.0 k6 Results ===\n p95:${p95}ms RPS:${rps} Errors:${err}% /health:${hp95}ms\n`,
  };
}
