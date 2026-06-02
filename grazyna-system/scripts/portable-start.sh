#!/bin/bash
set -e

echo "🦞 GRAŻYNA 5.0 PORTABLE MODE"
echo "Tryb lekki, lokalny i odporny na brak części usług"

if [ ! -d "frontend/node_modules" ]; then
  echo "▶ Instaluję frontend"
  cd frontend && npm install --silent && cd ..
fi

if [ ! -d "backend/node_modules" ]; then
  echo "▶ Instaluję backend"
  cd backend && npm install --silent && cd ..
fi

if [ ! -f "frontend/.env" ]; then
  cp frontend/.env.example frontend/.env 2>/dev/null || true
fi

if [ ! -f "backend/.env" ]; then
  cat > backend/.env <<EOF
NODE_ENV=development
PORT=3001
DATABASE_URL=postgresql://grazyna:grazyna123@localhost:5432/grazyna_db
REDIS_URL=redis://localhost:6379
JWT_SECRET=portable-mode-secret
CORS_ORIGIN=http://localhost:5173
EOF
fi

echo "▶ Uruchamiam backend i frontend w trybie portable"
(cd backend && npm run dev) &
sleep 3
(cd frontend && npm run dev)
