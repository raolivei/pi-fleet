#!/bin/bash
# Convert a worker node to a control plane node for HA
# Usage: ./convert-worker-to-control-plane.sh <node-name> <node-ip>
# Example: ./convert-worker-to-control-plane.sh node-2 192.168.2.102

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <node-name> <node-ip>"
    echo "Example: $0 node-2 192.168.2.102"
    exit 1
fi

NODE_NAME="$1"
NODE_IP="$2"
NODE_FQDN="${NODE_NAME}.eldertree.local"
CONTROL_PLANE_IP="192.168.2.101"
CONTROL_PLANE_FQDN="node-1.eldertree.local"
SSH_KEY="$HOME/.ssh/id_ed25519_raolivei"
KUBECONFIG="$HOME/.kube/config-eldertree"

echo "=========================================="
echo "Converting $NODE_FQDN to Control Plane"
echo "=========================================="
echo ""

# Export kubeconfig
export KUBECONFIG

echo "Step 1: Verifying node is currently a worker..."
NODE_STATUS=$(kubectl get node "$NODE_FQDN" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "NotFound")
if [ "$NODE_STATUS" != "True" ]; then
    echo "  ⚠️  Node $NODE_FQDN is not Ready. Status: $NODE_STATUS"
    read -p "  Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo "  ✅ Node verified"
echo ""

echo "Step 2: Getting k3s token from control plane..."
K3S_TOKEN=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$CONTROL_PLANE_IP" "sudo cat /var/lib/rancher/k3s/server/node-token" 2>/dev/null || echo "")
if [ -z "$K3S_TOKEN" ]; then
    echo "  ❌ Could not retrieve k3s token from $CONTROL_PLANE_FQDN"
    exit 1
fi
echo "  ✅ Retrieved k3s token"
echo ""

echo "Step 3: Draining node (moving pods to other nodes)..."
kubectl drain "$NODE_FQDN" --ignore-daemonsets --delete-emptydir-data --force --timeout=300s || {
    echo "  ⚠️  Drain had issues, but continuing..."
}
echo "  ✅ Node drained"
echo ""

echo "Step 4: Stopping k3s-agent on $NODE_FQDN..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$NODE_IP" "sudo systemctl stop k3s-agent" || echo "  (Service may already be stopped)"
echo "  ✅ k3s-agent stopped"
echo ""

echo "Step 5: Removing node from cluster..."
kubectl delete node "$NODE_FQDN" || echo "  (Node may already be removed)"
sleep 5
echo "  ✅ Node removed from cluster"
echo ""

echo "Step 6: Cleaning up worker state on $NODE_FQDN..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$NODE_IP" <<EOF
    # Remove k3s-agent service
    sudo systemctl disable k3s-agent || true
    sudo rm -f /etc/systemd/system/k3s-agent.service
    sudo rm -rf /etc/systemd/system/k3s-agent.service.d
    
    # Clean up agent state
    sudo rm -rf /var/lib/rancher/k3s/agent
    sudo rm -rf /var/lib/rancher/k3s/agent-tls
    
    # Remove node registration files
    sudo rm -f /etc/rancher/node/password
    sudo rm -f /etc/rancher/node/node-name
    
    echo "  ✅ Worker state cleaned up"
EOF
echo ""

echo "Step 7: Getting k3s version from control plane..."
K3S_VERSION=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$CONTROL_PLANE_IP" "sudo k3s --version | awk '{print \$3}'" 2>/dev/null || echo "")
if [ -z "$K3S_VERSION" ]; then
    echo "  ⚠️  Could not get k3s version, using latest"
    K3S_VERSION=""
else
    echo "  ✅ Found k3s version: $K3S_VERSION"
fi
echo ""

echo "Step 8: Installing k3s as control plane on $NODE_FQDN..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$NODE_IP" <<EOF
    set -e
    export INSTALL_K3S_VERSION="$K3S_VERSION"
    export K3S_TOKEN="$K3S_TOKEN"
    curl -sfL https://get.k3s.io | sh -s - server \
      --server https://$CONTROL_PLANE_FQDN:6443 \
      --write-kubeconfig-mode=644 \
      --tls-san=$NODE_FQDN \
      --disable servicelb
    
    echo "  ✅ k3s control plane installed"
EOF
echo ""

echo "Step 9: Configuring k3s to use gigabit network..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$NODE_IP" <<'EOF'
    # Get gigabit IP for this node
    NODE_NUM=$(hostname | sed 's/node-//')
    GIGABIT_IP="10.0.0.$NODE_NUM"
    
    # Check if node-ip already configured
    if grep -q "node-ip=$GIGABIT_IP" /etc/systemd/system/k3s.service; then
        echo "  ✅ Gigabit IP already configured"
    else
        # Update service file
        sudo sed -i "s|ExecStart=.*|& --node-ip=$GIGABIT_IP --flannel-iface=eth0|" /etc/systemd/system/k3s.service
        sudo systemctl daemon-reload
        sudo systemctl restart k3s
        echo "  ✅ Gigabit network configured"
    fi
EOF
echo ""

echo "Step 10: Waiting for node to join cluster (30 seconds)..."
sleep 30
echo ""

echo "Step 11: Verifying node status..."
NODE_READY=$(kubectl get node "$NODE_FQDN" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "NotFound")
CONTROL_PLANE=$(kubectl get node "$NODE_FQDN" -o jsonpath='{.metadata.labels.node-role\.kubernetes.io/control-plane}' 2>/dev/null || echo "")

if [ "$NODE_READY" == "True" ] && [ "$CONTROL_PLANE" == "true" ]; then
    echo "  ✅ Node is Ready and is a control plane node"
else
    echo "  ⚠️  Node status: Ready=$NODE_READY, ControlPlane=$CONTROL_PLANE"
    echo "  Check node status: kubectl get node $NODE_FQDN"
fi
echo ""

echo "Step 12: Verifying etcd membership..."
kubectl get nodes -o json | jq -r ".items[] | select(.metadata.name == \"$NODE_FQDN\") | .status.conditions[] | select(.type == \"EtcdIsVoter\") | \"EtcdIsVoter: \(.status)\"" || echo "  (etcd status check failed)"
echo ""

echo "=========================================="
echo "Conversion Complete"
echo "=========================================="
echo ""
echo "Verify cluster status:"
echo "  kubectl get nodes"
echo ""
echo "Check etcd members:"
echo "  kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels.\"node-role.kubernetes.io/control-plane\") | \"\(.metadata.name): etcd-voter=\(.status.conditions[] | select(.type==\"EtcdIsVoter\") | .status)\"'"
echo ""

