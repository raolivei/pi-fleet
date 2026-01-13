#!/bin/bash
# Update kubeconfig for HA - tries to get kubeconfig from any available control plane node
# This ensures kubectl can connect even if one node is down

set -e

KUBECONFIG_PATH="$HOME/.kube/config-eldertree"
SSH_KEY="$HOME/.ssh/id_ed25519_raolivei"

# Control plane nodes (in order of preference)
NODES=(
  "192.168.2.101:node-1.eldertree.local"
  "192.168.2.102:node-2.eldertree.local"
  "192.168.2.103:node-3.eldertree.local"
)

echo "=========================================="
echo "Updating kubeconfig for HA"
echo "=========================================="
echo ""

# Check SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ SSH key not found: $SSH_KEY"
    exit 1
fi

# Create .kube directory if it doesn't exist
mkdir -p "$HOME/.kube"

# Try to get kubeconfig from any available node
KUBECONFIG_RETRIEVED=false
for node_info in "${NODES[@]}"; do
    IFS=':' read -r node_ip node_hostname <<< "$node_info"
    echo "Trying to retrieve kubeconfig from $node_hostname ($node_ip)..."
    
    if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "raolivei@$node_ip" "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s-eldertree.yaml 2>/dev/null; then
        echo "   ✅ Kubeconfig retrieved from $node_hostname"
        KUBECONFIG_RETRIEVED=true
        break
    else
        echo "   ⚠️  $node_hostname is not accessible, trying next node..."
    fi
done

if [ "$KUBECONFIG_RETRIEVED" = false ]; then
    echo ""
    echo "❌ Failed to retrieve kubeconfig from any control plane node"
    echo "   All nodes may be down or unreachable"
    exit 1
fi

# Copy to final location
cp /tmp/k3s-eldertree.yaml "$KUBECONFIG_PATH"

# Update server URL - use the first available node's IP
# For true HA, you should set up a load balancer, but for now we'll use the node we got the config from
FIRST_AVAILABLE_NODE_IP=$(echo "${NODES[0]}" | cut -d':' -f1)
echo ""
echo "2. Updating server URL to use $FIRST_AVAILABLE_NODE_IP..."
sed -i '' "s|server: https://0.0.0.0:6443|server: https://$FIRST_AVAILABLE_NODE_IP:6443|g" "$KUBECONFIG_PATH"

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
echo "✅ Kubeconfig updated successfully!"
echo ""
echo "⚠️  NOTE: This kubeconfig points to a single node IP."
echo "   If that node goes down, you'll need to run this script again"
echo "   to get the kubeconfig from another node."
echo ""
echo "   For true HA, consider setting up a load balancer (kube-vip or MetalLB)"
echo "   See: docs/HA_KUBECONFIG_SETUP.md"
echo ""
echo "Location: $KUBECONFIG_PATH"
echo ""
echo "Testing connection..."
export KUBECONFIG="$KUBECONFIG_PATH"
if kubectl cluster-info > /dev/null 2>&1; then
    echo "✅ Cluster connection successful!"
    echo ""
    kubectl get nodes
else
    echo "⚠️  Cluster connection test failed."
    echo "   The node may be down. Try running this script again to get config from another node."
fi

# Cleanup
rm -f /tmp/k3s-eldertree.yaml

echo ""
echo "=========================================="
echo "Update Complete"
echo "=========================================="

