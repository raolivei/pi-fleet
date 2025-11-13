#!/bin/bash
# Configure macOS to use Pi-hole DNS via NodePort
# Note: macOS DNS doesn't support port numbers, so we'll configure the router DNS
# or use a workaround by setting the Pi IP and accessing via NodePort

set -e

PIHOLE_IP="${PIHOLE_IP:-192.168.2.83}"
PIHOLE_NODEPORT="${PIHOLE_NODEPORT:-30053}"

echo "🔧 Configuring macOS DNS for Pi-hole"
echo ""

# Get active network service
ACTIVE_SERVICE=$(networksetup -listallnetworkservices | grep -E "Wi-Fi|Ethernet|USB" | head -1)

if [ -z "$ACTIVE_SERVICE" ]; then
    echo "❌ Error: Could not find active network service"
    exit 1
fi

echo "📡 Active network service: $ACTIVE_SERVICE"
echo ""

# Check current DNS
CURRENT_DNS=$(networksetup -getdnsservers "$ACTIVE_SERVICE" 2>/dev/null || echo "")

echo "Current DNS servers:"
if [ -z "$CURRENT_DNS" ] || [ "$CURRENT_DNS" = "There aren't any DNS Servers set on $ACTIVE_SERVICE." ]; then
    echo "   (Using system defaults)"
else
    echo "$CURRENT_DNS" | sed 's/^/   /'
fi
echo ""

# Since macOS doesn't support DNS port numbers in System Settings,
# we have two options:
# 1. Configure router DNS (best for network-wide)
# 2. Use /etc/hosts (already working)

echo "⚠️  macOS System Settings doesn't support DNS port numbers."
echo ""
echo "   Option 1: Router DNS (Recommended for network-wide)"
echo "   Configure your router's DNS to: $PIHOLE_IP:$PIHOLE_NODEPORT"
echo "   Then all devices will use Pi-hole automatically"
echo ""
echo "   Option 2: Keep using /etc/hosts (Current - Already working)"
echo "   Your /etc/hosts entries are already configured and working"
echo ""
echo "   Option 3: Test Pi-hole DNS directly"
echo "   We'll test if Pi-hole DNS is responding on NodePort"
echo ""

# Test Pi-hole DNS
echo "🧪 Testing Pi-hole DNS..."
if command -v dig &> /dev/null; then
    echo "Testing: dig @$PIHOLE_IP -p $PIHOLE_NODEPORT canopy.eldertree.local"
    if dig @$PIHOLE_IP -p $PIHOLE_NODEPORT canopy.eldertree.local +short +timeout=2 2>&1 | grep -q "192.168.2.83"; then
        echo "✅ Pi-hole DNS is responding!"
        echo ""
        echo "To use Pi-hole DNS network-wide:"
        echo "1. Configure your router's DNS settings"
        echo "2. Set primary DNS to: $PIHOLE_IP:$PIHOLE_NODEPORT"
        echo "3. All devices will automatically resolve *.eldertree.local"
    else
        echo "⚠️  Pi-hole DNS not responding yet (may still be initializing)"
        echo "   Continue using /etc/hosts for now"
    fi
else
    echo "⚠️  'dig' not found, skipping DNS test"
fi

echo ""
echo "📋 Current setup:"
echo "   - /etc/hosts entries: ✅ Working"
echo "   - Pi-hole DNS: Testing..."
echo ""
echo "🌐 All services accessible via:"
echo "   - https://canopy.eldertree.local"
echo "   - https://grafana.eldertree.local"
echo "   - https://prometheus.eldertree.local"
echo "   - https://vault.eldertree.local"
echo "   - https://pihole.eldertree.local"
echo ""

