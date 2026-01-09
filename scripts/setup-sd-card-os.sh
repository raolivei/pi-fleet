#!/bin/bash
# Setup SD card OS after imaging with Raspberry Pi Imager
# This script applies boot reliability fixes to a freshly imaged SD card
#
# Usage:
#   1. Image SD card with Raspberry Pi Imager (hostname: node-x, user: raolivei, password: Control01!)
#   2. Boot from SD card on any node
#   3. Run this script: ./scripts/setup-sd-card-os.sh <IP_ADDRESS>
#
# Example:
#   ./scripts/setup-sd-card-os.sh 192.168.2.103

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

IP=${1}
if [ -z "$IP" ]; then
    echo -e "${RED}Error: IP address required${NC}"
    echo "Usage: $0 <IP_ADDRESS>"
    echo "Example: $0 192.168.2.103"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$PI_FLEET_DIR/ansible"

echo -e "${YELLOW}=== SD Card OS Setup: $IP ===${NC}"
echo ""
echo "This script will:"
echo "  1. Verify SSH access to SD card OS"
echo "  2. Apply boot reliability fixes to SD card"
echo "  3. Remove unused backup mount"
echo "  4. Fix initramfs issues"
echo "  5. Verify configuration"
echo ""
echo "SD card OS should have:"
echo "  - Hostname: node-x"
echo "  - User: raolivei"
echo "  - Password: Control01!"
echo ""
echo -e "${YELLOW}⚠️  This fixes the SD card OS (not NVMe)${NC}"
echo "   After this, you can use the SD card to boot and fix NVMe"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Identify node by IP
NODE_1_IP="192.168.2.101"
NODE_2_IP="192.168.2.102"
NODE_3_IP="192.168.2.103"

if [[ "$IP" == "$NODE_1_IP" ]]; then
    NODE="node-1"
elif [[ "$IP" == "$NODE_2_IP" ]]; then
    NODE="node-2"
elif [[ "$IP" == "$NODE_3_IP" ]]; then
    NODE="node-3"
else
    echo -e "${YELLOW}Warning: IP $IP not in known nodes. Using IP as node identifier.${NC}"
    NODE="$IP"
fi

echo -e "${YELLOW}Identified node: $NODE${NC}"
echo ""

# Test SSH access
echo -e "${YELLOW}Testing SSH access...${NC}"
if sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 raolivei@$IP "echo 'SSH OK'" 2>/dev/null; then
    echo -e "${GREEN}✓ SSH access confirmed${NC}"
else
    echo -e "${RED}✗ Cannot SSH to $IP${NC}"
    echo "Please verify:"
    echo "  - SD card is booted"
    echo "  - IP address is correct"
    echo "  - SSH is enabled"
    echo "  - Password is Control01!"
    exit 1
fi

# Apply boot reliability fixes
echo ""
echo -e "${YELLOW}Applying boot reliability fixes to SD card...${NC}"
cd "$ANSIBLE_DIR"

# First, try to update initramfs if needed
echo "  - Updating initramfs..."
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$IP "sudo update-initramfs -u" 2>/dev/null || echo "  ⚠️  Initramfs update skipped (may not be needed)"

# Apply fixes using playbook
ansible-playbook playbooks/fix-boot-reliability.yml \
    --limit "$NODE" \
    -e ansible_user=raolivei \
    -e ansible_password=Control01! \
    -e ansible_ssh_common_args="-o StrictHostKeyChecking=no" \
    || {
    echo -e "${YELLOW}⚠️  Playbook had issues, trying manual fixes...${NC}"
    
    # Manual fixes as fallback
    sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$IP "
        # Remove backup mount
        sudo sed -i '/\/dev\/sdb1.*\/mnt\/backup/d' /etc/fstab
        
        # Add nofail to optional mounts
        sudo sed -i 's|\(/dev/nvme[^\s]*\s\+[^\s]*\s\+ext4\s\+defaults\)\([^,]*\)|\1,nofail\2|g' /etc/fstab || true
        sudo sed -i 's|\(/dev/nvme[^\s]*\s\+[^\s]*\s\+vfat\s\+defaults\)\([^,]*\)|\1,nofail\2|g' /etc/fstab || true
        
        # Disable PAM faillock
        sudo sed -i '/pam_faillock/s/^[^#]/#&/' /etc/pam.d/common-auth
        
        # Unlock root
        sudo passwd -u root
        sudo faillock --user root --reset
        
        # Update initramfs
        sudo update-initramfs -u
    " 2>/dev/null || true
}

# Verify configuration
echo ""
echo -e "${YELLOW}Verifying configuration...${NC}"

# Check hostname
HOSTNAME=$(sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$IP "hostname" 2>/dev/null)
if [[ "$HOSTNAME" == "node-x" ]]; then
    echo -e "${GREEN}✓ Hostname: $HOSTNAME${NC}"
else
    echo -e "${YELLOW}⚠ Hostname: $HOSTNAME (expected: node-x)${NC}"
fi

# Check fstab has nofail
if sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$IP "sudo grep -q nofail /etc/fstab" 2>/dev/null; then
    echo -e "${GREEN}✓ fstab has nofail flags${NC}"
else
    echo -e "${YELLOW}⚠ fstab may be missing nofail flags${NC}"
fi

# Check backup mount removed
if sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$IP "sudo grep -q '/dev/sdb1.*backup' /etc/fstab" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Backup mount still in fstab${NC}"
else
    echo -e "${GREEN}✓ Backup mount removed from fstab${NC}"
fi

# Check root unlocked
ROOT_STATUS=$(sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$IP "sudo passwd -S root" 2>/dev/null | awk '{print $2}')
if [[ "$ROOT_STATUS" == "P" ]] || [[ "$ROOT_STATUS" == "NP" ]]; then
    echo -e "${GREEN}✓ Root account unlocked${NC}"
else
    echo -e "${YELLOW}⚠ Root account status: $ROOT_STATUS${NC}"
fi

echo ""
echo -e "${GREEN}=== SD Card OS Setup Complete ===${NC}"
echo ""
echo "SD card is now ready for recovery use."
echo ""
echo "Next steps:"
echo "  1. Test reboot: ssh raolivei@$IP 'sudo reboot'"
echo "  2. Wait 2 minutes, then verify: ping -c 1 $IP"
echo "  3. SD card can be used for recovery on any node"
echo ""

