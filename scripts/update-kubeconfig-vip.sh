#!/bin/bash
# Update kubeconfig to use kube-vip VIP for HA access
# This ensures Lens can always connect, even if node-1 is down
#
# The VIP (192.168.2.100) floats between control plane nodes using leader election.
# If the current leader (node-1) goes down, another node will take over the VIP.

set -e

KUBECONFIG_PATH="$HOME/.kube/config-eldertree"
VIP="192.168.2.100"

echo "=========================================="
echo "Updating kubeconfig to use VIP ($VIP)"
echo "=========================================="
echo ""

# Check if kubeconfig exists, if not create it from any available node
if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "⚠️  Kubeconfig not found, creating it..."
    echo "   Trying to get kubeconfig from any available control plane node..."
    
    NODES=(
        "192.168.2.101:node-1.eldertree.local"
        "192.168.2.102:node-2.eldertree.local"
        "192.168.2.103:node-3.eldertree.local"
    )
    
    SSH_KEY="$HOME/.ssh/id_ed25519_raolivei"
    KUBECONFIG_RETRIEVED=false
    
    for node_info in "${NODES[@]}"; do
        IFS=':' read -r node_ip node_hostname <<< "$node_info"
        if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "raolivei@$node_ip" "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s-eldertree.yaml 2>/dev/null; then
            echo "   ✅ Kubeconfig retrieved from $node_hostname"
            KUBECONFIG_RETRIEVED=true
            break
        fi
    done
    
    if [ "$KUBECONFIG_RETRIEVED" = false ]; then
        echo "❌ Failed to retrieve kubeconfig from any control plane node"
        exit 1
    fi
    
    # Copy to final location
    mkdir -p "$HOME/.kube"
    cp /tmp/k3s-eldertree.yaml "$KUBECONFIG_PATH"
    rm -f /tmp/k3s-eldertree.yaml
    
    # Update server URL to use VIP
    sed -i '' "s|server: https://0.0.0.0:6443|server: https://$VIP:6443|g" "$KUBECONFIG_PATH"
    
    # Rename cluster, context, and user
    sed -i '' "s|name: default|name: eldertree|g" "$KUBECONFIG_PATH"
    sed -i '' "s|cluster: default|cluster: eldertree|g" "$KUBECONFIG_PATH"
    sed -i '' "s|current-context: default|current-context: eldertree|g" "$KUBECONFIG_PATH"
    sed -i '' "s|user: default|user: eldertree|g" "$KUBECONFIG_PATH"
    
    chmod 600 "$KUBECONFIG_PATH"
    echo "   ✅ Kubeconfig created"
fi

# Backup current kubeconfig
cp "$KUBECONFIG_PATH" "${KUBECONFIG_PATH}.backup-$(date +%Y%m%d-%H%M%S)"
echo "✅ Backed up kubeconfig"

# Update server URL to use VIP
echo "Updating server URL to https://$VIP:6443..."
export KUBECONFIG="$KUBECONFIG_PATH"
kubectl config set-cluster eldertree --server=https://$VIP:6443 2>&1

echo ""
echo "✅ Kubeconfig updated successfully!"
echo ""
echo "Current server URL:"
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "Could not get server URL"

echo ""
echo "Testing connection via VIP..."
if kubectl cluster-info > /dev/null 2>&1; then
    echo "✅ Cluster connection successful via VIP!"
    echo ""
    kubectl get nodes
    echo ""
    echo "✅ kube-vip is working! The VIP floats between control plane nodes."
    echo "   Lens will be able to connect even if node-1 is down."
else
    echo "⚠️  Cluster connection test failed."
    echo "   The VIP may not be fully configured yet."
    echo "   Wait a few seconds and try again."
    echo ""
    echo "   If the issue persists, check:"
    echo "   1. kube-vip pods are running: kubectl get pods -n kube-system -l app=kube-vip"
    echo "   2. VIP is assigned: ping $VIP"
    echo "   3. VIP is in k3s cert: ssh node-1 'sudo grep 192.168.2.100 /etc/rancher/k3s/config.yaml'"
fi

echo ""
echo "=========================================="
echo "Setup Complete"
echo "=========================================="
echo ""
echo "Your kubeconfig now uses the VIP ($VIP) which floats between control plane nodes."
echo "Lens will be able to connect even if node-1 is down!"
echo ""
echo "Location: $KUBECONFIG_PATH"

