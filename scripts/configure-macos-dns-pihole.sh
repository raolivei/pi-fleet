#!/bin/bash
# Configure macOS DNS to use Pi-hole (now exposed on port 53)

set -e

PIHOLE_IP="${PIHOLE_IP:-192.168.2.83}"

echo "🔧 Configuring macOS DNS to use Pi-hole"
echo ""

# Get active network service
ACTIVE_SERVICE=$(networksetup -listallnetworkservices | grep -E "Wi-Fi|Ethernet|USB" | head -1)

if [ -z "$ACTIVE_SERVICE" ]; then
    echo "❌ Error: Could not find active network service"
    exit 1
fi

echo "📡 Active network service: $ACTIVE_SERVICE"
echo ""

# Configure DNS
echo "➕ Setting DNS servers..."
sudo networksetup -setdnsservers "$ACTIVE_SERVICE" "$PIHOLE_IP" "8.8.8.8" "1.1.1.1"

echo "✅ DNS configured!"
echo ""
echo "Current DNS servers:"
networksetup -getdnsservers "$ACTIVE_SERVICE"
echo ""

# Flush DNS cache
echo "🔄 Flushing DNS cache..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
echo "✅ DNS cache flushed"
echo ""

# Test DNS resolution
echo "🧪 Testing DNS resolution..."
sleep 2

for domain in canopy.eldertree.local vault.eldertree.local pihole.eldertree.local grafana.eldertree.local prometheus.eldertree.local; do
    if nslookup "$domain" >/dev/null 2>&1; then
        IP=$(nslookup "$domain" 2>/dev/null | grep -A 1 "Name:" | tail -1 | awk '{print $2}')
        echo "✅ $domain -> $IP"
    else
        echo "❌ $domain - not resolving"
    fi
done

echo ""
echo "🌐 All services should now be accessible:"
echo "   - https://canopy.eldertree.local"
echo "   - https://grafana.eldertree.local"
echo "   - https://prometheus.eldertree.local"
echo "   - https://vault.eldertree.local"
echo "   - https://pihole.eldertree.local"
echo ""

