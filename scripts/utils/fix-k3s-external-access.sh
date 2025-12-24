#!/bin/bash
# Fix K3s external access by adding IP to TLS SAN and ensuring service is enabled

set -e

NODE_IP="${1:-192.168.2.86}"
NODE_NAME="${2:-node-0}"

echo "=== Fixing K3s External Access ==="
echo "Node: $NODE_NAME ($NODE_IP)"
echo ""

ssh raolivei@${NODE_IP} << ENDSSH
set -e

# Check current service config
echo "Current K3s service configuration:"
sudo cat /etc/systemd/system/k3s.service | grep -A 10 ExecStart
echo ""

# Check if IP is in TLS SAN
if ! sudo grep -q "--tls-san=${NODE_IP}" /etc/systemd/system/k3s.service; then
    echo "Adding IP address to TLS SAN..."
    
    # Backup service file
    sudo cp /etc/systemd/system/k3s.service /etc/systemd/system/k3s.service.bak
    
    # Add IP to TLS SAN
    sudo sed -i "/--tls-san=/a\\\t'--tls-san=${NODE_IP}' \\\\" /etc/systemd/system/k3s.service
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    # Restart K3s
    echo "Restarting K3s..."
    sudo systemctl restart k3s
    
    echo "✓ Service updated"
else
    echo "✓ IP already in TLS SAN"
fi

# Ensure service is enabled
echo ""
echo "Ensuring service is enabled..."
sudo systemctl enable k3s
sudo systemctl is-enabled k3s

# Wait for service to be ready
echo ""
echo "Waiting for K3s to be ready..."
sleep 10

# Check status
echo ""
echo "Service status:"
sudo systemctl status k3s --no-pager | head -10

# Check if port is listening
echo ""
echo "Port 6443 status:"
sudo ss -tlnp | grep 6443 || echo "Port not listening"

ENDSSH

echo ""
echo "=== Fix Complete ==="
echo ""
echo "Test connection:"
echo "  curl -k https://${NODE_IP}:6443/healthz"
echo ""
echo "Update kubeconfig if needed:"
echo "  export KUBECONFIG=~/.kube/config-eldertree"
echo "  kubectl get nodes"

