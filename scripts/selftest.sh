#!/bin/bash
set -e

echo "🧪 GRAŻYNA SELFTEST"

check() {
  local name="$1"
  local url="$2"
  echo "▶ $name -> $url"
  curl -fsS "$url" >/dev/null
  echo "✓ OK"
}

check "Backend health" "http://localhost:3001/api/health"
check "Backend status" "http://localhost:3001/api/status"
check "Kernel profile" "http://localhost:3001/api/kernel/profile"

echo "✅ Podstawowe testy przeszły"
