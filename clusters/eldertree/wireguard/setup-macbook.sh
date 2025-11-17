#!/bin/bash
# Generate WireGuard client configuration for MacBook
# Run this script locally on your Mac

set -e

echo "=== WireGuard MacBook Client Setup ==="
echo ""

# Check if WireGuard tools are installed
if ! command -v wg &> /dev/null; then
    echo "📦 WireGuard tools not found. Installing..."
    echo "   Run: brew install wireguard-tools"
    read -p "Press Enter after installing..."
fi

# Create clients directory
mkdir -p clients
chmod 700 clients

echo "🔑 Generating MacBook keys..."
umask 077
wg genkey > clients/macbook.private
wg pubkey < clients/macbook.private > clients/macbook.public

CLIENT_PRIVATE_KEY=$(cat clients/macbook.private)
CLIENT_PUBLIC_KEY=$(cat clients/macbook.public)

echo ""
echo "✅ Keys generated!"
echo ""
echo "📋 Your MacBook Public Key (save this):"
echo "$CLIENT_PUBLIC_KEY"
echo ""

# Get server details
echo "🌍 Server Configuration"
echo ""
read -p "Enter your home public IP or domain: " SERVER_ENDPOINT
read -p "Enter server public key (from Pi): " SERVER_PUBLIC_KEY

# Optional: custom networks
echo ""
echo "📡 Network Configuration"
echo "   Default networks to route through VPN:"
echo "   - 10.8.0.0/24 (WireGuard tunnel)"
echo "   - 10.42.0.0/16 (k3s pods)"
echo "   - 10.43.0.0/16 (k3s services)"
echo ""
read -p "Enter your home LAN subnet [192.168.1.0/24]: " LAN_SUBNET
LAN_SUBNET=${LAN_SUBNET:-192.168.1.0/24}

# Generate client config
echo ""
echo "📝 Generating client configuration..."
cat > clients/macbook.conf <<EOF
# WireGuard Client Configuration - MacBook
# Split-tunnel: Only cluster traffic goes through VPN
# Generated: $(date)

[Interface]
Address = 10.8.0.2/32
PrivateKey = $CLIENT_PRIVATE_KEY
DNS = 10.8.0.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT:51820
AllowedIPs = 10.8.0.0/24, 10.42.0.0/16, 10.43.0.0/16, $LAN_SUBNET
PersistentKeepalive = 25
EOF

chmod 600 clients/macbook.conf

echo "✅ Configuration saved to: clients/macbook.conf"
echo ""
echo "📋 ADD THIS PEER TO SERVER:"
echo "------------------------------------------------------------"
echo "[Peer]"
echo "# MacBook"
echo "PublicKey = $CLIENT_PUBLIC_KEY"
echo "AllowedIPs = 10.8.0.2/32"
echo "PersistentKeepalive = 25"
echo "------------------------------------------------------------"
echo ""
echo "🔧 On your Pi, run:"
echo "   sudo nano /etc/wireguard/wg0.conf"
echo "   # Add the [Peer] section above"
echo "   sudo systemctl restart wg-quick@wg0"
echo ""
echo "📦 Next: Install WireGuard on Mac:"
echo "   1. Install: brew install wireguard-tools"
echo "   2. Install app: brew install --cask wireguard"
echo "   3. Import: clients/macbook.conf"
echo ""

