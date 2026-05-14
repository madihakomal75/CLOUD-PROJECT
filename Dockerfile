FROM node:22-slim AS builder
WORKDIR /app

# Install system dependencies for Prisma
RUN apt-get update && apt-get install -y openssl libc6 && rm -rf /var/lib/apt/lists/*

# Arguments for build-time safety (Next.js needs these)
ARG BETTER_AUTH_SECRET
ARG NEXT_PUBLIC_APP_URL
ARG DATABASE_URL

ENV BETTER_AUTH_SECRET=$BETTER_AUTH_SECRET
ENV BETTER_AUTH_URL=$NEXT_PUBLIC_APP_URL
ENV DATABASE_URL=$DATABASE_URL

COPY package*.json ./
# Force install specific Prisma versions to avoid version drift
RUN npm install --legacy-peer-deps
RUN npm install @prisma/client@5.22.0 prisma@5.22.0 --legacy-peer-deps

COPY . .

# Generate Prisma Client using the version we just installed
RUN npx prisma generate

# This will now run 'next build' without trying to call 'prisma' again
RUN npm run build