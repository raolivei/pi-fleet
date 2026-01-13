#!/bin/bash
# Fix node-2 k3s-agent authentication issue
# Error: "Node password rejected, duplicate hostname"

set -e

SSH_KEY="$HOME/.ssh/id_ed25519_raolivei"
NODE_2_IP="192.168.2.102"

echo "=========================================="
echo "Fixing node-2 k3s-agent Authentication Issue"
echo "=========================================="
echo ""

echo "Issue: node-2 k3s-agent cannot authenticate"
echo "Error: 'Node password rejected, duplicate hostname'"
echo ""

echo "Step 1: Stopping k3s-agent on node-2..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$NODE_2_IP" "sudo systemctl stop k3s-agent" || echo "  (Service may already be stopped)"
echo ""

echo "Step 2: Cleaning up k3s-agent state..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$NODE_2_IP" <<'EOF'
    # Remove password file that may be causing conflict
    sudo rm -f /etc/rancher/node/password
    
    # Clean up agent state
    sudo rm -rf /var/lib/rancher/k3s/agent
    
    # Remove node registration
    sudo rm -f /etc/rancher/node/node-name
    
    echo "  ✅ Cleaned up k3s-agent state"
EOF
echo ""

echo "Step 3: Getting fresh k3s token from control plane..."
K3S_TOKEN=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@192.168.2.101" "sudo cat /var/lib/rancher/k3s/server/node-token" 2>/dev/null || echo "")
if [ -z "$K3S_TOKEN" ]; then
    echo "  ❌ Could not retrieve k3s token from node-1"
    exit 1
fi
echo "  ✅ Retrieved k3s token"
echo ""

echo "Step 4: Checking k3s-agent service file..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$NODE_2_IP" <<EOF
    # Check if service file exists
    if [ -f /etc/systemd/system/k3s-agent.service.d/override.conf ]; then
        echo "  Current k3s-agent override config:"
        sudo cat /etc/systemd/system/k3s-agent.service.d/override.conf | head -10
    else
        echo "  ⚠️  No override config found"
    fi
EOF
echo ""

echo "Step 5: Reconfiguring k3s-agent with --with-node-id flag..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$NODE_2_IP" <<EOF
    # Create override directory
    sudo mkdir -p /etc/systemd/system/k3s-agent.service.d/
    
    # Get current ExecStart line
    CURRENT_EXEC=\$(sudo systemctl show k3s-agent | grep ExecStart | cut -d= -f2-)
    
    # Add --with-node-id flag if not present
    if echo "\$CURRENT_EXEC" | grep -q "with-node-id"; then
        echo "  ✅ --with-node-id flag already present"
    else
        # Create override with --with-node-id
        sudo tee /etc/systemd/system/k3s-agent.service.d/override.conf > /dev/null <<'OVERRIDE'
[Service]
ExecStart=
ExecStart=/usr/local/bin/k3s agent --with-node-id
OVERRIDE
        echo "  ✅ Added --with-node-id flag to k3s-agent"
    fi
    
    # Reload systemd
    sudo systemctl daemon-reload
    echo "  ✅ Reloaded systemd"
EOF
echo ""

echo "Step 6: Starting k3s-agent..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$NODE_2_IP" "sudo systemctl start k3s-agent"
sleep 5
echo ""

echo "Step 7: Checking k3s-agent status..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$NODE_2_IP" "sudo systemctl status k3s-agent --no-pager -l | head -20"
echo ""

echo "Step 8: Waiting for node to register (30 seconds)..."
sleep 30
echo ""

echo "Step 9: Checking node status in cluster..."
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes node-2.eldertree.local 2>&1 || echo "  ⚠️  Node not yet visible in cluster"
echo ""

echo "=========================================="
echo "Fix Complete"
echo "=========================================="
echo ""
echo "Monitor node-2 status:"
echo "  kubectl get nodes node-2.eldertree.local -w"
echo ""
echo "Check k3s-agent logs:"
echo "  ssh raolivei@192.168.2.102 'sudo journalctl -u k3s-agent -f'"
echo ""




