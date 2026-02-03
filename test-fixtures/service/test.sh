#!/bin/bash
set -e

# Test script for service (standard variant)
# This receives IMAGE_TAG from the workflow
# NOTE: Distroless images with no entrypoint cannot be run
# We can only inspect metadata

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

if [ "$ARCH" != "amd64" ] && [ "$ARCH" != "arm64" ]; then
  echo "❌ ERROR: Unexpected architecture: $ARCH"
  exit 1
fi

echo "  ✅ Valid architecture: $ARCH"

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

# Check user (distroless only has root by default, or nonroot)
USER=$(docker inspect --format='{{.Config.User}}' "$IMAGE_TAG")
if [ -z "$USER" ]; then
  USER="root (default)"
fi
echo "  User: $USER"

# Extract and verify metadata file
echo ""
echo "Checking metadata file..."
TEMP_CONTAINER=$(docker create "$IMAGE_TAG")

if docker cp "$TEMP_CONTAINER:/app/metadata.json" /tmp/metadata-test.json 2>/dev/null; then
  echo "  ✅ metadata.json exists"

  # Validate JSON structure
  if jq empty /tmp/metadata-test.json 2>/dev/null; then
    echo "  ✅ metadata.json is valid JSON"

    # Display metadata
    echo ""
    echo "  Metadata content:"
    jq '.' /tmp/metadata-test.json | sed 's/^/    /'

    # Verify variant
    VARIANT=$(jq -r '.variant' /tmp/metadata-test.json)
    if [ "$VARIANT" == "standard" ]; then
      echo ""
      echo "  ✅ Variant is 'standard'"
    else
      echo ""
      echo "⚠️  WARNING: Expected variant 'standard', got '$VARIANT'"
    fi
  else
    echo "⚠️  WARNING: metadata.json is not valid JSON"
  fi

  rm -f /tmp/metadata-test.json
else
  echo "⚠️  WARNING: metadata.json not found"
fi

docker rm "$TEMP_CONTAINER" > /dev/null

# Check image layers
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
echo "==========================================="
echo "✅ All tests passed for service image"
echo "==========================================="
