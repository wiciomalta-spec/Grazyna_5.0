import client from "prom-client";

export const register = client.register;

// Create metrics on the default registry so /metrics shows them together
export const httpRequests = new client.Counter({
  name: "http_requests_total",
  help: "Total HTTP Requests",
  labelNames: ["method", "route", "status"],
  registers: [register],
});
export const httpRequestDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
  registers: [register],
});
export const httpErrors = new client.Counter({
  name: "http_errors_total",
  help: "Total HTTP errors (status>=500)",
  labelNames: ["method", "route", "status"],
  registers: [register],
});
export const workerGauge = new client.Gauge({
  name: "worker_processes",
  help: "Number of worker processes",
  registers: [register],
});

// Defensive registration: some prom-client versions behave differently, attempt to register explicitly
try {
  (register as any).registerMetric && (register as any).registerMetric(httpRequests);
  (register as any).registerMetric && (register as any).registerMetric(httpRequestDuration);
  (register as any).registerMetric && (register as any).registerMetric(httpErrors);
  (register as any).registerMetric && (register as any).registerMetric(workerGauge);
} catch (e) {
  // ignore duplicate/compatibility issues
}

// Defensive: ensure metrics exist by initializing zero values (some registries omit empty histograms/counters)
try {
  // Create an initial labelled sample so the metric appears in /metrics
  httpRequests.inc({ method: '_init', route: '/_init', status: '0' }, 0);
  httpRequestDuration.observe({ method: '_init', route: '/_init', status: '0' }, 0);
  httpErrors.inc({ method: '_init', route: '/_init', status: '0' }, 0);
  workerGauge.set(0);
} catch (e) {
  // ignore
}

// Collect default metrics (includes GC metrics like GC duration)
try {
  client.collectDefaultMetrics({ register });
} catch (e) {
  // fallback
  try { client.collectDefaultMetrics(); } catch(e) { /* ignore */ }
}
