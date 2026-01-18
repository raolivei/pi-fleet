#!/bin/bash
# Quick fix for k3s connectivity issues
# This script attempts to restart k3s service on the node

set -e

NODE_IP="${1:-192.168.2.86}"
NODE_NAME="${2:-node-1}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_raolivei}"
KUBECONFIG_PATH="${HOME}/.kube/config-eldertree"

echo "=== Fixing K3s Connection ==="
echo "Node: $NODE_NAME ($NODE_IP)"
echo ""

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "⚠️  SSH key not found at: $SSH_KEY"
    echo ""
    echo "Please either:"
    echo "  1. Set SSH_KEY environment variable: export SSH_KEY=/path/to/key"
    echo "  2. Or ensure your SSH key is in the SSH agent"
    echo "  3. Or manually SSH to the node and run the commands below"
    echo ""
    echo "Manual steps:"
    echo "  ssh raolivei@$NODE_IP"
    echo "  sudo systemctl status k3s"
    echo "  sudo systemctl start k3s"
    echo "  sudo systemctl enable k3s"
    exit 1
fi

# Try SSH with the key
echo "Attempting SSH connection..."
if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes raolivei@"$NODE_IP" "echo 'SSH OK'" 2>/dev/null; then
    echo "✓ SSH connection successful"
    echo ""
    
    # Restart k3s service
    echo "Checking and restarting k3s service..."
    ssh -i "$SSH_KEY" raolivei@"$NODE_IP" << ENDSSH
set -e

echo "=== Current Service Status ==="
sudo systemctl status k3s --no-pager | head -10 || true

echo ""
echo "=== Starting Service ==="
sudo systemctl start k3s
sudo systemctl enable k3s

echo ""
echo "=== Waiting for Service to Start ==="
sleep 5

echo ""
echo "=== Service Status After Start ==="
sudo systemctl status k3s --no-pager | head -15 || true

echo ""
echo "=== Port 6443 Status ==="
if sudo ss -tlnp | grep -q ":6443"; then
    echo "✓ Port 6443 is listening"
    sudo ss -tlnp | grep ":6443"
else
    echo "✗ Port 6443 is NOT listening"
    echo ""
    echo "Checking logs for errors..."
    sudo journalctl -u k3s -n 30 --no-pager | tail -20
fi

ENDSSH
    
    echo ""
    echo "=== Waiting for API to be Ready ==="
    echo "Waiting 10 seconds for k3s API to stabilize..."
    sleep 10
    
    # Test connection
    echo ""
    echo "Testing connection..."
    if timeout 5 bash -c "echo > /dev/tcp/$NODE_IP/6443" 2>/dev/null; then
        echo "✓ Port 6443 is now accessible!"
        echo ""
        
        # Test kubectl
        if [ -f "$KUBECONFIG_PATH" ]; then
            export KUBECONFIG="$KUBECONFIG_PATH"
            echo "Testing kubectl connection..."
            if kubectl get nodes --request-timeout=10s > /dev/null 2>&1; then
                echo "✓ kubectl connection successful!"
                echo ""
                echo "Cluster status:"
                kubectl get nodes
            else
                echo "⚠️  Port is accessible but kubectl still fails"
                echo "   You may need to wait a bit longer or check kubeconfig"
            fi
        fi
    else
        echo "✗ Port 6443 still not accessible"
        echo ""
        echo "Please check the k3s logs:"
        echo "  ssh -i $SSH_KEY raolivei@$NODE_IP 'sudo journalctl -u k3s -n 50'"
    fi
    
else
    echo "✗ SSH connection failed"
    echo ""
    echo "Troubleshooting SSH:"
    echo "  1. Check if key exists: ls -la $SSH_KEY"
    echo "  2. Check key permissions: chmod 600 $SSH_KEY"
    echo "  3. Try adding key to agent: ssh-add $SSH_KEY"
    echo "  4. Test SSH manually: ssh -i $SSH_KEY raolivei@$NODE_IP"
    echo ""
    echo "If SSH still fails, you'll need to manually access the node and run:"
    echo "  sudo systemctl start k3s"
    echo "  sudo systemctl enable k3s"
    echo "  sudo systemctl status k3s"
    exit 1
fi

echo ""
echo "=== Fix Complete ==="



