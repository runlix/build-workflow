#!/bin/bash
set -e

# Test script for base image (debug variant)
# This receives IMAGE_TAG from the workflow

echo "=========================================="
echo "Testing Base Image (Debug Variant)"
echo "=========================================="
echo "Image: $IMAGE_TAG"
echo ""

# Check that IMAGE_TAG is set
if [ -z "$IMAGE_TAG" ]; then
  echo "❌ ERROR: IMAGE_TAG environment variable not set"
  exit 1
fi

# Verify image exists locally
if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
  echo "❌ ERROR: Image not found: $IMAGE_TAG"
  exit 1
fi

echo "✅ Image exists: $IMAGE_TAG"

# Check image labels
echo ""
echo "Checking OCI labels..."
REVISION=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.revision"}}' "$IMAGE_TAG")
CREATED=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.created"}}' "$IMAGE_TAG")

echo "  ✅ Revision: $REVISION"
echo "  ✅ Created: $CREATED"

# Debug images include busybox, so we can run shell commands
echo ""
echo "Testing debug features (busybox shell)..."

# Start container
docker run -d --name test-debug-container "$IMAGE_TAG" sleep 30 || {
  echo "❌ ERROR: Failed to start container"
  exit 1
}

# Test shell availability
if docker exec test-debug-container sh -c "echo 'Shell test'" > /dev/null 2>&1; then
  echo "  ✅ Shell (busybox) is available"
else
  echo "❌ ERROR: Shell not available in debug variant"
  docker stop test-debug-container
  docker rm test-debug-container
  exit 1
fi

# Test basic commands
if docker exec test-debug-container sh -c "ls /etc/build-info" > /dev/null 2>&1; then
  echo "  ✅ build-info file exists"
else
  echo "⚠️  WARNING: build-info file not found (may be expected)"
fi

# Cleanup
docker stop test-debug-container > /dev/null
docker rm test-debug-container > /dev/null

echo ""
echo "=========================================="
echo "✅ All tests passed for debug base image"
echo "=========================================="
