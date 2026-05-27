FROM node:20-slim AS build

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# === PROD RUNTIME (DEBIAN) ===
FROM node:20-slim

WORKDIR /app

RUN apt-get update && apt-get install -y openssl

COPY --from=build /app ./

COPY docker/entrypoint.sh /entrypoint.sh
COPY docker/diagnose.mjs /diagnose.mjs

RUN chmod +x /entrypoint.sh

USER node

ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", "dist/index.js"]