#!/bin/bash

# Script to test if MetalLB LoadBalancer IP is accessible
# This helps verify if AP Isolation has been disabled on the router

set -e

METALLB_IP="192.168.2.200"
TEST_HOST="vault.eldertree.local"
NODEPORT_HTTPS="32474"
NODEPORT_HTTP="31801"
NODE_IP="192.168.2.101"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MetalLB Connectivity Test ===${NC}"
echo ""

# Check if running as root (needed for arp command)
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Note: Some tests require root. Run with sudo for full results.${NC}"
    echo ""
fi

# Test 1: Check ARP entry
echo -e "${BLUE}[1/4] Checking ARP entry for ${METALLB_IP}...${NC}"
ARP_RESULT=$(arp -a | grep "$METALLB_IP" || echo "")
if [ -z "$ARP_RESULT" ]; then
    echo -e "${RED}❌ No ARP entry found${NC}"
    ARP_STATUS="missing"
elif echo "$ARP_RESULT" | grep -q "incomplete"; then
    echo -e "${YELLOW}⚠️  ARP entry exists but is incomplete (AP Isolation likely enabled)${NC}"
    echo "   Entry: $ARP_RESULT"
    ARP_STATUS="incomplete"
else
    MAC=$(echo "$ARP_RESULT" | grep -oE 'at [0-9a-f:]+' | cut -d' ' -f2)
    echo -e "${GREEN}✅ ARP entry found: ${MAC}${NC}"
    ARP_STATUS="complete"
fi
echo ""

# Test 2: Ping test
echo -e "${BLUE}[2/4] Testing ping to ${METALLB_IP}...${NC}"
if ping -c 2 -W 2 "$METALLB_IP" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ping successful${NC}"
    PING_STATUS="success"
else
    echo -e "${RED}❌ Ping failed${NC}"
    PING_STATUS="failed"
fi
echo ""

# Test 3: HTTPS access via LoadBalancer IP
echo -e "${BLUE}[3/4] Testing HTTPS access via LoadBalancer IP...${NC}"
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" -m 5 --connect-timeout 3 \
    "https://${METALLB_IP}" -H "Host: ${TEST_HOST}" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "000" ]; then
    echo -e "${RED}❌ Connection failed or timed out${NC}"
    LB_STATUS="failed"
elif [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
    echo -e "${GREEN}✅ HTTPS access successful (HTTP ${HTTP_CODE})${NC}"
    LB_STATUS="success"
else
    echo -e "${YELLOW}⚠️  Got HTTP ${HTTP_CODE} (may be working but unexpected)${NC}"
    LB_STATUS="partial"
fi
echo ""

# Test 4: NodePort access (should always work)
echo -e "${BLUE}[4/4] Testing NodePort access (fallback)...${NC}"
NODEPORT_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" -m 5 --connect-timeout 3 \
    "https://${NODE_IP}:${NODEPORT_HTTPS}" -H "Host: ${TEST_HOST}" 2>/dev/null || echo "000")
if [ "$NODEPORT_CODE" -ge 200 ] && [ "$NODEPORT_CODE" -lt 400 ]; then
    echo -e "${GREEN}✅ NodePort access successful (HTTP ${NODEPORT_CODE})${NC}"
    NODEPORT_STATUS="success"
else
    echo -e "${RED}❌ NodePort access failed${NC}"
    NODEPORT_STATUS="failed"
fi
echo ""

# Summary
echo -e "${BLUE}=== Test Summary ===${NC}"
echo ""
echo "ARP Entry:        $ARP_STATUS"
echo "Ping:             $PING_STATUS"
echo "LoadBalancer IP:  $LB_STATUS"
echo "NodePort:         $NODEPORT_STATUS"
echo ""

# Recommendations
if [ "$ARP_STATUS" = "complete" ] && [ "$PING_STATUS" = "success" ] && [ "$LB_STATUS" = "success" ]; then
    echo -e "${GREEN}✅ SUCCESS: AP Isolation appears to be disabled!${NC}"
    echo -e "${GREEN}   MetalLB LoadBalancer IP is fully accessible.${NC}"
    echo ""
    echo "You can now access services directly:"
    echo "  curl -k https://vault.eldertree.local"
    echo "  curl -k https://grafana.eldertree.local"
elif [ "$NODEPORT_STATUS" = "success" ]; then
    echo -e "${YELLOW}⚠️  AP Isolation is likely still enabled.${NC}"
    echo -e "${YELLOW}   LoadBalancer IP not accessible, but NodePort works.${NC}"
    echo ""
    echo "To fix:"
    echo "  1. Access router: http://192.168.2.1"
    echo "  2. Find 'AP Isolation' or 'Client Isolation' setting"
    echo "  3. Disable it"
    echo "  4. See: scripts/disable-ap-isolation-guide.md"
    echo ""
    echo "Current workaround (NodePort):"
    echo "  curl -k https://${NODE_IP}:${NODEPORT_HTTPS} -H 'Host: vault.eldertree.local'"
else
    echo -e "${RED}❌ ERROR: Both LoadBalancer and NodePort access failed!${NC}"
    echo "   This indicates a different problem. Check:"
    echo "   - Is the cluster running? (kubectl get nodes)"
    echo "   - Is MetalLB running? (kubectl get pods -n metallb-system)"
    echo "   - Is Traefik running? (kubectl get pods -n kube-system | grep traefik)"
fi
echo ""
