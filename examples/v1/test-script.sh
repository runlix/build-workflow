#!/bin/bash
set -e

# Example test script for Docker images
# This script receives IMAGE_TAG as an environment variable from the workflow

echo "Testing image: $IMAGE_TAG"

# Check that IMAGE_TAG is set
if [ -z "$IMAGE_TAG" ]; then
  echo "❌ ERROR: IMAGE_TAG environment variable not set"
  exit 1
fi

# Start container in detached mode
echo "Starting container..."
docker run -d --name test-container $IMAGE_TAG

# Wait for container startup
echo "Waiting for startup..."
sleep 5

# Check if container is running
if ! docker ps | grep -q test-container; then
  echo "❌ ERROR: Container is not running"
  docker logs test-container
  exit 1
fi

# Optional: Check health endpoint if your service exposes one
# echo "Checking health endpoint..."
# docker exec test-container curl -f http://localhost:8080/health || {
#   echo "❌ ERROR: Health check failed"
#   docker logs test-container
#   exit 1
# }

# Optional: Check application version
# echo "Checking application version..."
# docker exec test-container /app/binary --version

# Cleanup
echo "Cleaning up..."
docker stop test-container
docker rm test-container

echo "✅ All tests passed"
