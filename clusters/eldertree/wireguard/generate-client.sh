#!/bin/bash
# Generate WireGuard client configuration
# Usage: ./generate-client.sh <client-name> <client-ip-last-octet>
# Example: ./generate-client.sh iphone 2

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <client-name> <client-ip-last-octet>"
    echo "Example: $0 iphone 2"
    echo ""
    echo "This will create client config with IP 10.8.0.2"
    exit 1
fi

CLIENT_NAME=$1
CLIENT_IP_OCTET=$2
CLIENT_IP="10.8.0.${CLIENT_IP_OCTET}"

echo "=== Generating WireGuard Client Config ==="
echo "Client: $CLIENT_NAME"
echo "IP: $CLIENT_IP"
echo ""

# Create clients directory
mkdir -p clients
chmod 700 clients

# Check if client already exists
if [ -f "clients/${CLIENT_NAME}.conf" ]; then
    echo "⚠️  Client config already exists: clients/${CLIENT_NAME}.conf"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing config. Exiting."
        exit 0
    fi
fi

# Generate client keys
echo "🔑 Generating client keys..."
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# Get server public key
if [ ! -f /etc/wireguard/publickey ]; then
    echo "❌ Server public key not found. Run setup-server.sh first."
    exit 1
fi
SERVER_PUBLIC_KEY=$(sudo cat /etc/wireguard/publickey)

# Get server endpoint (try to detect public IP)
echo "🌍 Detecting server endpoint..."
PUBLIC_IP=$(curl -s ifconfig.me || echo "<YOUR_PUBLIC_IP>")
echo "Detected public IP: $PUBLIC_IP"
echo ""
read -p "Use this IP or enter custom domain/IP (press Enter to use $PUBLIC_IP): " CUSTOM_ENDPOINT
if [ -n "$CUSTOM_ENDPOINT" ]; then
    SERVER_ENDPOINT="$CUSTOM_ENDPOINT"
else
    SERVER_ENDPOINT="$PUBLIC_IP"
fi

# Create client config
echo "📝 Creating client config..."
cat > "clients/${CLIENT_NAME}.conf" <<EOF
# WireGuard Client Configuration - Split Tunnel for k3s Access
# Client: $CLIENT_NAME
# Generated: $(date)

[Interface]
Address = ${CLIENT_IP}/32
PrivateKey = $CLIENT_PRIVATE_KEY
DNS = 10.8.0.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = ${SERVER_ENDPOINT}:51820
AllowedIPs = 10.8.0.0/24, 10.42.0.0/16, 10.43.0.0/16, 192.168.1.0/24
PersistentKeepalive = 25
EOF

chmod 600 "clients/${CLIENT_NAME}.conf"

# Generate QR code for mobile devices
if command -v qrencode &> /dev/null; then
    echo "📱 Generating QR code for mobile..."
    qrencode -t ansiutf8 < "clients/${CLIENT_NAME}.conf"
    qrencode -t png -o "clients/${CLIENT_NAME}.png" < "clients/${CLIENT_NAME}.conf"
    echo "✅ QR code saved to clients/${CLIENT_NAME}.png"
else
    echo "💡 Install qrencode to generate QR codes: sudo apt install qrencode"
fi

echo ""
echo "✅ Client config created: clients/${CLIENT_NAME}.conf"
echo ""
echo "📋 Now add this peer to the server config:"
echo ""
echo "[Peer]"
echo "PublicKey = $CLIENT_PUBLIC_KEY"
echo "AllowedIPs = ${CLIENT_IP}/32"
echo "PersistentKeepalive = 25"
echo ""
echo "Run these commands on the server:"
echo "sudo bash -c 'cat >> /etc/wireguard/wg0.conf << \"EOF\""
echo ""
echo "[Peer]"
echo "PublicKey = $CLIENT_PUBLIC_KEY"
echo "AllowedIPs = ${CLIENT_IP}/32"
echo "PersistentKeepalive = 25"
echo "EOF'"
echo ""
echo "sudo systemctl restart wg-quick@wg0"
echo ""

