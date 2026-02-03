#!/bin/bash
set -e

# Test script for service (debug variant)
# This receives IMAGE_TAG from the workflow

echo "============================================"
echo "Testing Service Image (Debug Variant)"
echo "============================================"
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
VERSION=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.version"}}' "$IMAGE_TAG")
echo "  ✅ Version: $VERSION"

# Start container
echo ""
echo "Testing debug variant features..."
docker run -d --name test-debug-service -p 8080:8080 "$IMAGE_TAG" || {
  echo "❌ ERROR: Failed to start container"
  exit 1
}

sleep 3

# Check container is running
if ! docker ps | grep -q test-debug-service; then
  echo "❌ ERROR: Container is not running"
  docker logs test-debug-service
  docker rm -f test-debug-service
  exit 1
fi

echo "  ✅ Container is running"

# Test shell availability (debug variant should have shell)
echo ""
echo "Testing shell availability..."
if docker exec test-debug-service sh -c "echo 'Shell test'" > /dev/null 2>&1; then
  echo "  ✅ Shell is available (debug mode)"
else
  echo "❌ ERROR: Shell not available in debug variant"
  docker stop test-debug-service
  docker rm test-debug-service
  exit 1
fi

# Check metadata file
echo ""
echo "Checking metadata file..."
if docker exec test-debug-service sh -c "cat /app/metadata.json" > /dev/null 2>&1; then
  METADATA=$(docker exec test-debug-service sh -c "cat /app/metadata.json")
  echo "  Metadata:"
  echo "$METADATA" | jq '.'

  # Verify debug flag
  DEBUG_ENABLED=$(echo "$METADATA" | jq -r '.debug_enabled')
  if [ "$DEBUG_ENABLED" == "true" ]; then
    echo "  ✅ Debug mode enabled"
  else
    echo "⚠️  WARNING: Debug mode not enabled in metadata"
  fi
else
  echo "⚠️  WARNING: metadata.json not found"
fi

# Check logs show debug output
echo ""
echo "Checking debug logs..."
LOGS=$(docker logs test-debug-service 2>&1)
if echo "$LOGS" | grep -q "DEBUG"; then
  echo "  ✅ Debug logging is active"
else
  echo "⚠️  WARNING: No debug output in logs"
fi

# Cleanup
echo ""
echo "Cleaning up..."
docker stop test-debug-service > /dev/null
docker rm test-debug-service > /dev/null

echo ""
echo "============================================"
echo "✅ All tests passed for debug service image"
echo "============================================"
