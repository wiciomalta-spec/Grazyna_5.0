# backend/Dockerfile
FROM node:20-alpine AS builder
WORKDIR /app

# install deps
COPY package*.json ./
RUN npm ci

# copy source and build
COPY . .
RUN npm run build

# runtime image
FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

# copy built files and package.json for production deps
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./
RUN npm ci --only=production

# copy optional entrypoint script
COPY --from=builder /app/scripts/wait-for.sh ./scripts/wait-for.sh
RUN chmod +x ./scripts/wait-for.sh || true

EXPOSE 3001
# Wait for DB/Redis then start server
CMD ["sh", "-c", "./scripts/wait-for.sh && node dist/index.js"]
