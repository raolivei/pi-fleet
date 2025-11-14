#!/bin/bash
# Manual script to load images into k3s cluster
# Run this on the cluster node (192.168.2.83)

set -e

echo "=== Loading Docker images into k3s ==="
echo ""

# Check if images exist
if [ ! -f "/tmp/k8s-images/swimto-api.tar.gz" ]; then
    echo "Error: swimto-api.tar.gz not found in /tmp/k8s-images/"
    echo "Please transfer the image files first:"
    echo "  scp swimto-api.tar.gz nima-api.tar.gz user@192.168.2.83:/tmp/k8s-images/"
    exit 1
fi

cd /tmp/k8s-images

echo "Loading swimto-api:latest..."
gunzip -c swimto-api.tar.gz | sudo k3s ctr images import -
echo "✓ swimto-api loaded"

if [ -f "nima-api.tar.gz" ]; then
    echo "Loading nima-api:latest..."
    gunzip -c nima-api.tar.gz | sudo k3s ctr images import -
    echo "✓ nima-api loaded"
fi

echo ""
echo "Verifying images..."
sudo k3s ctr images ls | grep -E "(swimto-api|nima-api)" || echo "Images not found in list"

echo ""
echo "=== Done! ==="
echo "Images should now be available for pods to use."

