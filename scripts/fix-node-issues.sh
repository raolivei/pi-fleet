#!/bin/bash
# Fix node-1 and node-1 issues
# 1. Remove unreachable node-1 from cluster
# 2. Fix IP conflicts
# 3. Verify node-1 configuration

set -e

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
SSH_KEY="$HOME/.ssh/id_ed25519_raolivei"

echo "=========================================="
echo "Fixing Node Issues - eldertree Cluster"
echo "=========================================="
echo ""

export KUBECONFIG="$KUBECONFIG"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG" ]; then
    echo "❌ Kubeconfig not found: $KUBECONFIG"
    exit 1
fi

echo "Current status:"
kubectl get nodes
echo ""

# Step 1: Remove node-1 if it's unreachable
echo "Step 1: Checking node-1 status..."
if ! ping -c 1 -W 2 192.168.2.100 > /dev/null 2>&1; then
    echo "  ⚠️  node-1 (192.168.2.100) is unreachable"
    read -p "  Remove node-1 from cluster? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "  Removing node-1 from cluster..."
        kubectl delete node node-1.eldertree.local 2>&1 || echo "    (Node may already be removed or in use)"
        echo "  ✅ node-1 removal attempted"
    else
        echo "  ⏭️  Skipping node-1 removal"
    fi
else
    echo "  ✅ node-1 is reachable, skipping removal"
fi
echo ""

# Step 2: Check and fix IP conflicts on node-1
echo "Step 2: Checking node-1 IP configuration..."
if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "raolivei@192.168.2.101" "hostname" > /dev/null 2>&1; then
    echo "  ✅ node-1 is accessible"
    
    # Get current IPs
    NODE1_ETH0=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@192.168.2.101" "ip addr show eth0 | grep 'inet ' | awk '{print \$2}' | cut -d/ -f1" 2>/dev/null || echo "")
    NODE1_WLAN0=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@192.168.2.101" "ip addr show wlan0 | grep 'inet ' | awk '{print \$2}' | cut -d/ -f1" 2>/dev/null || echo "")
    
    echo "  Current IPs:"
    echo "    eth0:  ${NODE1_ETH0:-not found}"
    echo "    wlan0: ${NODE1_WLAN0:-not found}"
    
    # Check if node-1 has the correct IP (should be 10.0.0.1 for eth0, but node-1 also has this)
    # According to docs, node-1 should have 10.0.0.1, but if node-1 exists, there's a conflict
    if [ "$NODE1_ETH0" = "10.0.0.1" ]; then
        echo "  ⚠️  node-1 has IP 10.0.0.1 (same as node-1)"
        echo "  This is correct if node-1 is removed, but verify network configuration"
    fi
else
    echo "  ❌ Cannot access node-1"
    exit 1
fi
echo ""

# Step 3: Verify node-1 k3s configuration
echo "Step 3: Verifying node-1 k3s configuration..."
if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@192.168.2.101" "systemctl is-active k3s" > /dev/null 2>&1; then
    echo "  ✅ k3s service is active"
    
    # Check k3s server configuration
    K3S_ARGS=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@192.168.2.101" "sudo cat /etc/systemd/system/k3s.service.d/override.conf 2>/dev/null | grep ExecStart || sudo systemctl show k3s | grep ExecStart" 2>/dev/null || echo "")
    echo "  k3s configuration:"
    echo "$K3S_ARGS" | head -3
else
    echo "  ❌ k3s service is not active"
fi
echo ""

# Step 4: Check etcd status
echo "Step 4: Checking etcd cluster status..."
ETCD_MEMBERS=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels["node-role.kubernetes.io/control-plane"]=="true") | "\(.metadata.name): etcd-voter=\(.status.conditions[] | select(.type=="EtcdIsVoter") | .status)"' 2>/dev/null || echo "")
if [ -n "$ETCD_MEMBERS" ]; then
    echo "  etcd members:"
    echo "$ETCD_MEMBERS" | while read -r line; do
        echo "    $line"
    done
else
    echo "  ⚠️  Could not get etcd status"
fi
echo ""

# Step 5: Final status
echo "Step 5: Final node status:"
echo "-------------------------"
kubectl get nodes -o wide
echo ""

echo "=========================================="
echo "Fix Complete"
echo "=========================================="
echo ""
echo "Next steps if issues persist:"
echo ""
echo "1. If node-1 should be removed:"
echo "   kubectl delete node node-1.eldertree.local"
echo "   kubectl drain node-1.eldertree.local --ignore-daemonsets --delete-emptydir-data"
echo ""
echo "2. If node-1 IP needs to be changed:"
echo "   - SSH to node-1: ssh raolivei@192.168.2.101"
echo "   - Check NetworkManager config: sudo nmcli connection show"
echo "   - Update eth0 IP if needed"
echo ""
echo "3. To verify network configuration:"
echo "   cd ~/WORKSPACE/raolivei/pi-fleet/ansible"
echo "   ansible-playbook playbooks/configure-eth0-static.yml --limit node-1"
echo ""




