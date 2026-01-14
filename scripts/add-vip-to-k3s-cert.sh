#!/bin/bash
# Add VIP (192.168.2.100) to k3s TLS SAN list on all control plane nodes
# This allows the API server certificate to be valid for the VIP

set -e

VIP="192.168.2.100"
SSH_KEY="$HOME/.ssh/id_ed25519_raolivei"
NODES=(
    "192.168.2.101:node-1.eldertree.local"
    "192.168.2.102:node-2.eldertree.local"
    "192.168.2.103:node-3.eldertree.local"
)

echo "=========================================="
echo "Adding VIP ($VIP) to k3s TLS SAN list"
echo "=========================================="
echo ""

for node_info in "${NODES[@]}"; do
    IFS=':' read -r node_ip node_hostname <<< "$node_info"
    echo "=== Processing $node_hostname ($node_ip) ==="
    
    ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "raolivei@$node_ip" bash << 'ENDSSH'
set -e

VIP="192.168.2.100"
CONFIG_FILE="/etc/rancher/k3s/config.yaml"
BACKUP_FILE="${CONFIG_FILE}.backup-$(date +%Y%m%d-%H%M%S)"

echo "Checking current config..."
if [ -f "$CONFIG_FILE" ]; then
    echo "Current tls-san entries:"
    sudo grep -A 10 "^tls-san:" "$CONFIG_FILE" || echo "No tls-san found"
    
    # Check if VIP is already in the list
    if sudo grep -q "$VIP" "$CONFIG_FILE" 2>/dev/null; then
        echo "✅ VIP ($VIP) already in tls-san list"
    else
        echo "Adding VIP ($VIP) to tls-san list..."
        
        # Backup config
        sudo cp "$CONFIG_FILE" "$BACKUP_FILE"
        echo "✅ Backed up config to $BACKUP_FILE"
        
        # Add VIP to tls-san list
        if sudo grep -q "^tls-san:" "$CONFIG_FILE"; then
            # tls-san exists, add VIP to the list
            sudo sed -i "/^tls-san:/a\\  - $VIP" "$CONFIG_FILE"
        else
            # tls-san doesn't exist, create it
            echo "tls-san:" | sudo tee -a "$CONFIG_FILE" > /dev/null
            echo "  - $VIP" | sudo tee -a "$CONFIG_FILE" > /dev/null
        fi
        
        echo "✅ Added VIP to config"
        echo ""
        echo "Updated config:"
        sudo cat "$CONFIG_FILE"
        
        echo ""
        echo "Restarting k3s to apply changes..."
        sudo systemctl restart k3s
        
        echo "Waiting for k3s to be ready..."
        sleep 15
        
        if sudo systemctl is-active --quiet k3s; then
            echo "✅ k3s restarted successfully"
        else
            echo "⚠️  k3s may not be fully ready yet"
        fi
    fi
else
    echo "⚠️  Config file not found: $CONFIG_FILE"
    echo "   Creating new config file..."
    echo "tls-san:" | sudo tee "$CONFIG_FILE" > /dev/null
    echo "  - $VIP" | sudo tee -a "$CONFIG_FILE" > /dev/null
    sudo systemctl restart k3s
    sleep 15
fi
ENDSSH

    echo ""
done

echo "=========================================="
echo "✅ VIP added to all control plane nodes"
echo "=========================================="
echo ""
echo "The API server certificate should now be valid for $VIP"
echo "Wait a few minutes for certificates to be regenerated, then test:"
echo "  kubectl config set-cluster eldertree --server=https://$VIP:6443"
echo "  kubectl get nodes"

