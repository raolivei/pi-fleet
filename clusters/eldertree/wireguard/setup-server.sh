#!/bin/bash
# WireGuard Server Setup Script for k3s Cluster Access
# Run this on your Raspberry Pi with sudo

set -e

echo "=== WireGuard Server Setup for k3s Cluster (eldertree) ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Install WireGuard
echo "📦 Installing WireGuard..."
apt update
apt install -y wireguard wireguard-tools iptables resolvconf

# Enable IP forwarding permanently
echo "🔧 Enabling IP forwarding..."
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sed -i 's/net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/' /etc/sysctl.conf
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Create WireGuard directory
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

# Generate server keys if they don't exist
if [ ! -f /etc/wireguard/privatekey ]; then
    echo "🔑 Generating server keys..."
    wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
    chmod 600 /etc/wireguard/privatekey
    chmod 644 /etc/wireguard/publickey
    
    echo ""
    echo "✅ Server keys generated!"
    echo "📋 Server Public Key (share with clients):"
    cat /etc/wireguard/publickey
    echo ""
else
    echo "✅ Server keys already exist"
    echo "📋 Server Public Key:"
    cat /etc/wireguard/publickey
    echo ""
fi

# Check if config exists
if [ -f /etc/wireguard/wg0.conf ]; then
    echo "⚠️  /etc/wireguard/wg0.conf already exists"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing config. Setup complete!"
        exit 0
    fi
fi

# Copy config template
echo "📝 Installing WireGuard config..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/wg0.conf" ]; then
    cp "$SCRIPT_DIR/wg0.conf" /etc/wireguard/wg0.conf
    
    # Replace server private key in config
    PRIVATE_KEY=$(cat /etc/wireguard/privatekey)
    sed -i "s|<SERVER_PRIVATE_KEY>|$PRIVATE_KEY|g" /etc/wireguard/wg0.conf
    
    chmod 600 /etc/wireguard/wg0.conf
    echo "✅ Config installed"
else
    echo "❌ wg0.conf template not found in $SCRIPT_DIR"
    exit 1
fi

# Enable and start WireGuard
echo "🚀 Enabling WireGuard service..."
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Check status
echo ""
echo "📊 WireGuard Status:"
wg show

echo ""
echo "✅ WireGuard server setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Note your server's public IP or domain name"
echo "2. Open UDP port 51820 on your firewall/router"
echo "3. Generate client configs using ./generate-client.sh"
echo "4. Configure DNS forwarding (see setup-dns.sh)"
echo ""
echo "🔑 Server Public Key (for client configs):"
cat /etc/wireguard/publickey
echo ""

