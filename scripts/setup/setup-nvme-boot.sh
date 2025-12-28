#!/bin/bash
# Wrapper script to run Ansible playbook for NVMe boot setup
# This is a convenience script - the actual work is done by Ansible

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== NVMe Boot Setup (via Ansible) ===${NC}"
echo ""
echo "This script runs the Ansible playbook to configure boot from NVMe."
echo ""

# Check if Ansible is available
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${YELLOW}Ansible not found. Installing...${NC}"
    echo "Please install Ansible first:"
    echo "  brew install ansible"
    exit 1
fi

# Change to Ansible directory
cd "$ANSIBLE_DIR"

# Run the playbook
echo -e "${GREEN}Running Ansible playbook...${NC}"
echo ""

ansible-playbook playbooks/setup-nvme-boot.yml \
    -e setup_nvme_boot=true \
    -e clone_from_sd=true \
    --ask-become-pass

echo ""
echo -e "${GREEN}=== Complete ===${NC}"
echo ""
echo "Next step: Reboot the Pi"
echo "  sudo reboot"

