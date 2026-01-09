#!/bin/bash
# Script to diagnose Pi-hole DNS issues on Mac
# Run this when DNS (192.168.2.201) is not working

set -e

echo "=== Pi-hole DNS Diagnostic Script for Mac ==="
echo ""
echo "This script will help diagnose why Pi-hole DNS (192.168.2.201) is not working"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: Network connectivity to Pi-hole IP
echo "1. Testing network connectivity to 192.168.2.201..."
if ping -c 3 -W 2000 192.168.2.201 > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Pi-hole IP (192.168.2.201) is reachable"
else
    echo -e "${RED}✗${NC} Pi-hole IP (192.168.2.201) is NOT reachable"
    echo "   This is likely the root cause - MetalLB may not be advertising the IP"
    echo "   Check MetalLB configuration and ensure it's advertising on wlan0"
fi
echo ""

# Check 2: DNS port accessibility
echo "2. Testing DNS port (53) accessibility..."
if nc -z -v -w 2 192.168.2.201 53 2>&1 | grep -q "succeeded"; then
    echo -e "${GREEN}✓${NC} DNS port (53) is accessible"
else
    echo -e "${RED}✗${NC} DNS port (53) is NOT accessible"
    echo "   Pi-hole service may not be running or port is blocked"
fi
echo ""

# Check 3: Direct DNS query test
echo "3. Testing direct DNS query to Pi-hole..."
if dig @192.168.2.201 google.com +time=2 +tries=1 +short > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} DNS queries work when querying Pi-hole directly"
    DNS_WORKS_DIRECT=true
else
    echo -e "${RED}✗${NC} DNS queries fail when querying Pi-hole directly"
    echo "   Error details:"
    dig @192.168.2.201 google.com +time=2 +tries=1 2>&1 | tail -5
    DNS_WORKS_DIRECT=false
fi
echo ""

# Check 4: Current DNS configuration
echo "4. Checking current DNS configuration on Mac..."
CURRENT_DNS=$(scutil --dns | grep "nameserver\[0\]" | head -1 | awk '{print $3}')
echo "   Current DNS servers:"
scutil --dns | grep "nameserver\[" | head -5 | while read line; do
    DNS_IP=$(echo "$line" | awk '{print $3}')
    echo "   - $DNS_IP"
done
echo ""

# Check 5: macOS DNS cache
echo "5. Checking macOS DNS cache status..."
echo "   Current DNS cache entries for google.com:"
dscacheutil -q host -a name google.com 2>&1 | head -10 || echo "   No cached entries"
echo ""

# Check 6: Network interface configuration
echo "6. Checking network interface configuration..."
ACTIVE_INTERFACE=$(route get default | grep interface | awk '{print $2}')
echo "   Active network interface: $ACTIVE_INTERFACE"
echo "   IP address: $(ipconfig getifaddr $ACTIVE_INTERFACE 2>/dev/null || echo 'N/A')"
echo "   Subnet: $(ipconfig getoption $ACTIVE_INTERFACE subnet_mask 2>/dev/null || echo 'N/A')"
echo ""

# Check 7: Router/Gateway connectivity
echo "7. Checking router/gateway connectivity..."
GATEWAY=$(route -n get default | grep gateway | awk '{print $2}')
if [ -n "$GATEWAY" ]; then
    echo "   Gateway: $GATEWAY"
    if ping -c 1 -W 1000 $GATEWAY > /dev/null 2>&1; then
        echo -e "   ${GREEN}✓${NC} Gateway is reachable"
    else
        echo -e "   ${RED}✗${NC} Gateway is NOT reachable"
    fi
fi
echo ""

# Check 8: Test with fallback DNS
echo "8. Testing with fallback DNS (8.8.8.8) for comparison..."
if dig @8.8.8.8 google.com +time=2 +tries=1 +short > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Fallback DNS (8.8.8.8) works"
    echo "   This confirms your network connection is fine"
else
    echo -e "${RED}✗${NC} Fallback DNS (8.8.8.8) also fails"
    echo "   This suggests a broader network issue"
fi
echo ""

# Summary and recommendations
echo "=== DIAGNOSIS SUMMARY ==="
echo ""

if [ "$DNS_WORKS_DIRECT" = "true" ]; then
    echo -e "${GREEN}Pi-hole DNS service is working, but macOS may not be using it correctly.${NC}"
    echo ""
    echo "Possible issues:"
    echo "1. macOS DNS cache may be stale - try flushing it:"
    echo "   sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
    echo ""
    echo "2. DNS may be configured at router level - check router DNS settings"
    echo ""
    echo "3. Try setting DNS manually:"
    echo "   System Settings > Network > [Your Connection] > Details > DNS"
    echo "   Add: 192.168.2.201"
    echo "   Remove other DNS servers temporarily to test"
else
    echo -e "${RED}Pi-hole DNS service is NOT working.${NC}"
    echo ""
    echo "Root causes to check:"
    echo "1. MetalLB may not be advertising the LoadBalancer IP"
    echo "   - Check: kubectl get svc -n pihole"
    echo "   - Check: kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker"
    echo ""
    echo "2. Pi-hole pod may not be running"
    echo "   - Check: kubectl get pods -n pihole"
    echo "   - Check: kubectl logs -n pihole -l app=pihole"
    echo ""
    echo "3. Network routing issue"
    echo "   - Ensure your Mac is on the same network (192.168.2.0/24)"
    echo "   - Check firewall rules"
    echo ""
    echo "4. MetalLB interface configuration"
    echo "   - Verify MetalLB is configured to advertise on wlan0"
    echo "   - Check: kubectl get l2advertisement -n metallb-system default -o yaml"
fi

echo ""
echo "=== Next Steps ==="
echo ""
echo "If Pi-hole IP is not reachable, run these commands on a machine with cluster access:"
echo ""
echo "  export KUBECONFIG=~/.kube/config-eldertree"
echo "  kubectl get svc -n pihole"
echo "  kubectl get pods -n pihole"
echo "  kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker --tail=50"
echo ""
echo "To fix MetalLB advertisement:"
echo "  kubectl apply -f clusters/eldertree/core-infrastructure/metallb/config.yaml"
echo "  kubectl rollout restart daemonset -n metallb-system metallb-speaker"
echo ""


