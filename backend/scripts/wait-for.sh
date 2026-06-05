#!/bin/sh
# backend/scripts/wait-for.sh
set -e

host_check() {
  host=$1; port=$2; tries=20
  i=0
  while ! nc -z "$host" "$port"; do
    i=$((i+1))
    echo "Waiting for $host:$port ($i/$tries)..."
    if [ "$i" -ge "$tries" ]; then
      echo "Timeout waiting for $host:$port"
      return 1
    fi
    sleep 1
  done
  return 0
}

# Compose service names
PG_HOST=${PG_HOST:-postgres}
PG_PORT=${PG_PORT:-5432}
REDIS_HOST=${REDIS_HOST:-redis}
REDIS_PORT=${REDIS_PORT:-6379}

echo "Checking Postgres $PG_HOST:$PG_PORT"
host_check "$PG_HOST" "$PG_PORT" || exit 1

echo "Checking Redis $REDIS_HOST:$REDIS_PORT"
host_check "$REDIS_HOST" "$REDIS_PORT" || exit 1

echo "Dependencies ready"
exec "$@"