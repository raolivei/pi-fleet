#!/bin/bash
# Configure macOS to use Pi-hole DNS server for automatic *.eldertree.local resolution

set -e

PIHOLE_DNS="${PIHOLE_DNS:-192.168.2.83}"
PIHOLE_PORT="${PIHOLE_PORT:-30053}"

echo "🔧 Configuring macOS DNS to use Pi-hole"
echo ""

# Get the active network service (usually Wi-Fi or Ethernet)
ACTIVE_SERVICE=$(networksetup -listallnetworkservices | grep -E "Wi-Fi|Ethernet|USB" | head -1)

if [ -z "$ACTIVE_SERVICE" ]; then
    echo "❌ Error: Could not find active network service"
    echo "   Available services:"
    networksetup -listallnetworkservices
    exit 1
fi

echo "📡 Active network service: $ACTIVE_SERVICE"
echo ""

# Get current DNS servers
echo "Current DNS servers:"
networksetup -getdnsservers "$ACTIVE_SERVICE"
echo ""

# Check if Pi-hole DNS is already configured
CURRENT_DNS=$(networksetup -getdnsservers "$ACTIVE_SERVICE" 2>/dev/null | grep -c "$PIHOLE_DNS" || echo "0")

if [ "$CURRENT_DNS" -gt 0 ]; then
    echo "✅ Pi-hole DNS ($PIHOLE_DNS) is already configured"
else
    echo "➕ Adding Pi-hole DNS server..."
    # macOS doesn't support port numbers in DNS settings, so we'll use the IP
    # The NodePort 30053 is for external access, but internally we use the service IP
    # For macOS, we need to use the cluster IP or configure via router
    echo ""
    echo "⚠️  Note: macOS System Settings doesn't support DNS port numbers."
    echo "   You have two options:"
    echo ""
    echo "   Option 1: Configure via Router (Recommended)"
    echo "   - Set your router's DNS to: $PIHOLE_DNS:$PIHOLE_PORT"
    echo "   - All devices will automatically use Pi-hole"
    echo ""
    echo "   Option 2: Use /etc/hosts (Current method)"
    echo "   - Keep using /etc/hosts entries (already configured)"
    echo ""
    echo "   Option 3: Use Pi-hole Service IP (if accessible)"
    echo "   - We'll add the Pi-hole IP as primary DNS"
    echo ""
    
    read -p "Add Pi-hole IP ($PIHOLE_DNS) as DNS server? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Set DNS servers (Pi-hole first, then system defaults)
        networksetup -setdnsservers "$ACTIVE_SERVICE" "$PIHOLE_DNS" 8.8.8.8 1.1.1.1
        echo "✅ DNS configured: $PIHOLE_DNS (primary), 8.8.8.8, 1.1.1.1 (fallback)"
    else
        echo "⏭️  Skipping DNS configuration"
        echo "   Using /etc/hosts method instead"
    fi
fi

echo ""
echo "🧪 Testing DNS resolution..."
echo ""

# Test DNS resolution
for domain in canopy.eldertree.local vault.eldertree.local pihole.eldertree.local; do
    if nslookup "$domain" "$PIHOLE_DNS" >/dev/null 2>&1; then
        echo "✅ $domain resolves via Pi-hole"
    else
        echo "⚠️  $domain - testing with system DNS..."
        if ping -c 1 -W 1000 "$domain" >/dev/null 2>&1; then
            echo "✅ $domain resolves via system DNS (/etc/hosts)"
        else
            echo "❌ $domain - not resolving"
        fi
    fi
done

echo ""
echo "📋 Summary:"
echo "   - Pi-hole DNS: $PIHOLE_DNS:$PIHOLE_PORT"
echo "   - Active service: $ACTIVE_SERVICE"
echo ""
echo "🌐 Accessible URLs:"
echo "   - https://canopy.eldertree.local"
echo "   - https://grafana.eldertree.local"
echo "   - https://prometheus.eldertree.local"
echo "   - https://vault.eldertree.local"
echo "   - https://pihole.eldertree.local"
echo ""

