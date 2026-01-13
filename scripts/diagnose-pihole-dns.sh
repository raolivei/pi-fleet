#!/bin/bash
set -e

echo "=== Pi-hole DNS Diagnostic Script ==="
echo ""

# Check if Pi-hole IP is reachable
echo "1. Checking Pi-hole LoadBalancer IP (192.168.2.201)..."
if ping -c 2 -W 2 192.168.2.201 > /dev/null 2>&1; then
    echo "   ✅ Pi-hole IP is reachable"
else
    echo "   ❌ Pi-hole IP is NOT reachable"
    echo "   → MetalLB may not be advertising the IP"
    echo "   → Check MetalLB speaker logs on the Pi"
fi
echo ""

# Check ARP table
echo "2. Checking ARP table for 192.168.2.201..."
ARP_ENTRY=$(arp -a | grep "192.168.2.201" || echo "")
if [ -n "$ARP_ENTRY" ]; then
    echo "   ARP entry: $ARP_ENTRY"
    if echo "$ARP_ENTRY" | grep -q "incomplete"; then
        echo "   ⚠️  ARP entry is incomplete - MetalLB not responding"
    else
        echo "   ✅ ARP entry exists"
    fi
else
    echo "   ⚠️  No ARP entry found"
fi
echo ""

# Check current DNS configuration
echo "3. Current DNS configuration on macOS..."
DNS_SERVERS=$(scutil --dns | grep "nameserver\[0\]" | head -1 | awk '{print $3}')
echo "   Primary DNS: $DNS_SERVERS"
if [ "$DNS_SERVERS" = "192.168.2.201" ]; then
    echo "   ✅ Using Pi-hole as DNS"
elif [ "$DNS_SERVERS" = "192.168.2.1" ]; then
    echo "   ⚠️  Using router as DNS - router should forward to Pi-hole"
    echo "   → Configure router to use 192.168.2.201 as upstream DNS"
else
    echo "   ⚠️  Using $DNS_SERVERS as DNS"
fi
echo ""

# Test DNS queries
echo "4. Testing DNS resolution..."
echo "   Testing google.com..."
if nslookup google.com 192.168.2.201 > /dev/null 2>&1; then
    echo "   ✅ Pi-hole can resolve external domains"
else
    echo "   ❌ Pi-hole cannot resolve external domains (may be unreachable)"
fi

echo "   Testing grafana.eldertree.local..."
if nslookup grafana.eldertree.local 192.168.2.201 > /dev/null 2>&1; then
    echo "   ✅ grafana.eldertree.local resolves via Pi-hole"
    RESOLVED_IP=$(nslookup grafana.eldertree.local 192.168.2.201 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
    echo "   → Resolves to: $RESOLVED_IP"
else
    echo "   ❌ grafana.eldertree.local does NOT resolve via Pi-hole"
    echo "   → ExternalDNS may not have created the record"
    echo "   → Check ExternalDNS logs on the Pi"
fi
echo ""

# Summary and recommendations
echo "=== Recommendations ==="
echo ""
if ! ping -c 1 -W 1 192.168.2.201 > /dev/null 2>&1; then
    echo "🔴 CRITICAL: Pi-hole IP (192.168.2.201) is not reachable"
    echo "   Fix:"
    echo "   1. SSH to the Pi (192.168.2.101)"
    echo "   2. Check MetalLB: kubectl get pods -n metallb-system"
    echo "   3. Check MetalLB logs: kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker"
    echo "   4. Check Pi-hole service: kubectl get svc -n pihole pi-hole"
    echo "   5. Restart MetalLB if needed: kubectl rollout restart daemonset -n metallb-system metallb-speaker"
    echo ""
fi

if [ "$DNS_SERVERS" != "192.168.2.201" ]; then
    echo "⚠️  DNS is not pointing directly to Pi-hole"
    echo "   Options:"
    echo "   A. Configure router to use Pi-hole (192.168.2.201) as upstream DNS"
    echo "      → Router admin panel → DNS Settings → Set 192.168.2.201 as DNS"
    echo "   B. Configure router DHCP to hand out 192.168.2.201 as DNS to clients"
    echo "      → Router admin panel → DHCP Settings → DNS Server: 192.168.2.201"
    echo "   C. Configure macOS directly (may conflict with VPN):"
    echo "      → System Settings → Network → DNS → Add 192.168.2.201"
    echo ""
fi

echo "✅ Once Pi-hole is reachable and DNS is configured, test with:"
echo "   nslookup grafana.eldertree.local 192.168.2.201"
echo ""



