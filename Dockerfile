FROM node:20-alpine AS builder
WORKDIR /app
RUN apk add --no-cache libc6-compat openssl

COPY package*.json ./
RUN npm install --legacy-peer-deps

# 1. Match the version the logs are demanding (6.19.3)
RUN npm install @prisma/client@6.19.3 --legacy-peer-deps

COPY . .
RUN rm -rf node_modules/.prisma node_modules/@prisma/client

# 2. Use --no-engine or --skip-generate to prevent the internal npm install
RUN npx prisma generate --no-engine

# 3. Build the application
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