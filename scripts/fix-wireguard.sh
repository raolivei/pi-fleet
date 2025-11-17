#!/bin/bash
# Fix WireGuard VPN after Pi restart
# This script checks and fixes WireGuard service status

set -e

PI_HOST="${PI_HOST:-192.168.2.83}"
PI_USER="${PI_USER:-raolivei}"
PI_PASSWORD="${PI_PASSWORD:-Control01!}"

echo "🔐 WireGuard VPN Fix Script"
echo "=========================="
echo ""

# Function to run SSH command
ssh_cmd() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$@"
}

echo "📋 Step 1: Checking WireGuard service status..."
if ssh_cmd "sudo systemctl is-active --quiet wg-quick@wg0"; then
    echo "✅ WireGuard service is running"
else
    echo "⚠️  WireGuard service is not running"
    
    echo ""
    echo "📋 Step 2: Checking if service is enabled..."
    if ssh_cmd "sudo systemctl is-enabled --quiet wg-quick@wg0"; then
        echo "✅ Service is enabled for auto-start"
    else
        echo "⚠️  Service is not enabled, enabling now..."
        ssh_cmd "sudo systemctl enable wg-quick@wg0"
        echo "✅ Service enabled"
    fi
    
    echo ""
    echo "📋 Step 3: Checking WireGuard configuration..."
    if ssh_cmd "test -f /etc/wireguard/wg0.conf"; then
        echo "✅ WireGuard config exists"
    else
        echo "❌ WireGuard config not found at /etc/wireguard/wg0.conf"
        echo "   You may need to re-run the installation job"
        exit 1
    fi
    
    echo ""
    echo "📋 Step 4: Checking IP forwarding..."
    IP_FORWARD=$(ssh_cmd "cat /proc/sys/net/ipv4/ip_forward")
    if [ "$IP_FORWARD" = "1" ]; then
        echo "✅ IP forwarding is enabled"
    else
        echo "⚠️  IP forwarding is disabled, enabling..."
        ssh_cmd "echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf"
        ssh_cmd "sudo sysctl -p"
        echo "✅ IP forwarding enabled"
    fi
    
    echo ""
    echo "📋 Step 5: Starting WireGuard service..."
    ssh_cmd "sudo systemctl start wg-quick@wg0"
    sleep 2
    
    if ssh_cmd "sudo systemctl is-active --quiet wg-quick@wg0"; then
        echo "✅ WireGuard service started successfully"
    else
        echo "❌ Failed to start WireGuard service"
        echo ""
        echo "Checking logs..."
        ssh_cmd "sudo journalctl -u wg-quick@wg0 -n 20 --no-pager"
        exit 1
    fi
fi

echo ""
echo "📋 Step 6: Checking WireGuard interface..."
WG_STATUS=$(ssh_cmd "sudo wg show 2>&1" || echo "")
if [ -n "$WG_STATUS" ]; then
    echo "✅ WireGuard interface is up"
    echo ""
    echo "WireGuard status:"
    ssh_cmd "sudo wg show"
else
    echo "⚠️  WireGuard interface may not be fully configured"
fi

echo ""
echo "📋 Step 7: Checking if WireGuard is listening on port 51820..."
if ssh_cmd "sudo ss -ulnp | grep -q 51820"; then
    echo "✅ WireGuard is listening on UDP port 51820"
else
    echo "⚠️  WireGuard may not be listening on port 51820"
    echo "   Checking firewall..."
    ssh_cmd "sudo ufw status | grep 51820 || echo 'Port 51820 not found in firewall rules'"
fi

echo ""
echo "📋 Step 8: Checking firewall status..."
FIREWALL_STATUS=$(ssh_cmd "sudo ufw status | head -1")
echo "$FIREWALL_STATUS"

echo ""
echo "🎉 WireGuard fix complete!"
echo ""
echo "To verify from your Mac:"
echo "  sudo wg show"
echo ""
echo "To check server status:"
echo "  sshpass -p '$PI_PASSWORD' ssh $PI_USER@$PI_HOST 'sudo wg show'"

