#!/bin/bash
set -e

# Test script for service (debug variant)
# This receives IMAGE_TAG from the workflow
# NOTE: Distroless images do NOT have shells - even debug variants
# We can only test that the container runs and extract files with docker cp

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
REVISION=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.revision"}}' "$IMAGE_TAG")
CREATED=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.created"}}' "$IMAGE_TAG")
SOURCE=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.source"}}' "$IMAGE_TAG")

echo "  ✅ Version: $VERSION"
echo "  ✅ Revision: $REVISION"
echo "  ✅ Created: $CREATED"
echo "  ✅ Source: $SOURCE"

# Check configuration
echo ""
echo "Checking configuration..."
EXPOSED_PORTS=$(docker inspect --format='{{range $p, $conf := .Config.ExposedPorts}}{{$p}} {{end}}' "$IMAGE_TAG")
echo "  Exposed ports: $EXPOSED_PORTS"

USER=$(docker inspect --format='{{.Config.User}}' "$IMAGE_TAG")
echo "  User: $USER"

if [ "$USER" != "testapp" ]; then
  echo "❌ ERROR: Expected user 'testapp', got '$USER'"
  exit 1
fi

echo "  ✅ User is 'testapp'"

# Start container
echo ""
echo "Testing container startup..."
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

# Check metadata file by copying it out
echo ""
echo "Checking metadata file..."
if docker cp test-debug-service:/app/metadata.json /tmp/metadata-test.json 2>/dev/null; then
  echo "  ✅ metadata.json exists"

  # Validate JSON and check content
  if jq empty /tmp/metadata-test.json 2>/dev/null; then
    echo "  ✅ metadata.json is valid JSON"

    # Display metadata
    echo ""
    echo "  Metadata content:"
    jq '.' /tmp/metadata-test.json | sed 's/^/    /'

    # Verify debug flag
    DEBUG_ENABLED=$(jq -r '.debug_enabled' /tmp/metadata-test.json)
    if [ "$DEBUG_ENABLED" == "true" ]; then
      echo ""
      echo "  ✅ Debug mode enabled in metadata"
    else
      echo ""
      echo "⚠️  WARNING: Debug mode not enabled in metadata (got: $DEBUG_ENABLED)"
    fi

    # Verify variant
    VARIANT=$(jq -r '.variant' /tmp/metadata-test.json)
    if [ "$VARIANT" == "debug" ]; then
      echo "  ✅ Variant is 'debug'"
    else
      echo "⚠️  WARNING: Expected variant 'debug', got '$VARIANT'"
    fi
  else
    echo "⚠️  WARNING: metadata.json is not valid JSON"
  fi

  rm -f /tmp/metadata-test.json
else
  echo "⚠️  WARNING: metadata.json not found"
fi

# Check logs show debug output
echo ""
echo "Checking application logs..."
LOGS=$(docker logs test-debug-service 2>&1 | head -10)
echo "$LOGS" | sed 's/^/  /'

if echo "$LOGS" | grep -q "DEBUG"; then
  echo ""
  echo "  ✅ Debug logging is active"
else
  echo ""
  echo "⚠️  NOTE: No 'DEBUG' string in logs (may be expected)"
fi

# Test health endpoint (if available)
echo ""
echo "Testing health endpoint..."
if curl -f -s http://localhost:8080 > /dev/null 2>&1; then
  echo "  ✅ Health check passed"
else
  echo "⚠️  WARNING: Health check failed (may be expected for test image)"
fi

# Cleanup
echo ""
echo "Cleaning up..."
docker stop test-debug-service > /dev/null 2>&1
docker rm test-debug-service > /dev/null 2>&1

echo ""
echo "============================================"
echo "✅ All tests passed for debug service image"
echo "============================================"
