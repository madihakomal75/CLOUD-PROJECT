# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
RUN apk add --no-cache libc6-compat openssl

COPY package*.json ./
RUN npm install --legacy-peer-deps
RUN npm install @prisma/client@6.19.3 --legacy-peer-deps

COPY . .

# Remove the shadowing file and ensure target directory exists
RUN rm -f src/generated/prisma.ts
RUN mkdir -p src/generated/prisma

# Generate Prisma based on the 'output' in your schema.prisma
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

# Copy generated Prisma files to the final image
COPY --from=builder /app/src/generated/prisma ./src/generated/prisma

EXPOSE 3000
CMD npx prisma db push && node server.js