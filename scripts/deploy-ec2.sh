#!/bin/bash
# ─────────────────────────────────────────────────────────────
# deploy-ec2.sh — runs ON the EC2 instance via SSH.
# Jenkins SSHes in and pipes this script to bash.
# It pulls the latest image from DockerHub and restarts the app.
# ─────────────────────────────────────────────────────────────

set -e

CONTAINER_NAME="devops-pipeline-app"
# DockerHub image — replace with your actual DockerHub username
DOCKER_USER="navcomwest"
IMAGE="${DOCKER_USER}/devops-pipeline-app:latest"
APP_PORT=3000

echo "──────────────────────────────────────"
echo " Deploying: ${IMAGE}"
echo "──────────────────────────────────────"

# Stop and remove old container if running
echo "Stopping old container..."
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm   ${CONTAINER_NAME} 2>/dev/null || true

# Pull latest image from DockerHub
echo "Pulling latest image..."
docker pull ${IMAGE}

# Run new container
echo "Starting new container..."
docker run \
    --detach \
    --name  ${CONTAINER_NAME} \
    --publish ${APP_PORT}:3000 \
    --env NODE_ENV=production \
    --restart unless-stopped \
    ${IMAGE}

# Verify it started
sleep 3
if docker ps | grep -q ${CONTAINER_NAME}; then
    echo "Deploy successful — app running on port ${APP_PORT}"
else
    echo "Deploy failed — container not running"
    docker logs ${CONTAINER_NAME}
    exit 1
fi
