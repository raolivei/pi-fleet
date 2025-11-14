#!/bin/bash
# Quick script to connect Mac to WireGuard VPN

CONFIG_SOURCE="$HOME/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/infrastructure/wireguard/client-mac.conf"
CONFIG_DEST="/opt/homebrew/etc/wireguard/wg0.conf"

echo "🔐 WireGuard Mac Client Setup"
echo "============================="
echo ""

# Check if config source exists
if [ ! -f "$CONFIG_SOURCE" ]; then
    echo "❌ Config file not found: $CONFIG_SOURCE"
    exit 1
fi

# Install config
echo "📋 Installing WireGuard config..."
sudo mkdir -p /opt/homebrew/etc/wireguard
sudo cp "$CONFIG_SOURCE" "$CONFIG_DEST"
sudo chmod 600 "$CONFIG_DEST"
echo "✅ Config installed to $CONFIG_DEST"
echo ""

# Check if already connected
if sudo wg show wg0 &>/dev/null; then
    echo "⚠️  WireGuard is already connected"
    echo ""
    echo "Current status:"
    sudo wg show wg0
    echo ""
    read -p "Disconnect and reconnect? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo wg-quick down wg0
        sleep 1
    else
        exit 0
    fi
fi

# Connect
echo "🚀 Connecting to VPN..."
sudo wg-quick up wg0

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Connected!"
    echo ""
    echo "Status:"
    sudo wg show wg0
    echo ""
    echo "Test connectivity:"
    echo "  ping 192.168.2.83"
    echo "  kubectl get nodes"
    echo "  curl -k https://canopy.eldertree.local/api/v1/health"
    echo ""
    echo "To disconnect: sudo wg-quick down wg0"
else
    echo "❌ Failed to connect. Check logs above."
    exit 1
fi

