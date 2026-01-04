#!/bin/bash
# Emergency boot recovery script
# Monitors nodes and automatically applies boot reliability fixes when they come back online

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$PI_FLEET_DIR/ansible"
INVENTORY="$ANSIBLE_DIR/inventory/hosts.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Boot Recovery Script ===${NC}"
echo "This script will:"
echo "  1. Monitor all nodes until they come back online"
echo "  2. Automatically apply boot reliability fixes"
echo "  3. Verify the fixes were applied"
echo ""

# Function to check if node is reachable
check_node() {
    local node=$1
    local ip=$2
    
    if ping -c 1 -W 2 "$ip" &>/dev/null; then
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no raolivei@"$ip" "echo ok" &>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Function to apply fixes to a node
fix_node() {
    local node=$1
    echo -e "${GREEN}Applying boot reliability fixes to $node...${NC}"
    
    cd "$ANSIBLE_DIR" || exit 1
    
    if ansible-playbook playbooks/fix-boot-reliability.yml --limit "$node" -i "$INVENTORY"; then
        echo -e "${GREEN}✅ Fixes applied to $node${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to apply fixes to $node${NC}"
        return 1
    fi
}

# Get all nodes from inventory
NODES=$(ansible-inventory -i "$INVENTORY" --list 2>/dev/null | \
    grep -A 1 '"raspberry_pi"' | \
    grep '"hosts"' | \
    sed 's/.*\[\(.*\)\].*/\1/' | \
    tr ',' ' ' 2>/dev/null || echo "node-1 node-2 node-3")

echo "Monitoring nodes: $NODES"
echo ""

# Check current status
echo "Checking current node status..."
NODES_ONLINE=()
NODES_OFFLINE=()

for node in $NODES; do
    IP=$(ansible-inventory -i "$INVENTORY" --host "$node" 2>/dev/null | \
        grep ansible_host | awk '{print $2}' | tr -d '"' || echo "")
    
    if [ -z "$IP" ]; then
        # Fallback to known IPs
        case $node in
            node-1) IP="192.168.2.101" ;;
            node-2) IP="192.168.2.102" ;;
            node-3) IP="192.168.2.103" ;;
        esac
    fi
    
    if check_node "$node" "$IP"; then
        echo -e "${GREEN}✅ $node ($IP) is online${NC}"
        NODES_ONLINE+=("$node")
    else
        echo -e "${RED}❌ $node ($IP) is offline${NC}"
        NODES_OFFLINE+=("$node")
    fi
done

echo ""

# Fix online nodes immediately
if [ ${#NODES_ONLINE[@]} -gt 0 ]; then
    echo "Fixing online nodes..."
    for node in "${NODES_ONLINE[@]}"; do
        fix_node "$node"
    done
fi

# Monitor offline nodes
if [ ${#NODES_OFFLINE[@]} -gt 0 ]; then
    echo -e "${YELLOW}Waiting for offline nodes to come back online...${NC}"
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    MAX_WAIT=${1:-3600}  # Default 1 hour
    START_TIME=$(date +%s)
    
    while [ $(($(date +%s) - START_TIME)) -lt $MAX_WAIT ]; do
        for node in "${NODES_OFFLINE[@]}"; do
            IP=$(ansible-inventory -i "$INVENTORY" --host "$node" 2>/dev/null | \
                grep ansible_host | awk '{print $2}' | tr -d '"' || echo "")
            
            if [ -z "$IP" ]; then
                case $node in
                    node-1) IP="192.168.2.101" ;;
                    node-2) IP="192.168.2.102" ;;
                    node-3) IP="192.168.2.103" ;;
                esac
            fi
            
            if check_node "$node" "$IP"; then
                echo -e "${GREEN}$node came back online!${NC}"
                sleep 10  # Wait a bit for services to stabilize
                fix_node "$node"
                
                # Remove from offline list
                NODES_OFFLINE=("${NODES_OFFLINE[@]/$node}")
            fi
        done
        
        if [ ${#NODES_OFFLINE[@]} -eq 0 ]; then
            echo -e "${GREEN}All nodes are now online and fixed!${NC}"
            break
        fi
        
        sleep 10
        echo -n "."
    done
    
    if [ ${#NODES_OFFLINE[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}Timeout waiting for nodes: ${NODES_OFFLINE[*]}${NC}"
        echo "You may need to:"
        echo "  1. Physically power cycle the nodes"
        echo "  2. Check network connectivity"
        echo "  3. Run this script again when nodes are back"
    fi
fi

echo ""
echo -e "${GREEN}=== Recovery Complete ===${NC}"
echo "All accessible nodes have been fixed."
echo ""
echo "Next steps:"
echo "  1. Verify nodes are online: cd $ANSIBLE_DIR && ansible raspberry_pi -i inventory/hosts.yml -m ping"
echo "  2. Check cluster: export KUBECONFIG=~/.kube/config-eldertree && kubectl get nodes"
echo "  3. If nodes still don't boot, check boot logs on console"

