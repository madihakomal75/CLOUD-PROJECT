# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
RUN apk add --no-cache libc6-compat openssl

COPY package*.json ./
RUN npm install --legacy-peer-deps
RUN npm install @prisma/client@6.19.3 --legacy-peer-deps

COPY . .

# Ensure the custom directory exists for the Prisma output
RUN mkdir -p src/generated/prisma

# Generate the Client into src/generated/prisma
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
# Note: Keeping the path logic from your successful build
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# Copy the custom generated prisma folder so the app can find it at runtime
COPY --from=builder /app/src/generated/prisma ./src/generated/prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma/client ./node_modules/@prisma/client

EXPOSE 3000
CMD ["node", "server.js"]