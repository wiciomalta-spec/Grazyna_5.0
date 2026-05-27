FROM node:20-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl build-essential git && rm -rf /var/lib/apt/lists/*
COPY package*.json package-lock.json ./
COPY prisma ./prisma/
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
RUN npm ci --no-audit --no-fund
RUN npx prisma generate --schema=./prisma/schema.prisma
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:20-slim AS runtime
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates libssl3 && rm -rf /var/lib/apt/lists/*
COPY package*.json package-lock.json ./
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
RUN npm ci --omit=dev --no-audit --no-fund
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/dist ./dist
EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 CMD wget --no-verbose --tries=1 --spider http://localhost:3001/api/health || exit 1
CMD ["node","dist/index.js"]