#!/bin/bash
# Install DNS Forwarding on WireGuard Server
# Run this from your Mac - it will SSH to the server and set up DNS forwarding

set -e

PI_HOST="eldertree"
PI_IP="192.168.2.83"
PI_USER="raolivei"
SCRIPT_NAME="setup-dns-forwarding.sh"

echo "🔧 Installing DNS Forwarding on WireGuard Server"
echo "================================================"
echo ""

# Check if script exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="${SCRIPT_DIR}/${SCRIPT_NAME}"

if [ ! -f "$SETUP_SCRIPT" ]; then
    echo "❌ Script not found: $SETUP_SCRIPT"
    exit 1
fi

echo "📋 Configuration:"
echo "  Server: ${PI_USER}@${PI_HOST} (${PI_IP})"
echo "  Script: ${SETUP_SCRIPT}"
echo ""

# Try to resolve hostname, fallback to IP
if getent hosts ${PI_HOST} > /dev/null 2>&1; then
    SERVER="${PI_USER}@${PI_HOST}"
elif ping -c 1 ${PI_IP} > /dev/null 2>&1; then
    SERVER="${PI_USER}@${PI_IP}"
else
    echo "❌ Cannot reach server at ${PI_HOST} or ${PI_IP}"
    echo "   Make sure you're on the local network or VPN is connected"
    exit 1
fi

echo "📡 Copying script to server..."
scp "${SETUP_SCRIPT}" ${SERVER}:/tmp/${SCRIPT_NAME}

if [ $? -ne 0 ]; then
    echo "❌ Failed to copy script. Check SSH connection."
    echo ""
    echo "Try manually:"
    echo "  scp ${SETUP_SCRIPT} ${SERVER}:/tmp/"
    exit 1
fi

echo "✅ Script copied"
echo ""

echo "🚀 Running setup script on server..."
echo "   (You may be prompted for password)"
echo ""

ssh -t ${SERVER} "sudo bash /tmp/${SCRIPT_NAME}"

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 DNS forwarding setup complete!"
    echo ""
    echo "📱 Next steps:"
    echo "  1. Update WireGuard config on iPhone: DNS = 10.8.0.1"
    echo "  2. Re-import client-mobile.conf or update DNS in WireGuard app"
    echo "  3. Disconnect and reconnect WireGuard tunnel"
    echo "  4. Test: https://canopy.eldertree.local"
else
    echo ""
    echo "❌ Setup failed. Check the error messages above."
    exit 1
fi


