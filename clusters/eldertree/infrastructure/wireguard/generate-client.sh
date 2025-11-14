#!/bin/bash
set -e

# WireGuard Client Configuration Generator
# Generates client configs and adds them to the server

CLIENT_NAME="${1:-client}"
WG_NETWORK="10.8.0.0/24"
WG_SERVER_IP="10.8.0.1"
LOCAL_NETWORK="192.168.2.0/24"
PI_HOST="eldertree"
PI_USER="raolivei"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔐 WireGuard Client Configuration Generator"
echo "=========================================="
echo "Client name: ${CLIENT_NAME}"
echo ""

# Generate client keys
echo "🔑 Generating client keys..."
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

echo "✅ Client keys generated"
echo "   Public Key: ${CLIENT_PUBLIC_KEY}"
echo ""

# Get server public key and IP
echo "📡 Fetching server configuration..."
SERVER_PUBLIC_KEY=$(ssh ${PI_USER}@${PI_HOST} "sudo cat /etc/wireguard/server_public.key" 2>/dev/null)

if [ -z "$SERVER_PUBLIC_KEY" ]; then
    echo "❌ Could not fetch server public key. Is WireGuard installed on the server?"
    exit 1
fi

# Get server public IP (try to get from server, fallback to asking)
PUBLIC_IP=$(ssh ${PI_USER}@${PI_HOST} "curl -s ifconfig.me 2>/dev/null || echo ''" 2>/dev/null)

if [ -z "$PUBLIC_IP" ]; then
    echo "⚠️  Could not detect public IP automatically"
    read -p "Enter server public IP or hostname: " PUBLIC_IP
fi

# Calculate client IP (assign sequentially)
CLIENT_IP_NUM=$(ssh ${PI_USER}@${PI_HOST} "sudo wg show wg0 peers 2>/dev/null | wc -l" || echo "0")
CLIENT_IP_NUM=$((CLIENT_IP_NUM + 2))  # Start from .2 (server is .1)
CLIENT_IP="10.8.0.${CLIENT_IP_NUM}"

echo "📋 Client IP: ${CLIENT_IP}"
echo ""

# Create client configuration
CLIENT_CONFIG_FILE="client-${CLIENT_NAME}.conf"

cat > "${CLIENT_CONFIG_FILE}" <<EOF
[Interface]
# Client private key (keep this secret!)
PrivateKey = ${CLIENT_PRIVATE_KEY}
# Client IP in VPN network
Address = ${CLIENT_IP}/24
# DNS (use Pi-hole on local network)
DNS = 192.168.2.83

[Peer]
# Server public key
PublicKey = ${SERVER_PUBLIC_KEY}
# Server address and port
Endpoint = ${PUBLIC_IP}:51820
# Allowed IPs (VPN network + local network)
AllowedIPs = ${WG_NETWORK}, ${LOCAL_NETWORK}
# Keep connection alive
PersistentKeepalive = 25
EOF

chmod 600 "${CLIENT_CONFIG_FILE}"

echo "✅ Client configuration created: ${CLIENT_CONFIG_FILE}"
echo ""

# Add client to server
echo "🔧 Adding client to server..."
PEER_CONFIG="[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32"

# Try to add peer via wg command (for running service)
if ssh ${PI_USER}@${PI_HOST} "sudo wg set wg0 peer ${CLIENT_PUBLIC_KEY} allowed-ips ${CLIENT_IP}/32" 2>/dev/null; then
    echo "✅ Peer added to running WireGuard service"
    
    # Also add to config file for persistence
    ssh ${PI_USER}@${PI_HOST} "echo '' | sudo tee -a /etc/wireguard/wg0.conf > /dev/null && echo '${PEER_CONFIG}' | sudo tee -a /etc/wireguard/wg0.conf > /dev/null" 2>/dev/null && \
        echo "✅ Peer configuration saved to server config file"
else
    echo "⚠️  Could not add peer automatically. Please add manually:"
    echo ""
    echo "SSH to server and run:"
    echo "  sudo wg set wg0 peer ${CLIENT_PUBLIC_KEY} allowed-ips ${CLIENT_IP}/32"
    echo ""
    echo "Or add to /etc/wireguard/wg0.conf:"
    echo ""
    echo "${PEER_CONFIG}"
    echo ""
fi

# Generate QR code for mobile devices
if command -v qrencode &> /dev/null; then
    QR_FILE="client-${CLIENT_NAME}.png"
    qrencode -t png -o "${QR_FILE}" < "${CLIENT_CONFIG_FILE}"
    echo "📱 QR code generated: ${QR_FILE}"
    echo "   Scan this with WireGuard mobile app"
elif [ "$CLIENT_NAME" = "mobile" ]; then
    echo "⚠️  qrencode not installed. Install with: brew install qrencode"
    echo "   Or manually import ${CLIENT_CONFIG_FILE} in WireGuard app"
fi

echo ""
echo "🎉 Client configuration complete!"
echo ""
echo "Next steps:"
echo ""
if [ "$CLIENT_NAME" = "mac" ]; then
    echo "📱 macOS Setup:"
    echo "  1. Install WireGuard: brew install wireguard-tools"
    echo "  2. Copy config: sudo cp ${CLIENT_CONFIG_FILE} /usr/local/etc/wireguard/wg0.conf"
    echo "  3. Start VPN: sudo wg-quick up wg0"
    echo "  4. Check status: sudo wg show"
elif [ "$CLIENT_NAME" = "mobile" ]; then
    echo "📱 Mobile Setup:"
    echo "  1. Install WireGuard app (iOS/Android)"
    echo "  2. Scan QR code: ${QR_FILE:-${CLIENT_CONFIG_FILE}}"
    echo "  3. Or import config file: ${CLIENT_CONFIG_FILE}"
    echo "  4. Connect to VPN"
else
    echo "📱 Setup:"
    echo "  1. Copy ${CLIENT_CONFIG_FILE} to your device"
    echo "  2. Import into WireGuard client"
    echo "  3. Connect to VPN"
fi
echo ""
echo "Test connection:"
echo "  ping 192.168.2.83"
echo "  kubectl get nodes"
echo ""

