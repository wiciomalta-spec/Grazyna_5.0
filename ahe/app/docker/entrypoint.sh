#!/bin/sh
set -e

echo "[AHE] Start..."

# DIAGNOSTYKA
node /diagnose.mjs

# TRYB
PROFILE=${APP_PROFILE:-prod}

echo "[AHE] Profile: $PROFILE"

if [ "$PROFILE" = "hybrid" ]; then
  echo "[AHE] Debug mode ON"
fi

exec "$@"
``