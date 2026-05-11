# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app

# Install system dependencies for Alpine
RUN apk add --no-cache libc6-compat openssl

# Install dependencies (including the specific Prisma version to prevent build-time crashes)
COPY package*.json ./
RUN npm install --legacy-peer-deps
RUN npm install @prisma/client@6.16.3 --legacy-peer-deps

# Copy source and clean any local Windows remnants
COPY . .
RUN rm -rf node_modules/.prisma node_modules/@prisma/client

# Generate Linux-specific Prisma Client
RUN npx prisma generate

# Build the application
ENV NODE_ENV=production
RUN npm run build

# Stage 2: Run
FROM node:20-alpine AS runner
WORKDIR /app
RUN apk add --no-cache openssl
ENV NODE_ENV=production

# Copy standalone build files
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# PLACEMENT FIX: Move Linux binaries to every path the app searches
COPY --from=builder /app/node_modules/.prisma ./.next/standalone/node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma/client ./.next/standalone/node_modules/@prisma/client
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma/client ./node_modules/@prisma/client

EXPOSE 3000
CMD ["node", "server.js"]