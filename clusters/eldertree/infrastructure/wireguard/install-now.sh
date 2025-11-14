#!/bin/bash
# Run this script to install WireGuard VPN
# It will guide you through the process

set -e

PI_HOST="${PI_HOST:-eldertree}"
PI_USER="${PI_USER:-raolivei}"
PI_IP="${PI_IP:-192.168.2.83}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔐 WireGuard VPN Installation"
echo "=============================="
echo ""
echo "This will install WireGuard on: ${PI_USER}@${PI_HOST} (${PI_IP})"
echo ""

# Check if we can connect
echo "🔍 Testing SSH connection..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes ${PI_USER}@${PI_IP} "echo 'OK'" 2>/dev/null; then
    echo "✅ SSH connection works!"
    AUTO_INSTALL=true
else
    echo "⚠️  SSH requires authentication"
    echo "   You'll need to run the installation manually"
    AUTO_INSTALL=false
fi

echo ""

if [ "$AUTO_INSTALL" = true ]; then
    echo "📦 Copying installation script to Pi..."
    scp "${SCRIPT_DIR}/install-wireguard.sh" ${PI_USER}@${PI_IP}:/tmp/install-wireguard.sh
    
    echo "🚀 Running installation on Pi..."
    ssh ${PI_USER}@${PI_IP} "sudo bash /tmp/install-wireguard.sh"
    
    echo ""
    echo "✅ Installation complete!"
    echo ""
    echo "📋 Getting server information..."
    SERVER_PUBLIC_KEY=$(ssh ${PI_USER}@${PI_IP} "sudo cat /etc/wireguard/server_public.key")
    PUBLIC_IP=$(ssh ${PI_USER}@${PI_IP} "curl -s ifconfig.me")
    
    echo "   Server Public Key: ${SERVER_PUBLIC_KEY}"
    echo "   Public IP: ${PUBLIC_IP}"
    echo ""
    
    echo "📱 Generating client configurations..."
    cd "${SCRIPT_DIR}"
    ./generate-client.sh mac
    ./generate-client.sh mobile
    
    echo ""
    echo "🎉 Setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. Install WireGuard on Mac: brew install wireguard-tools qrencode"
    echo "2. Copy config: sudo cp client-mac.conf /usr/local/etc/wireguard/wg0.conf"
    echo "3. Start VPN: sudo wg-quick up wg0"
    echo "4. Install WireGuard app on phone and scan client-mobile.png"
    
else
    echo "📋 Manual Installation Required"
    echo ""
    echo "Step 1: SSH to Pi and install WireGuard"
    echo "----------------------------------------"
    echo "Run these commands:"
    echo ""
    echo "  ssh ${PI_USER}@${PI_IP}"
    echo "  cd /tmp"
    echo "  curl -O https://raw.githubusercontent.com/raolivei/raolivei/main/pi-fleet/clusters/eldertree/infrastructure/wireguard/install-wireguard.sh"
    echo "  chmod +x install-wireguard.sh"
    echo "  sudo ./install-wireguard.sh"
    echo ""
    echo "Step 2: Note the server public key and public IP"
    echo "-------------------------------------------------"
    echo "After installation, run on Pi:"
    echo "  sudo cat /etc/wireguard/server_public.key"
    echo "  curl ifconfig.me"
    echo ""
    echo "Step 3: Generate client configs"
    echo "--------------------------------"
    echo "Back on your Mac:"
    echo "  cd ${SCRIPT_DIR}"
    echo "  ./generate-client.sh mac"
    echo "  ./generate-client.sh mobile"
    echo ""
    echo "See INSTALL_NOW.md for complete instructions"
fi

