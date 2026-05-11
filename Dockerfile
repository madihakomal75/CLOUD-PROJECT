# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app

# Install system dependencies for Prisma on Alpine
RUN apk add --no-cache libc6-compat openssl

COPY package*.json ./
RUN npm install --legacy-peer-deps

# Copy everything else EXCEPT what's in .dockerignore
COPY . .

# WIPE any potential local remnants just in case
RUN rm -rf node_modules/.prisma node_modules/@prisma/client

# Generate the correct Linux binary
RUN npx prisma generate

# Build the application
ENV NODE_ENV=production
RUN npm run build

# Stage 2: Run
FROM node:20-alpine AS runner
WORKDIR /app
RUN apk add --no-cache openssl
ENV NODE_ENV=production

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# CRITICAL: Place the Linux engine in all searched locations
COPY --from=builder /app/node_modules/.prisma ./.next/standalone/node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma/client ./.next/standalone/node_modules/@prisma/client
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma/client ./node_modules/@prisma/client

EXPOSE 3000
CMD ["node", "server.js"]