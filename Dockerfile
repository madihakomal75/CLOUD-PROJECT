# ---- Build Stage ----
FROM node:22-slim AS builder
WORKDIR /app

# Install system dependencies for Prisma and OpenSSL
RUN apt-get update && apt-get install -y openssl libc6 && rm -rf /var/lib/apt/lists/*

# Build-time args — passed from your GitHub Action 'build-args'
ARG BETTER_AUTH_SECRET
ARG NEXT_PUBLIC_APP_URL
ARG DATABASE_URL
ARG SENTRY_AUTH_TOKEN

# ENV settings for the build process
ENV BETTER_AUTH_SECRET=$BETTER_AUTH_SECRET
# FIX: Fallback to localhost during build so BetterAuth validation passes
ENV BETTER_AUTH_URL=${NEXT_PUBLIC_APP_URL:-http://localhost:3000}
ENV DATABASE_URL=$DATABASE_URL
ENV SENTRY_AUTH_TOKEN=$SENTRY_AUTH_TOKEN

COPY package*.json ./

# Install dependencies using legacy-peer-deps to avoid version conflicts
RUN npm install --legacy-peer-deps

# Ensure Prisma versions match your local environment
RUN npm install @prisma/client@5.22.0 prisma@5.22.0 --legacy-peer-deps

COPY . .

# Generate Prisma Client (required for the build)
RUN npx prisma generate

# Build Next.js app (Standalone mode)
RUN npm run build

# ---- Production Stage ----
FROM node:22-slim AS runner
WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y openssl libc6 && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production

# Copy only the necessary files for a small, fast image
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
# Ensure your generated Prisma folder is included if custom
COPY --from=builder /app/src/generated ./src/generated

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

# Start the application
CMD ["node", "server.js"]