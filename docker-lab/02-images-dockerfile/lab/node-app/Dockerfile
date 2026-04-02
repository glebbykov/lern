# syntax=docker/dockerfile:1.7

# --- Stage 1: install dependencies ---
FROM node:22-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# --- Stage 2: production runtime ---
FROM node:22-alpine AS runtime
WORKDIR /app

RUN addgroup -S app && adduser -S -G app app

COPY --from=deps /app/node_modules ./node_modules
COPY server.js ./

USER app
EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:3000/healthz || exit 1

CMD ["node", "server.js"]
