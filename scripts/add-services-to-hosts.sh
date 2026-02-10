#!/bin/bash

# Script to add all eldertree cluster services to /etc/hosts
# Uses Pi-hole DNS IP (192.168.2.201) as per NETWORK.md documentation

set -e

# MetalLB LoadBalancer IP (192.168.2.200) doesn't work due to Wi-Fi ARP isolation
# Using node-1 IP directly as workaround - traffic will route via NodePort
INGRESS_IP="192.168.2.101"  # node-1 IP (control plane)
HOSTS_FILE="/etc/hosts"
BACKUP_FILE="/etc/hosts.backup.$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Adding eldertree cluster services to /etc/hosts${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Backup current /etc/hosts
echo -e "${YELLOW}Creating backup: ${BACKUP_FILE}${NC}"
cp "$HOSTS_FILE" "$BACKUP_FILE"
echo ""

# Check if entries already exist
if grep -q "# Eldertree Cluster Services" "$HOSTS_FILE"; then
    echo -e "${YELLOW}Eldertree entries already exist in /etc/hosts${NC}"
    echo -e "${YELLOW}Removing old entries...${NC}"
    # Remove old eldertree entries (from "# Eldertree" to end of block or next section)
    sed -i.bak '/^# Eldertree Cluster Services/,/^# End Eldertree Cluster Services/d' "$HOSTS_FILE"
    rm -f "$HOSTS_FILE.bak"
fi

# Services to add
cat >> "$HOSTS_FILE" << EOF

# Eldertree Cluster Services
# Added automatically by add-services-to-hosts.sh
# Control Plane IP: $INGRESS_IP
# Last Updated: $(date)

# Infrastructure Services
$INGRESS_IP  vault.eldertree.local
$INGRESS_IP  grafana.eldertree.local
$INGRESS_IP  prometheus.eldertree.local
$INGRESS_IP  pihole.eldertree.local
$INGRESS_IP  flux.eldertree.local
$INGRESS_IP  docs.eldertree.local

# Applications
$INGRESS_IP  canopy.eldertree.local
$INGRESS_IP  swimto.eldertree.local
$INGRESS_IP  journey.eldertree.local
$INGRESS_IP  nima.eldertree.local

# Pitanga Services
$INGRESS_IP  pitanga.eldertree.local

# Cluster Nodes
$INGRESS_IP  node-1.eldertree.local
192.168.2.102  node-2.eldertree.local
192.168.2.103  node-3.eldertree.local

# End Eldertree Cluster Services
EOF

echo -e "${GREEN}✅ Successfully added all services to /etc/hosts${NC}"
echo ""
echo "Added services:"
echo "  - vault.eldertree.local"
echo "  - grafana.eldertree.local"
echo "  - prometheus.eldertree.local"
echo "  - pihole.eldertree.local"
echo "  - flux.eldertree.local"
echo "  - docs.eldertree.local"
echo "  - canopy.eldertree.local"
echo "  - swimto.eldertree.local"
echo "  - journey.eldertree.local"
echo "  - nima.eldertree.local"
echo "  - pitanga.eldertree.local"
echo "  - node-1.eldertree.local"
echo "  - node-2.eldertree.local"
echo "  - node-3.eldertree.local"
echo ""
echo -e "${YELLOW}Backup saved to: ${BACKUP_FILE}${NC}"
echo ""
echo "Test access (via NodePort):"
echo "  curl -k https://192.168.2.101:32474 -H 'Host: vault.eldertree.local'"
echo "  curl -k https://192.168.2.101:32474 -H 'Host: grafana.eldertree.local'"
echo ""
echo -e "${YELLOW}⚠️  Note: Direct HTTPS (port 443) access doesn't work due to Wi-Fi client isolation.${NC}"
echo -e "${YELLOW}   Use NodePort 32474 for HTTPS or 31801 for HTTP.${NC}"
echo -e "${YELLOW}   To fix: Disable 'AP Isolation' or 'Client Isolation' on your router.${NC}"
