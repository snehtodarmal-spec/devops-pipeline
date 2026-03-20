#!/bin/bash
# ─────────────────────────────────────────────────────────────
# deploy.sh — called by Jenkins in the Deploy stage.
#
# Usage: ./scripts/deploy.sh <full-image-reference>
# Example: ./scripts/deploy.sh localhost:5000/devops-pipeline-app:42
#
# What it does:
#   1. Stops and removes any running instance of the app
#   2. Pulls the new image from the registry
#   3. Runs the new container
#   4. Verifies it started correctly
# ─────────────────────────────────────────────────────────────

# Exit immediately if any command fails.
# Without this, the script would continue even after an error.
set -e

# The full image reference is passed as the first argument
FULL_IMAGE=$1
CONTAINER_NAME="devops-pipeline-app"
APP_PORT=3000

echo "──────────────────────────────────────"
echo " Deploying: ${FULL_IMAGE}"
echo "──────────────────────────────────────"

# ── Step 1: Stop old container ────────────────────────────────
# Check if a container with our app name is already running.
# If it is, stop it gracefully (gives it 10s to shut down cleanly).
# The || true means "don't fail if no container exists" —
# on the very first deploy there's nothing to stop.
echo "Stopping old container if running..."
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm   ${CONTAINER_NAME} 2>/dev/null || true

# ── Step 2: Pull latest image ─────────────────────────────────
# Even though Jenkins just pushed this image, we explicitly pull
# to verify the registry has it and to simulate what a remote
# server (EC2) would do in Phase 2.
echo "Pulling image from registry..."
docker pull ${FULL_IMAGE}

# ── Step 3: Run new container ─────────────────────────────────
echo "Starting new container..."
docker run \
    --detach \
    --name  ${CONTAINER_NAME} \
    --publish ${APP_PORT}:3000 \
    --env NODE_ENV=production \
    --restart unless-stopped \
    ${FULL_IMAGE}

# ── Step 4: Verify it started ─────────────────────────────────
# Wait a few seconds for the app to initialise, then curl
# the health endpoint. If it returns 200, deploy succeeded.
echo "Waiting for app to start..."
sleep 3

HTTP_STATUS=$(curl --silent --output /dev/null \
    --write-out "%{http_code}" \
    http://localhost:${APP_PORT}/health)

if [ "${HTTP_STATUS}" = "200" ]; then
    echo "Deploy successful — app responding on port ${APP_PORT}"
else
    echo "Deploy failed — health check returned HTTP ${HTTP_STATUS}"
    docker logs ${CONTAINER_NAME}
    exit 1
fi
