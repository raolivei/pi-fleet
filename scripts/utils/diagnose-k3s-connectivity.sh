#!/bin/bash
# Diagnose and fix k3s connectivity issues

set -e

NODE_IP="${1:-192.168.2.86}"
NODE_NAME="${2:-node-1}"
KUBECONFIG_PATH="${HOME}/.kube/config-eldertree"

echo "=== K3s Connectivity Diagnostic ==="
echo "Node: $NODE_NAME ($NODE_IP)"
echo ""

# Step 1: Check network connectivity
echo "1. Checking network connectivity..."
if ping -c 2 -W 2 "$NODE_IP" > /dev/null 2>&1; then
    echo "   ✓ Network connectivity OK"
else
    echo "   ✗ Network connectivity FAILED"
    echo "   Cannot reach $NODE_IP"
    exit 1
fi

# Step 2: Check if port 6443 is accessible
echo ""
echo "2. Checking k3s API server (port 6443)..."
if timeout 3 bash -c "echo > /dev/tcp/$NODE_IP/6443" 2>/dev/null; then
    echo "   ✓ Port 6443 is accessible"
    PORT_ACCESSIBLE=true
else
    echo "   ✗ Port 6443 is NOT accessible"
    PORT_ACCESSIBLE=false
fi

# Step 3: Check kubeconfig
echo ""
echo "3. Checking kubeconfig..."
if [ -f "$KUBECONFIG_PATH" ]; then
    echo "   ✓ Kubeconfig exists at $KUBECONFIG_PATH"
    export KUBECONFIG="$KUBECONFIG_PATH"
    
    # Try to get cluster info
    if kubectl cluster-info --request-timeout=5s > /dev/null 2>&1; then
        echo "   ✓ Can connect to cluster via kubectl"
        echo ""
        echo "   Cluster status:"
        kubectl get nodes
        exit 0
    else
        echo "   ✗ Cannot connect to cluster via kubectl"
    fi
else
    echo "   ✗ Kubeconfig not found at $KUBECONFIG_PATH"
fi

# Step 4: SSH diagnostic (if port is not accessible)
if [ "$PORT_ACCESSIBLE" = false ]; then
    echo ""
    echo "4. Diagnosing k3s service on node..."
    echo "   Attempting SSH connection to check service status..."
    echo ""
    
    # Check if SSH works
    if ssh -o ConnectTimeout=5 -o BatchMode=yes raolivei@"$NODE_IP" "echo 'SSH OK'" 2>/dev/null; then
        echo "   ✓ SSH connection successful"
        echo ""
        echo "   Checking k3s service status..."
        ssh raolivei@"$NODE_IP" << ENDSSH
set -e

echo "=== K3s Service Status ==="
sudo systemctl status k3s --no-pager | head -15 || true

echo ""
echo "=== Service Active Status ==="
if sudo systemctl is-active k3s > /dev/null 2>&1; then
    echo "✓ Service is ACTIVE"
else
    echo "✗ Service is INACTIVE"
    echo ""
    echo "Attempting to start service..."
    sudo systemctl start k3s
    sleep 5
    sudo systemctl status k3s --no-pager | head -10 || true
fi

echo ""
echo "=== Service Enabled Status ==="
if sudo systemctl is-enabled k3s > /dev/null 2>&1; then
    echo "✓ Service is ENABLED (will start on boot)"
else
    echo "✗ Service is NOT ENABLED"
    echo "Enabling service..."
    sudo systemctl enable k3s
fi

echo ""
echo "=== Port 6443 Listening ==="
if sudo ss -tlnp | grep -q ":6443"; then
    echo "✓ Port 6443 is listening"
    sudo ss -tlnp | grep ":6443"
else
    echo "✗ Port 6443 is NOT listening"
fi

echo ""
echo "=== Recent k3s Logs (last 20 lines) ==="
sudo journalctl -u k3s -n 20 --no-pager || true

ENDSSH
        
        echo ""
        echo "=== Waiting for k3s to be ready ==="
        echo "Waiting 10 seconds for service to stabilize..."
        sleep 10
        
        # Test connection again
        echo ""
        echo "Testing connection again..."
        if timeout 5 bash -c "echo > /dev/tcp/$NODE_IP/6443" 2>/dev/null; then
            echo "✓ Port 6443 is now accessible!"
        else
            echo "✗ Port 6443 still not accessible"
            echo ""
            echo "Please check the k3s logs on the node:"
            echo "  ssh raolivei@$NODE_IP 'sudo journalctl -u k3s -n 50'"
        fi
    else
        echo "   ✗ SSH connection failed"
        echo ""
        echo "   Cannot diagnose service status remotely."
        echo "   Please SSH to the node manually and run:"
        echo "     sudo systemctl status k3s"
        echo "     sudo systemctl start k3s  # if stopped"
        echo "     sudo journalctl -u k3s -n 50  # check logs"
    fi
fi

echo ""
echo "=== Diagnostic Complete ==="
echo ""
echo "Next steps:"
echo "  1. If k3s service was restarted, wait a few seconds and test:"
echo "     export KUBECONFIG=$KUBECONFIG_PATH"
echo "     kubectl get nodes"
echo ""
echo "  2. If service is still not accessible, check logs:"
echo "     ssh raolivei@$NODE_IP 'sudo journalctl -u k3s -n 100'"
echo ""
echo "  3. If you need to fix TLS SAN configuration:"
echo "     cd pi-fleet/scripts/utils"
echo "     ./fix-k3s-external-access.sh $NODE_IP $NODE_NAME"



