# ===== BUILDER =====
FROM node:18-bullseye AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    build-essential \
    git \
 && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci

ARG DATABASE_URL
ENV DATABASE_URL=${DATABASE_URL}
COPY prisma ./prisma
RUN npx prisma generate

COPY tsconfig.json ./
COPY src ./src
RUN npm run build


# ===== RUNTIME =====
FROM node:18-bullseye

WORKDIR /app
ENV NODE_ENV=production

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    openssl \
    wget \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./
# COPY --from=builder /app/prisma ./prisma

RUN useradd --user-group --create-home --shell /bin/false appuser
USER appuser

EXPOSE 3001

CMD ["node", "dist/index.js"]
