#!/bin/bash
# Script to transfer Docker images to remote k3s cluster node

REMOTE_HOST="192.168.2.83"
REMOTE_USER="${REMOTE_USER:-$(whoami)}"
REMOTE_DIR="/tmp/k8s-images"

echo "=== Transferring Docker images to cluster node ==="
echo "Target: ${REMOTE_USER}@${REMOTE_HOST}"
echo ""

# Create remote directory
echo "Creating remote directory..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p ${REMOTE_DIR}"

# Transfer images
echo "Transferring swimto-api.tar.gz..."
scp swimto-api.tar.gz ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/

echo "Transferring nima-api.tar.gz..."
scp nima-api.tar.gz ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/

# Load images into k3s
echo ""
echo "Loading images into k3s..."
ssh ${REMOTE_USER}@${REMOTE_HOST} << 'EOF'
cd /tmp/k8s-images
echo "Loading swimto-api..."
gunzip -c swimto-api.tar.gz | sudo k3s ctr images import -
echo "Loading nima-api..."
gunzip -c nima-api.tar.gz | sudo k3s ctr images import -
echo "Cleaning up..."
rm -f swimto-api.tar.gz nima-api.tar.gz
EOF

echo ""
echo "=== Images loaded successfully! ==="
echo "Checking images in k3s..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "sudo k3s ctr images ls | grep -E '(swimto-api|nima-api)'"

echo ""
echo "Pods should now be able to pull these images."

