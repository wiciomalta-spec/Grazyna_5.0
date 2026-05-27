# ✅ BUILDER
FROM node:20-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates curl build-essential git \
  && rm -rf /var/lib/apt/lists/*

# install deps (DEV + PROD)
COPY package*.json ./
RUN npm ci

# prisma
COPY prisma ./prisma
RUN npx prisma generate

# build app
COPY tsconfig.json ./
COPY src ./src
RUN npm run build


# ✅ RUNTIME
FROM node:20-alpine

WORKDIR /app
ENV NODE_ENV=production

# required libs for prisma
RUN apk add --no-cache openssl libc6-compat ca-certificates

# ❌ NIE robimy npm ci tutaj!
# ✅ kopiujemy GOTOWE node_modules z buildera

COPY --from=builder /app/node_modules ./node_modules

# app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma

# health
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/api/health || exit 1

EXPOSE 3001

CMD ["node", "dist/index.js"]