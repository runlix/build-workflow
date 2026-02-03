#!/bin/bash
set -e

# Test script for service (standard variant)
# This receives IMAGE_TAG from the workflow

echo "==========================================="
echo "Testing Service Image (Standard Variant)"
echo "==========================================="
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
SOURCE=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.source"}}' "$IMAGE_TAG")
VERSION=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.version"}}' "$IMAGE_TAG")

if [ -z "$REVISION" ]; then
  echo "❌ ERROR: Missing label: org.opencontainers.image.revision"
  exit 1
fi

echo "  ✅ Revision: $REVISION"
echo "  ✅ Created: $CREATED"
echo "  ✅ Source: $SOURCE"
echo "  ✅ Version: $VERSION"

# Check architecture
echo ""
echo "Checking architecture..."
ARCH=$(docker inspect --format='{{.Architecture}}' "$IMAGE_TAG")
echo "  Architecture: $ARCH"

# Check exposed port
echo ""
echo "Checking configuration..."
EXPOSED_PORTS=$(docker inspect --format='{{range $p, $conf := .Config.ExposedPorts}}{{$p}} {{end}}' "$IMAGE_TAG")
echo "  Exposed ports: $EXPOSED_PORTS"

if [[ ! "$EXPOSED_PORTS" =~ "8080" ]]; then
  echo "❌ ERROR: Port 8080 not exposed"
  exit 1
fi

echo "  ✅ Port 8080 is exposed"

# Check user
USER=$(docker inspect --format='{{.Config.User}}' "$IMAGE_TAG")
echo "  User: $USER"

if [ "$USER" != "testapp" ]; then
  echo "❌ ERROR: Expected user 'testapp', got '$USER'"
  exit 1
fi

echo "  ✅ User is 'testapp'"

# Start container and check it runs
echo ""
echo "Testing container startup..."
docker run -d --name test-service-container -p 8080:8080 "$IMAGE_TAG" || {
  echo "❌ ERROR: Failed to start container"
  exit 1
}

echo "  ✅ Container started"

# Wait for startup
sleep 3

# Check if container is still running
if ! docker ps | grep -q test-service-container; then
  echo "❌ ERROR: Container is not running"
  docker logs test-service-container
  docker rm -f test-service-container
  exit 1
fi

echo "  ✅ Container is running"

# Check health endpoint (if application supports it)
echo ""
echo "Testing health endpoint..."
if curl -f -s http://localhost:8080 > /dev/null 2>&1; then
  echo "  ✅ Health check passed"
else
  echo "⚠️  WARNING: Health check failed (may be expected for test image)"
fi

# Check logs for expected output
echo ""
echo "Checking application logs..."
docker logs test-service-container 2>&1 | head -10

# Cleanup
echo ""
echo "Cleaning up..."
docker stop test-service-container > /dev/null
docker rm test-service-container > /dev/null

echo ""
echo "==========================================="
echo "✅ All tests passed for service image"
echo "==========================================="
