#!/usr/bin/env bash
set -euo pipefail

# Konfiguracja (możesz nadpisać przez env przed uruchomieniem)
PROMETHEUS_RETENTION="${PROMETHEUS_RETENTION:-30d}"
CLICKHOUSE_URL="${CLICKHOUSE_URL:-http://localhost:8123}"
BACKEND_PORT="${BACKEND_PORT:-4000}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"

echo "=== BUILD: backend image ==="
docker build -t monitoring-backend:local -f backend/Dockerfile.backend ./backend

echo "=== BUILD: frontend image ==="
docker build -t monitoring-frontend:local -f frontend/Dockerfile.frontend ./frontend

echo "=== START: docker-compose ==="
docker-compose up -d --build

echo "=== WAIT: services to become ready (Prometheus, ClickHouse, backend) ==="
# wait for Prometheus
for i in {1..30}; do
  if curl -sS http://localhost:9090/-/ready >/dev/null 2>&1; then
    echo "Prometheus ready"
    break
  fi
  echo "Waiting for Prometheus..."
  sleep 2
done

# wait for ClickHouse HTTP
for i in {1..30}; do
  if curl -sS ${CLICKHOUSE_URL} >/dev/null 2>&1; then
    echo "ClickHouse ready"
    break
  fi
  echo "Waiting for ClickHouse..."
  sleep 2
done

# wait for backend
for i in {1..30}; do
  if curl -sS "http://localhost:${BACKEND_PORT}/health" | grep -q '"ok"'; then
    echo "Backend ready"
    break
  fi
  echo "Waiting for backend..."
  sleep 2
done

echo "=== APPLY: ClickHouse schema ==="
# apply schema if not exists (uses schema.sql from infra)
if curl -sS ${CLICKHOUSE_URL} --data-binary @infra/clickhouse/schema.sql >/dev/null 2>&1; then
  echo "ClickHouse schema applied"
else
  echo "Warning: ClickHouse schema apply may have failed"
fi

echo "=== SANITY CHECK: Prometheus proxy via backend ==="
if curl -sS "http://localhost:${BACKEND_PORT}/api/promql/query?q=up" | jq . >/dev/null 2>&1; then
  echo "Prometheus proxy OK"
else
  echo "Warning: Prometheus proxy returned unexpected result"
fi

echo "=== OPTIONAL: start ingest worker (background) ==="
# uruchom worker w kontenerze backend (jeśli chcesz lokalnie)
docker exec -d $(docker ps --filter "ancestor=monitoring-backend:local" -q | head -n1) sh -c "npm run ingest || true"

echo "=== DEPLOY COMPLETE ==="
echo "Frontend: http://localhost:${FRONTEND_PORT}"
echo "Backend:  http://localhost:${BACKEND_PORT}"
echo "Prometheus: http://localhost:9090"
echo "ClickHouse: ${CLICKHOUSE_URL}"