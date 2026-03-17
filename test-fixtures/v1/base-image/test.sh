#!/bin/bash
set -e

# Test script for base image (standard variant)
# This receives IMAGE_TAG from the workflow

echo "======================================"
echo "Testing Base Image (Standard Variant)"
echo "======================================"
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

if [ -z "$REVISION" ]; then
  echo "❌ ERROR: Missing label: org.opencontainers.image.revision"
  exit 1
fi

if [ -z "$CREATED" ]; then
  echo "❌ ERROR: Missing label: org.opencontainers.image.created"
  exit 1
fi

if [ -z "$SOURCE" ]; then
  echo "❌ ERROR: Missing label: org.opencontainers.image.source"
  exit 1
fi

echo "  ✅ Revision: $REVISION"
echo "  ✅ Created: $CREATED"
echo "  ✅ Source: $SOURCE"

# Check architecture
echo ""
echo "Checking architecture..."
ARCH=$(docker inspect --format='{{.Architecture}}' "$IMAGE_TAG")
echo "  Architecture: $ARCH"

if [ "$ARCH" != "amd64" ] && [ "$ARCH" != "arm64" ]; then
  echo "❌ ERROR: Unexpected architecture: $ARCH"
  exit 1
fi

echo "  ✅ Valid architecture: $ARCH"

# Distroless images don't have a shell, so we can't run the container
# But we can verify the image layers
echo ""
echo "Checking image layers..."
LAYER_COUNT=$(docker inspect --format='{{len .RootFS.Layers}}' "$IMAGE_TAG")
echo "  Layer count: $LAYER_COUNT"

if [ "$LAYER_COUNT" -lt 1 ]; then
  echo "❌ ERROR: Image has no layers"
  exit 1
fi

echo "  ✅ Image has $LAYER_COUNT layers"

echo ""
echo "======================================"
echo "✅ All tests passed for base image"
echo "======================================"
