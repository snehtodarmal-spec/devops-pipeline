#!/bin/bash
# ─────────────────────────────────────────────────────────────
# cleanup.sh — removes the running app container.
# Useful for manual teardown during development.
# Not called by the pipeline automatically —
# run it manually when you want to stop the app.
# ─────────────────────────────────────────────────────────────

set -e

CONTAINER_NAME="devops-pipeline-app"

echo "Stopping and removing ${CONTAINER_NAME}..."
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm   ${CONTAINER_NAME} 2>/dev/null || true
echo "Done"
