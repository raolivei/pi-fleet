#!/bin/bash
# Setup kubeconfig for eldertree cluster for use with Lens
# This script retrieves the kubeconfig from node-1 and configures it properly

set -e

NODE_1_IP="192.168.2.101"
NODE_1_HOSTNAME="node-1.eldertree.local"
KUBECONFIG_PATH="$HOME/.kube/config-eldertree"
SSH_KEY="$HOME/.ssh/id_ed25519_raolivei"

echo "=========================================="
echo "Setting up kubeconfig for eldertree cluster"
echo "=========================================="
echo ""

# Check SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ SSH key not found: $SSH_KEY"
    exit 1
fi

# Create .kube directory if it doesn't exist
mkdir -p "$HOME/.kube"

# Retrieve kubeconfig from node-1
echo "1. Retrieving kubeconfig from node-1..."
if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$NODE_1_IP" "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s-eldertree.yaml 2>/dev/null; then
    echo "   ✅ Kubeconfig retrieved"
else
    echo "   ❌ Failed to retrieve kubeconfig from node-1"
    exit 1
fi

# Copy to final location
cp /tmp/k3s-eldertree.yaml "$KUBECONFIG_PATH"

# Update server URL from 0.0.0.0:6443 to node-1 IP
echo "2. Updating server URL..."
sed -i '' "s|server: https://0.0.0.0:6443|server: https://$NODE_1_IP:6443|g" "$KUBECONFIG_PATH"

# Rename cluster from "default" to "eldertree"
echo "3. Renaming cluster to 'eldertree'..."
sed -i '' "s|name: default|name: eldertree|g" "$KUBECONFIG_PATH"
sed -i '' "s|cluster: default|cluster: eldertree|g" "$KUBECONFIG_PATH"

# Rename context from "default" to "eldertree"
echo "4. Renaming context to 'eldertree'..."
sed -i '' "s|current-context: default|current-context: eldertree|g" "$KUBECONFIG_PATH"

# Rename user from "default" to "eldertree"
sed -i '' "s|user: default|user: eldertree|g" "$KUBECONFIG_PATH"

# Set proper permissions
chmod 600 "$KUBECONFIG_PATH"

echo ""
echo "✅ Kubeconfig configured successfully!"
echo ""
echo "Location: $KUBECONFIG_PATH"
echo ""
echo "To use with kubectl:"
echo "  export KUBECONFIG=$KUBECONFIG_PATH"
echo ""
echo "To use with Lens:"
echo "  1. Open Lens"
echo "  2. Go to File → Add Cluster (or click the + icon)"
echo "  3. Select 'From File' or 'From Kubeconfig'"
echo "  4. Navigate to: $KUBECONFIG_PATH"
echo "  OR"
echo "  5. Lens will automatically detect it if you add it to ~/.kube/config"
echo ""
echo "Testing connection..."
export KUBECONFIG="$KUBECONFIG_PATH"
if kubectl cluster-info > /dev/null 2>&1; then
    echo "✅ Cluster connection successful!"
    echo ""
    kubectl get nodes
else
    echo "⚠️  Cluster connection test failed, but kubeconfig is saved."
    echo "   You may need to check network connectivity or firewall rules."
fi

# Cleanup
rm -f /tmp/k3s-eldertree.yaml

echo ""
echo "=========================================="
echo "Setup Complete"
echo "=========================================="


