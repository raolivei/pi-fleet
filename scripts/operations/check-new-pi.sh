#!/bin/bash
set -e

# Script to check and verify new Raspberry Pi on the network
# Usage: ./check-new-pi.sh [new-pi-ip]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Raspberry Pi Network Check ===${NC}"
echo ""

# Known nodes
ELDERTREE_IP="192.168.2.83"
ELDERTREE_HOSTNAME="eldertree"
NETWORK="192.168.2.0/24"

# Check if new Pi IP provided
if [ -n "$1" ]; then
    NEW_PI_IP="$1"
    echo -e "${YELLOW}Checking provided IP: ${NEW_PI_IP}${NC}"
else
    echo -e "${YELLOW}Scanning network for Raspberry Pi devices...${NC}"
    echo ""
fi

# Function to check if device is a Raspberry Pi
check_pi() {
    local ip=$1
    echo -e "${BLUE}Checking ${ip}...${NC}"
    
    # Ping check
    if ! ping -c 1 -W 2 "$ip" &>/dev/null; then
        echo -e "  ${RED}✗ Not reachable${NC}"
        return 1
    fi
    
    # SSH check
    if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes pi@"$ip" "echo 'connected'" &>/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ SSH accessible (pi user)${NC}"
        USER="pi"
    elif ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes raolivei@"$ip" "echo 'connected'" &>/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ SSH accessible (raolivei user)${NC}"
        USER="raolivei"
    else
        echo -e "  ${YELLOW}⚠ SSH not accessible (may need password)${NC}"
        USER="unknown"
    fi
    
    # Get system info
    if [ "$USER" != "unknown" ]; then
        echo -e "  ${BLUE}System Information:${NC}"
        ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$USER@$ip" "
            echo -n '    Hostname: '; hostname
            echo -n '    IP Address: '; ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print \$2}' | head -1
            echo -n '    MAC Address: '; ip link show | grep -A1 'state UP' | grep 'link/ether' | awk '{print \$2}' | head -1
            echo -n '    OS: '; cat /etc/os-release | grep PRETTY_NAME | cut -d'\"' -f2
            echo -n '    Architecture: '; uname -m
            echo -n '    Model: '; cat /proc/device-tree/model 2>/dev/null || echo 'Unknown'
            echo -n '    Memory: '; free -h | grep Mem | awk '{print \$2}'
        " 2>/dev/null || echo -e "    ${RED}Could not retrieve system info${NC}"
    fi
    
    # Check if k3s is installed
    if [ "$USER" != "unknown" ]; then
        if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$USER@$ip" "which k3s &>/dev/null" 2>/dev/null; then
            echo -e "  ${YELLOW}⚠ k3s is already installed${NC}"
            ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$USER@$ip" "
                if systemctl is-active --quiet k3s; then
                    echo '    k3s service: Active'
                    k3s kubectl get nodes 2>/dev/null || echo '    k3s: Installed but not responding'
                else
                    echo '    k3s service: Inactive'
                fi
            " 2>/dev/null
        else
            echo -e "  ${GREEN}✓ k3s not installed (ready for setup)${NC}"
        fi
    fi
    
    echo ""
    return 0
}

# Check existing eldertree node
echo -e "${BLUE}=== Checking Existing Cluster Node ===${NC}"
check_pi "$ELDERTREE_IP"
echo ""

# Check cluster status if kubeconfig exists
if [ -f ~/.kube/config-eldertree ]; then
    echo -e "${BLUE}=== Cluster Status ===${NC}"
    export KUBECONFIG=~/.kube/config-eldertree
    kubectl get nodes 2>/dev/null || echo -e "${YELLOW}Cluster not accessible${NC}"
    echo ""
fi

# Check new Pi if IP provided
if [ -n "$NEW_PI_IP" ]; then
    echo -e "${BLUE}=== Checking New Raspberry Pi ===${NC}"
    check_pi "$NEW_PI_IP"
    
    if [ "$NEW_PI_IP" != "$ELDERTREE_IP" ]; then
        echo -e "${GREEN}=== Summary ===${NC}"
        echo "New Pi IP: $NEW_PI_IP"
        echo "Eldertree IP: $ELDERTREE_IP"
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "1. Update Ansible inventory: ansible/inventory/hosts.yml"
        echo "2. Run system setup: cd ansible && ansible-playbook playbooks/setup-system.yml"
        echo "3. Add as worker node: See README.md 'Add Worker Nodes' section"
    fi
else
    echo -e "${YELLOW}=== Network Scan ===${NC}"
    echo "Scanning $NETWORK for active devices..."
    echo ""
    echo -e "${YELLOW}To check a specific IP, run:${NC}"
    echo "  $0 <ip-address>"
    echo ""
    echo -e "${YELLOW}Or scan for SSH-accessible devices:${NC}"
    echo "  for ip in {1..254}; do"
    echo "    ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no pi@192.168.2.\$ip 'hostname' 2>/dev/null && echo \"192.168.2.\$ip - Pi found\""
    echo "  done"
fi

echo ""
echo -e "${BLUE}=== Switch Information ===${NC}"
echo "TP-Link SG105: 5-port Gigabit switch"
echo "Both Pis should be connected to this switch"
echo "Network: $NETWORK"
echo ""

