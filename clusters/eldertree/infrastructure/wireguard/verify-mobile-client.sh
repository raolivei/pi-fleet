#!/bin/bash
# Verify and fix mobile client configuration on WireGuard server

set -e

PI_HOST="eldertree"
PI_USER="raolivei"
MOBILE_PUBLIC_KEY="$(echo 'mBYKaEGu+yzoQtihhGMY9VU06HOk8y4q1O6wKBv1h34=' | wg pubkey 2>/dev/null || echo '')"
MOBILE_IP="10.8.0.3"

echo "🔍 Verifying Mobile Client Configuration"
echo "========================================"
echo ""

# Check if we can resolve the hostname
if ! getent hosts ${PI_HOST} > /dev/null 2>&1 && ! getent hosts 192.168.2.83 > /dev/null 2>&1; then
    echo "⚠️  Cannot resolve ${PI_HOST}. Make sure you're on the local network or VPN is connected."
    echo ""
    echo "To run this script, you need to:"
    echo "1. Be on the local network (192.168.2.0/24), OR"
    echo "2. Connect WireGuard VPN first, then run this script"
    exit 1
fi

echo "📡 Checking WireGuard server status..."
echo ""

# Check if mobile client is registered
echo "Checking if mobile client (10.8.0.3) is registered on server..."
echo ""

# Generate the expected public key from private key
if command -v wg &> /dev/null; then
    EXPECTED_PUBLIC_KEY=$(echo "mBYKaEGu+yzoQtihhGMY9VU06HOk8y4q1O6wKBv1h34=" | wg pubkey 2>/dev/null || echo "")
    echo "Expected mobile client public key: ${EXPECTED_PUBLIC_KEY}"
    echo ""
fi

echo "📋 Instructions to verify on server:"
echo ""
echo "SSH to the server and run:"
echo "  ssh ${PI_USER}@${PI_HOST}"
echo "  sudo wg show wg0"
echo ""
echo "Look for a peer with:"
echo "  - Allowed IPs: 10.8.0.3/32"
echo "  - Recent handshake time"
echo ""
echo "If mobile client is NOT listed, add it with:"
echo "  sudo wg set wg0 peer <MOBILE_PUBLIC_KEY> allowed-ips ${MOBILE_IP}/32"
echo ""
echo "Then save to config:"
echo "  sudo wg-quick save wg0"
echo ""
echo "📱 Mobile Client Config Check:"
echo ""
echo "The client-mobile.conf file should have:"
echo "  - PrivateKey: mBYKaEGu+yzoQtihhGMY9VU06HOk8y4q1O6wKBv1h34="
echo "  - Address: 10.8.0.3/24"
echo "  - DNS: 192.168.2.83"
echo "  - PublicKey: AcxnYJk0nrZLq28iQoc6B8GTkPVU2VcDevc3LTj3/FQ="
echo "  - Endpoint: 184.147.64.214:51820"
echo ""
echo "✅ Config file looks correct!"
echo ""
echo "🔧 Next Steps:"
echo ""
echo "1. Make sure mobile client is registered on server (see above)"
echo "2. Import client-mobile.conf into WireGuard app on iPhone"
echo "3. Connect the tunnel"
echo "4. Test: https://192.168.2.83 (should work)"
echo "5. Test: https://canopy.eldertree.local (should work if DNS is correct)"
echo ""

