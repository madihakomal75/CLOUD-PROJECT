# Stage 1: Build
FROM node:22-slim AS builder
WORKDIR /app

# Install dependencies for Prisma/Next
RUN apt-get update && apt-get install -y openssl libc6 && rm -rf /var/lib/apt/lists/*

# Arguments passed from GitHub Actions to prevent BetterAuth crash
ARG BETTER_AUTH_SECRET
ARG NEXT_PUBLIC_APP_URL
ARG DATABASE_URL

# Set as ENV so Next.js build can see them
ENV BETTER_AUTH_SECRET=$BETTER_AUTH_SECRET
ENV BETTER_AUTH_URL=$NEXT_PUBLIC_APP_URL
ENV DATABASE_URL=$DATABASE_URL
ENV NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL
ENV PRISMA_SKIP_POSTINSTALL_GENERATE=true
ENV NODE_ENV=production

COPY package*.json ./
RUN npm install --legacy-peer-deps

COPY . .

# Generate Prisma and Build Next.js
# This forces the build to use Version 5.x, which allows 'url' in the schema
RUN npx prisma@5.22.0 generate
RUN npm run build

# Stage 2: Run
FROM node:22-slim AS runner
WORKDIR /app
RUN apt-get update && apt-get install -y openssl libc6 && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production

# Standard Next.js standalone setup
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/src/generated/prisma ./src/generated/prisma

EXPOSE 3000
CMD ["node", "server.js"]