#!/bin/bash
# Verification script for WireGuard split-tunnel setup
# Run this on the CLIENT after connecting to WireGuard

set -e

echo "=== WireGuard Split-Tunnel Verification ==="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if WireGuard interface exists
echo "1️⃣ Checking WireGuard interface..."
if ip link show wg0 &> /dev/null; then
    echo -e "${GREEN}✅ WireGuard interface (wg0) exists${NC}"
else
    echo -e "${RED}❌ WireGuard interface (wg0) not found${NC}"
    echo "   Connect to WireGuard first"
    exit 1
fi

# Check WireGuard connection
echo ""
echo "2️⃣ Checking WireGuard connection..."
if command -v wg &> /dev/null; then
    WG_OUTPUT=$(sudo wg show 2>/dev/null || echo "error")
    if [[ "$WG_OUTPUT" != "error" ]] && [[ -n "$WG_OUTPUT" ]]; then
        echo -e "${GREEN}✅ WireGuard connected${NC}"
        echo "$WG_OUTPUT" | head -5
    else
        echo -e "${RED}❌ WireGuard not connected${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  'wg' command not available, skipping${NC}"
fi

# Verify split-tunnel (default route should NOT be through VPN)
echo ""
echo "3️⃣ Verifying split-tunnel configuration..."
DEFAULT_ROUTE=$(ip route | grep default | head -1)
if echo "$DEFAULT_ROUTE" | grep -q "wg0"; then
    echo -e "${RED}❌ Default route goes through VPN (NOT split-tunnel)${NC}"
    echo "   $DEFAULT_ROUTE"
    echo ""
    echo "   Your AllowedIPs in client config should NOT include 0.0.0.0/0"
else
    echo -e "${GREEN}✅ Default route bypasses VPN (split-tunnel working)${NC}"
    echo "   $DEFAULT_ROUTE"
fi

# Check routes to cluster networks
echo ""
echo "4️⃣ Checking routes to cluster networks..."

for NETWORK in "10.8.0.0/24" "10.42.0.0/16" "10.43.0.0/16"; do
    if ip route get ${NETWORK%/*} 2>/dev/null | grep -q "wg0"; then
        echo -e "${GREEN}✅ $NETWORK routes through wg0${NC}"
    else
        echo -e "${RED}❌ $NETWORK does NOT route through wg0${NC}"
    fi
done

# Test internet connectivity (should bypass VPN)
echo ""
echo "5️⃣ Testing internet connectivity (should bypass VPN)..."
if curl -s --max-time 5 https://ifconfig.me > /dev/null; then
    PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me)
    echo -e "${GREEN}✅ Internet working${NC}"
    echo "   Your public IP: $PUBLIC_IP"
    echo "   (This should NOT be the VPN server IP)"
else
    echo -e "${RED}❌ Internet not working${NC}"
fi

# Test VPN tunnel connectivity
echo ""
echo "6️⃣ Testing VPN tunnel connectivity..."
if ping -c 2 -W 2 10.8.0.1 &> /dev/null; then
    echo -e "${GREEN}✅ Can ping WireGuard server (10.8.0.1)${NC}"
else
    echo -e "${RED}❌ Cannot ping WireGuard server (10.8.0.1)${NC}"
fi

# Test DNS resolution
echo ""
echo "7️⃣ Testing DNS resolution..."

# Check if dig is available
if ! command -v dig &> /dev/null; then
    echo -e "${YELLOW}⚠️  'dig' not found, install dnsutils/bind-tools${NC}"
else
    # Test cluster.local resolution
    echo "   Testing kubernetes.default.svc.cluster.local..."
    if dig @10.8.0.1 kubernetes.default.svc.cluster.local +short +time=2 &> /dev/null; then
        RESULT=$(dig @10.8.0.1 kubernetes.default.svc.cluster.local +short +time=2 | head -1)
        if [ -n "$RESULT" ]; then
            echo -e "${GREEN}✅ cluster.local DNS working${NC}"
            echo "   Resolved to: $RESULT"
        else
            echo -e "${RED}❌ cluster.local DNS not resolving${NC}"
        fi
    else
        echo -e "${RED}❌ Cannot query DNS server${NC}"
    fi
    
    # Test internet DNS (should work)
    echo ""
    echo "   Testing google.com (internet DNS)..."
    if dig google.com +short +time=2 | grep -q .; then
        echo -e "${GREEN}✅ Internet DNS working${NC}"
    else
        echo -e "${RED}❌ Internet DNS not working${NC}"
    fi
fi

# Test k3s service access
echo ""
echo "8️⃣ Testing k3s service access..."
echo "   Enter a k3s service IP to test (e.g., 10.43.0.1 for kubernetes API)"
read -p "   Service IP (or press Enter to skip): " SERVICE_IP

if [ -n "$SERVICE_IP" ]; then
    if ping -c 2 -W 2 "$SERVICE_IP" &> /dev/null; then
        echo -e "${GREEN}✅ Can ping $SERVICE_IP${NC}"
    else
        echo -e "${RED}❌ Cannot ping $SERVICE_IP${NC}"
        echo "   (Note: Some services may not respond to ping)"
    fi
fi

echo ""
echo "=== Verification Complete ==="
echo ""
echo "📋 Summary:"
echo "- WireGuard should be connected"
echo "- Default route should bypass VPN (split-tunnel)"
echo "- Cluster networks (10.42.x, 10.43.x) should route through VPN"
echo "- Internet should work normally"
echo "- cluster.local DNS should resolve"
echo ""
echo "🔧 Troubleshooting commands:"
echo "  ip route                    # Show all routes"
echo "  ip route get 8.8.8.8        # Show internet route"
echo "  ip route get 10.43.0.1      # Show cluster route"
echo "  sudo wg show                # Show WireGuard status"
echo "  dig @10.8.0.1 <domain>      # Test DNS"
echo ""

