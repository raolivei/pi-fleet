#!/bin/bash
set -e

# Script to add a new Raspberry Pi as a worker node to the eldertree cluster
# Usage: ./add-worker-node.sh <worker-ip> <worker-hostname> [static-ip]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Add Worker Node to Eldertree Cluster ===${NC}"
echo ""

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Usage: $0 <worker-ip> <worker-hostname> [static-ip]${NC}"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.2.84 fleet-worker-01"
    echo "  $0 192.168.2.84 fleet-worker-01 192.168.2.84"
    echo ""
    exit 1
fi

WORKER_IP="$1"
WORKER_HOSTNAME="$2"
STATIC_IP="${3:-}"  # Optional static IP

# Validate hostname format
if [[ ! "$WORKER_HOSTNAME" =~ ^fleet-worker-[0-9]{2}$ ]]; then
    echo -e "${YELLOW}Warning: Hostname should follow pattern 'fleet-worker-01', 'fleet-worker-02', etc.${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${BLUE}Configuration:${NC}"
echo "  Worker IP: ${WORKER_IP}"
echo "  Hostname: ${WORKER_HOSTNAME}"
if [ -n "$STATIC_IP" ]; then
    echo "  Static IP: ${STATIC_IP}"
else
    echo "  Static IP: (DHCP)"
fi
echo ""

# Check prerequisites
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}❌ $1 not found${NC}"
        echo -e "${YELLOW}   Install with: $2${NC}"
        exit 1
    fi
}

check_command "ansible" "brew install ansible"
check_command "kubectl" "brew install kubectl"
check_command "sshpass" "brew install hudochenkov/sshpass/sshpass"

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# Test connectivity to worker
echo -e "${YELLOW}[2/6] Testing connectivity to worker node...${NC}"
if ! ping -c 1 -W 2 "$WORKER_IP" &>/dev/null; then
    echo -e "${RED}❌ Cannot reach ${WORKER_IP}${NC}"
    echo ""
    echo -e "${YELLOW}Possible issues:${NC}"
    echo "  1. Pi is not powered on"
    echo "  2. Pi is not connected to network/switch"
    echo "  3. OS is not installed on the Pi"
    echo ""
    echo -e "${YELLOW}Before adding a worker node, ensure:${NC}"
    echo "  - OS is installed using Raspberry Pi Imager"
    echo "  - SSH is enabled in Imager settings"
    echo "  - Pi is booted and connected to network"
    echo ""
    echo "See: docs/ADD_WORKER_NODE.md for complete setup guide"
    exit 1
fi
echo -e "${GREEN}✓ Worker node is reachable${NC}"
echo ""

# Check SSH access
echo -e "${YELLOW}[3/6] Checking SSH access...${NC}"
SSH_USER=""
if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes pi@"$WORKER_IP" "echo 'connected'" &>/dev/null 2>&1; then
    SSH_USER="pi"
    echo -e "${GREEN}✓ SSH accessible as 'pi' user${NC}"
elif ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes raolivei@"$WORKER_IP" "echo 'connected'" &>/dev/null 2>&1; then
    SSH_USER="raolivei"
    echo -e "${GREEN}✓ SSH accessible as 'raolivei' user${NC}"
else
    # Test if SSH port is open
    if timeout 2 nc -zv "$WORKER_IP" 22 &>/dev/null; then
        echo -e "${YELLOW}⚠ SSH port is open but requires password authentication${NC}"
        echo "You'll be prompted for the password during setup"
        SSH_USER="pi"
    else
        echo -e "${RED}❌ SSH is not accessible${NC}"
        echo ""
        echo -e "${YELLOW}Possible issues:${NC}"
        echo "  1. OS is not installed on the Pi"
        echo "  2. SSH was not enabled in Raspberry Pi Imager settings"
        echo "  3. Pi is still booting (wait 1-2 minutes and try again)"
        echo ""
        echo -e "${YELLOW}To fix:${NC}"
        echo "  1. Install OS using Raspberry Pi Imager"
        echo "  2. Make sure 'Enable SSH' is checked in Imager settings"
        echo "  3. Boot the Pi and wait for it to fully start"
        echo ""
        echo "See: docs/ADD_WORKER_NODE.md for complete setup guide"
        exit 1
    fi
fi
echo ""

# Get k3s token from control plane
echo -e "${YELLOW}[4/6] Retrieving k3s node token from control plane...${NC}"
K3S_TOKEN_FILE="${ANSIBLE_DIR}/k3s-node-token"

if [ ! -f "$K3S_TOKEN_FILE" ]; then
    echo "Fetching token from eldertree..."
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no raolivei@192.168.2.83 \
        "cat /var/lib/rancher/k3s/server/node-token" > "$K3S_TOKEN_FILE" 2>/dev/null || {
        echo -e "${RED}❌ Failed to retrieve token from control plane${NC}"
        exit 1
    }
    chmod 600 "$K3S_TOKEN_FILE"
fi

K3S_TOKEN=$(cat "$K3S_TOKEN_FILE")
if [ -z "$K3S_TOKEN" ]; then
    echo -e "${RED}❌ k3s token is empty${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Token retrieved${NC}"
echo ""

# Update Ansible inventory
echo -e "${YELLOW}[5/6] Updating Ansible inventory...${NC}"
INVENTORY_FILE="${ANSIBLE_DIR}/inventory/hosts.yml"

# Backup inventory
cp "$INVENTORY_FILE" "${INVENTORY_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if worker already in inventory
if grep -q "$WORKER_HOSTNAME:" "$INVENTORY_FILE"; then
    echo -e "${YELLOW}⚠ Worker ${WORKER_HOSTNAME} already in inventory${NC}"
    read -p "Update existing entry? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Update existing entry
        if [ -n "$STATIC_IP" ]; then
            ansible_host_value="$STATIC_IP"
        else
            ansible_host_value="$WORKER_IP"
        fi
        
        # Use Python to update YAML (more reliable than sed)
        python3 << EOF
import yaml
import sys

inventory_file = '${INVENTORY_FILE}'
worker_hostname = '${WORKER_HOSTNAME}'
ansible_host_value = '${ansible_host_value}'
ssh_user = '${SSH_USER}'

with open(inventory_file, 'r') as f:
    inventory = yaml.safe_load(f)

# Update or add worker host
if worker_hostname not in inventory['all']['children']['raspberry_pi']['hosts']:
    inventory['all']['children']['raspberry_pi']['hosts'][worker_hostname] = {}

inventory['all']['children']['raspberry_pi']['hosts'][worker_hostname]['ansible_host'] = ansible_host_value
inventory['all']['children']['raspberry_pi']['hosts'][worker_hostname]['ansible_user'] = ssh_user
inventory['all']['children']['raspberry_pi']['hosts'][worker_hostname]['ansible_ssh_common_args'] = '-o StrictHostKeyChecking=no'

with open(inventory_file, 'w') as f:
    yaml.dump(inventory, f, default_flow_style=False, sort_keys=False)
EOF
    else
        echo "Skipping inventory update"
    fi
else
    # Add new worker entry
    if [ -n "$STATIC_IP" ]; then
        ansible_host_value="$STATIC_IP"
    else
        ansible_host_value="$WORKER_IP"
    fi
    
    python3 << EOF
import yaml
import sys

inventory_file = '${INVENTORY_FILE}'
worker_hostname = '${WORKER_HOSTNAME}'
ansible_host_value = '${ansible_host_value}'
ssh_user = '${SSH_USER}'

with open(inventory_file, 'r') as f:
    inventory = yaml.safe_load(f)

# Add worker host
if worker_hostname not in inventory['all']['children']['raspberry_pi']['hosts']:
    inventory['all']['children']['raspberry_pi']['hosts'][worker_hostname] = {}

inventory['all']['children']['raspberry_pi']['hosts'][worker_hostname]['ansible_host'] = ansible_host_value
inventory['all']['children']['raspberry_pi']['hosts'][worker_hostname]['ansible_user'] = ssh_user
inventory['all']['children']['raspberry_pi']['hosts'][worker_hostname]['ansible_ssh_common_args'] = '-o StrictHostKeyChecking=no'

with open(inventory_file, 'w') as f:
    yaml.dump(inventory, f, default_flow_style=False, sort_keys=False)
EOF
fi

echo -e "${GREEN}✓ Inventory updated${NC}"
echo ""

# Run Ansible playbooks
echo -e "${YELLOW}[6/6] Running Ansible playbooks...${NC}"
echo ""

cd "$ANSIBLE_DIR"

# System setup
echo -e "${BLUE}→ Running system setup...${NC}"
ansible-playbook playbooks/setup-system.yml \
    --limit "$WORKER_HOSTNAME" \
    -e "target_user=raolivei" \
    -e "hostname=${WORKER_HOSTNAME}" \
    -e "static_ip=${STATIC_IP:-}" \
    -e "static_netmask=255.255.255.0" \
    -e "static_gateway=192.168.2.1" \
    -e "static_dns=['192.168.2.1', '8.8.8.8']" \
    --ask-pass \
    --ask-become-pass || {
    echo -e "${RED}❌ System setup failed${NC}"
    exit 1
}

echo ""

# Install k3s worker
echo -e "${BLUE}→ Installing k3s worker...${NC}"
ansible-playbook playbooks/install-k3s-worker.yml \
    --limit "$WORKER_HOSTNAME" \
    -e "k3s_token=${K3S_TOKEN}" \
    -e "k3s_server_url=https://eldertree:6443" \
    --ask-become-pass || {
    echo -e "${RED}❌ k3s worker installation failed${NC}"
    exit 1
}

echo ""

# Verify node joined cluster
echo -e "${YELLOW}Verifying worker node joined cluster...${NC}"
export KUBECONFIG=~/.kube/config-eldertree
sleep 5

if kubectl get nodes "$WORKER_HOSTNAME" &>/dev/null; then
    echo -e "${GREEN}✓ Worker node successfully joined the cluster!${NC}"
    echo ""
    kubectl get nodes
else
    echo -e "${YELLOW}⚠ Worker node may still be joining. Check status:${NC}"
    echo "  export KUBECONFIG=~/.kube/config-eldertree"
    echo "  kubectl get nodes"
    echo ""
    echo "If node doesn't appear after a few minutes, check logs:"
    echo "  ssh ${SSH_USER}@${WORKER_IP}"
    echo "  sudo journalctl -u k3s-agent -n 50"
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"

