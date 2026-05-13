# Stage 1: Build
FROM node:22-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y openssl libc6 && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
# Prisma 7 Fix: Skip auto-generation during npm install
ENV PRISMA_SKIP_POSTINSTALL_GENERATE=true
RUN npm install --legacy-peer-deps

COPY . .

# Generate Prisma - No 'url' in schema, so we pass it as an ENV for validation
ARG DATABASE_URL
ENV DATABASE_URL=$DATABASE_URL
RUN npx prisma generate
RUN npm run build

# Stage 2: Run
FROM node:22-slim AS runner
WORKDIR /app
RUN apt-get update && apt-get install -y openssl libc6 && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
# CRITICAL: Copy the generated prisma engine into the standalone node_modules
COPY --from=builder /app/src/generated/prisma ./src/generated/prisma

EXPOSE 3000
# Remove 'prisma db push' from CMD. Do this manually or in a separate job.
# Running it in CMD often causes timeouts that lead to 'servicesStable' errors.
CMD ["node", "server.js"]