#!/bin/bash
set -e

# Complete WireGuard VPN Setup Script
# This script automates the entire VPN setup process

PI_HOST="eldertree"
PI_USER="raolivei"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔐 WireGuard VPN Complete Setup"
echo "================================"
echo ""

# Check if we can SSH to the Pi
echo "🔍 Checking SSH connection to ${PI_USER}@${PI_HOST}..."
if ! ssh -o ConnectTimeout=5 ${PI_USER}@${PI_HOST} "echo 'Connected'" &>/dev/null; then
    echo "❌ Cannot connect to ${PI_USER}@${PI_HOST}"
    echo "   Please ensure SSH access is configured"
    exit 1
fi
echo "✅ SSH connection OK"
echo ""

# Step 1: Install WireGuard on server
echo "📦 Step 1: Installing WireGuard on server..."
echo "   Copying installation script..."
scp "${SCRIPT_DIR}/install-wireguard.sh" ${PI_USER}@${PI_HOST}:/tmp/install-wireguard.sh

echo "   Running installation script..."
ssh ${PI_USER}@${PI_HOST} "sudo bash /tmp/install-wireguard.sh"

echo "✅ WireGuard installed on server"
echo ""

# Step 2: Generate client configs
echo "📱 Step 2: Generating client configurations..."

# Generate Mac client
if [ -f "${SCRIPT_DIR}/generate-client.sh" ]; then
    cd "${SCRIPT_DIR}"
    echo "   Generating Mac client config..."
    ./generate-client.sh mac
    
    echo "   Generating Mobile client config..."
    ./generate-client.sh mobile
    
    echo "✅ Client configurations generated"
else
    echo "⚠️  generate-client.sh not found. Please run manually:"
    echo "   cd ${SCRIPT_DIR}"
    echo "   ./generate-client.sh mac"
    echo "   ./generate-client.sh mobile"
fi

echo ""
echo "🎉 VPN setup complete!"
echo ""
echo "Next steps:"
echo ""
echo "1. Install WireGuard on your Mac:"
echo "   brew install wireguard-tools"
echo ""
echo "2. Copy Mac config and start VPN:"
echo "   sudo cp ${SCRIPT_DIR}/client-mac.conf /usr/local/etc/wireguard/wg0.conf"
echo "   sudo wg-quick up wg0"
echo ""
echo "3. Install WireGuard app on your phone and scan QR code:"
echo "   open ${SCRIPT_DIR}/client-mobile.png"
echo ""
echo "4. Test connection:"
echo "   ping 192.168.2.83"
echo "   kubectl get nodes"
echo ""

