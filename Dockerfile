FROM node:22-slim AS builder
WORKDIR /app

# Install system dependencies for Prisma
RUN apt-get update && apt-get install -y openssl libc6 && rm -rf /var/lib/apt/lists/*

# Build-time args — Next.js and Sentry need these at build time
ARG BETTER_AUTH_SECRET
ARG NEXT_PUBLIC_APP_URL
ARG DATABASE_URL
ARG SENTRY_AUTH_TOKEN

ENV BETTER_AUTH_SECRET=$BETTER_AUTH_SECRET
ENV BETTER_AUTH_URL=$NEXT_PUBLIC_APP_URL
ENV DATABASE_URL=$DATABASE_URL
# Sentry uses this to upload source maps during `next build`
ENV SENTRY_AUTH_TOKEN=$SENTRY_AUTH_TOKEN

COPY package*.json ./

# Single install pass with legacy-peer-deps to resolve all peer conflicts
RUN npm install --legacy-peer-deps

# Overwrite with pinned Prisma versions — MUST use --legacy-peer-deps here too
RUN npm install @prisma/client@5.22.0 prisma@5.22.0 --legacy-peer-deps

COPY . .

# Generate Prisma Client
RUN npx prisma generate

# Build Next.js app
RUN npm run build

# ---- Production image ----
FROM node:22-slim AS runner
WORKDIR /app

RUN apt-get update && apt-get install -y openssl libc6 && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production

# Copy only what is needed to run
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/src/generated ./src/generated

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

CMD ["node", "server.js"]