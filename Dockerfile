# ─────────────────────────────────────────────────────────────
# Multi-stage Dockerfile
#
# Stage 1 (builder): installs ALL dependencies including devDeps
#                    and runs the app build if needed
# Stage 2 (production): copies only what's needed to run the app
#                       — no devDependencies, no test files
#
# This keeps the final image small and free of test tooling.
# ─────────────────────────────────────────────────────────────

# ── Stage 1: Builder ──────────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files first — Docker caches this layer.
# If package.json hasn't changed, Docker skips npm ci
# on the next build, making builds significantly faster.
COPY app/package*.json ./

# Install all deps including devDependencies
# (needed if you have a build step e.g. TypeScript)
RUN npm ci

# Copy the rest of the source code
COPY app/src ./src

# ── Stage 2: Production ───────────────────────────────────────
FROM node:18-alpine AS production

# Create a non-root user to run the app.
# Running as root inside a container is a security risk —
# if the app is compromised, the attacker gets root on the container.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only production dependencies manifest
COPY app/package*.json ./

# Install ONLY production dependencies — no jest, no supertest
RUN npm ci --only=production

# Copy built source from the builder stage
COPY --from=builder /app/src ./src

# Switch to non-root user before starting the app
USER appuser

# Document which port the app listens on.
# This is metadata only — you still need -p in docker run
# or the ports: mapping in docker-compose to expose it.
EXPOSE 3000

# Health check — Docker will periodically curl this endpoint.
# If it fails 3 times in a row, Docker marks the container unhealthy.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost:3000/health || exit 1

# Start the app
CMD ["node", "src/index.js"]
