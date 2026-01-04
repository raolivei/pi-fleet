#!/bin/bash
# Recovery script for node booted from SD card with generic hostname (node-x)
# Identifies node by IP address and applies recovery fixes to NVMe (not SD card)
# 
# IMPORTANT: This script fixes the NVMe drive, not the SD card!
# The node must be booted from SD card, and the NVMe must be connected.
# Corrections are applied to /mnt/nvme-root (NVMe root partition).
#
# Usage: ./recover-node-by-ip.sh <IP_ADDRESS>
# Example: ./recover-node-by-ip.sh 192.168.2.101

set -e

IP=${1:-""}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$PI_FLEET_DIR/ansible"
INVENTORY="$ANSIBLE_DIR/inventory/hosts.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to identify node by IP
identify_node() {
    local ip=$1
    
    case "$ip" in
        192.168.2.101|10.0.0.1)
            echo "node-1"
            return 0
            ;;
        192.168.2.102|10.0.0.2)
            echo "node-2"
            return 0
            ;;
        192.168.2.103|10.0.0.3)
            echo "node-3"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check if IP provided
if [[ -z "$IP" ]]; then
    echo -e "${RED}Error: IP address required${NC}"
    echo "Usage: $0 <IP_ADDRESS>"
    echo "Example: $0 192.168.2.86"
    echo ""
    echo "Available nodes:"
    echo "  - node-1: 192.168.2.101 or 10.0.0.1"
    echo "  - node-2: 192.168.2.102 or 10.0.0.2"
    echo "  - node-3: 192.168.2.103 or 10.0.0.3"
    exit 1
fi

# Identify node
NODE_NAME=$(identify_node "$IP")
if [[ -z "$NODE_NAME" ]]; then
    echo -e "${RED}Error: Unknown IP address: $IP${NC}"
    echo "Known IPs:"
    echo "  - node-1: 192.168.2.101 or 10.0.0.1"
    echo "  - node-2: 192.168.2.102 or 10.0.0.2"
    echo "  - node-3: 192.168.2.103 or 10.0.0.3"
    exit 1
fi

echo -e "${YELLOW}=== Node Recovery: $NODE_NAME ($IP) ===${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: This script fixes the NVMe drive, not the SD card!${NC}"
echo "   - Node is currently booted from SD card"
echo "   - NVMe must be connected (but not booted from)"
echo "   - Corrections will be applied to NVMe partitions"
echo ""

# Check if node is reachable
echo "Checking if $IP is accessible..."
if ! ping -c 1 -W 2 "$IP" &>/dev/null; then
    echo -e "${RED}❌ $IP is not reachable${NC}"
    echo "Make sure:"
    echo "  1. SD card is inserted and node booted from it"
    echo "  2. NVMe is connected (but node is booting from SD)"
    echo "  3. Node booted completely (wait 1-2 minutes)"
    exit 1
fi

# Test SSH
echo "Testing SSH connection..."
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no raolivei@"$IP" "echo ok" &>/dev/null; then
    echo -e "${RED}❌ SSH not working on $IP${NC}"
    echo "Make sure SSH is enabled and accessible"
    exit 1
fi

echo -e "${GREEN}✅ $IP is accessible${NC}"
echo ""

# Create temporary inventory entry for this IP
TEMP_INVENTORY=$(mktemp)
cat > "$TEMP_INVENTORY" <<EOF
[raspberry_pi]
temp_node ansible_host=$IP ansible_user=raolivei ansible_ssh_private_key_file=~/.ssh/id_ed25519_raolivei ansible_ssh_common_args="-o StrictHostKeyChecking=no"
EOF

# Check if NVMe is connected
echo "Checking if NVMe is connected..."
NVME_CHECK=$(ssh -o StrictHostKeyChecking=no raolivei@"$IP" "lsblk | grep nvme || echo 'not_found'" 2>/dev/null || echo "not_found")
if [[ "$NVME_CHECK" == *"not_found"* ]] || [[ -z "$NVME_CHECK" ]]; then
    echo -e "${RED}❌ NVMe not detected!${NC}"
    echo "Make sure:"
    echo "  1. NVMe drive is connected"
    echo "  2. Node is booted from SD card (not NVMe)"
    exit 1
fi
echo -e "${GREEN}✅ NVMe detected${NC}"
echo ""

# Mount NVMe partitions
echo "Mounting NVMe partitions..."
ssh -o StrictHostKeyChecking=no raolivei@"$IP" "sudo mkdir -p /mnt/nvme-root /mnt/nvme-boot" 2>/dev/null || true
ssh -o StrictHostKeyChecking=no raolivei@"$IP" "sudo mount /dev/nvme0n1p2 /mnt/nvme-root 2>/dev/null && echo 'NVMe root mounted' || echo 'NVMe root already mounted or failed'" 2>/dev/null
ssh -o StrictHostKeyChecking=no raolivei@"$IP" "sudo mount /dev/nvme0n1p1 /mnt/nvme-boot 2>/dev/null && echo 'NVMe boot mounted' || echo 'NVMe boot already mounted or failed'" 2>/dev/null
echo ""

# Apply boot reliability fixes to NVMe (not SD card)
echo -e "${YELLOW}Applying boot reliability fixes to NVMe (not SD card)...${NC}"
cd "$ANSIBLE_DIR" || exit 1

# Fix NVMe fstab
echo "  - Fixing NVMe fstab..."
ansible temp_node -i "$TEMP_INVENTORY" -m shell -a "
    # Backup NVMe fstab
    sudo cp /mnt/nvme-root/etc/fstab /mnt/nvme-root/etc/fstab.bak.\$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
    
    # Remove unused backup mount
    sudo sed -i '/\/dev\/sdb1.*\/mnt\/backup/d' /mnt/nvme-root/etc/fstab 2>/dev/null || true
    
    # Add nofail to optional mounts
    sudo sed -i 's|\(/dev/nvme[^\s]*\s\+[^\s]*\s\+ext4\s\+defaults\)\([^,]*\)|\1,nofail\2|g' /mnt/nvme-root/etc/fstab 2>/dev/null || true
    sudo sed -i 's|\(/dev/nvme[^\s]*\s\+[^\s]*\s\+vfat\s\+defaults\)\([^,]*\)|\1,nofail\2|g' /mnt/nvme-root/etc/fstab 2>/dev/null || true
    sudo sed -i 's|\(/mnt/backup.*defaults\)\([^,]*\)|\1,nofail\2|g' /mnt/nvme-root/etc/fstab 2>/dev/null || true
    
    # Boot partition
    if grep -q '/boot/firmware' /mnt/nvme-root/etc/fstab; then
        sudo sed -i 's|\(/boot/firmware.*defaults\)\([^,]*\)|\1,nofail\2|g' /mnt/nvme-root/etc/fstab 2>/dev/null || true
    fi
" --become &>/dev/null || true

# Fix NVMe PAM faillock
echo "  - Fixing NVMe PAM faillock..."
ansible temp_node -i "$TEMP_INVENTORY" -m shell -a "
    sudo cp /mnt/nvme-root/etc/pam.d/common-auth /mnt/nvme-root/etc/pam.d/common-auth.bak.\$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
    sudo sed -i '/pam_faillock/s/^[^#]/#&/' /mnt/nvme-root/etc/pam.d/common-auth 2>/dev/null || true
" --become &>/dev/null || true

# Unlock root on NVMe
echo "  - Unlocking root account on NVMe..."
ansible temp_node -i "$TEMP_INVENTORY" -m shell -a "
    sudo chroot /mnt/nvme-root passwd -u root 2>/dev/null || true
    sudo chroot /mnt/nvme-root faillock --user root --reset 2>/dev/null || true
" --become &>/dev/null || true

# Set root password on NVMe
echo "  - Setting root password on NVMe..."
if [[ -n "$PI_PASSWORD" ]]; then
    ansible temp_node -i "$TEMP_INVENTORY" -m shell -a "echo 'root:$PI_PASSWORD' | sudo chroot /mnt/nvme-root chpasswd" --become &>/dev/null || true
fi

# Fix NVMe cmdline.txt
echo "  - Fixing NVMe cmdline.txt..."
ansible temp_node -i "$TEMP_INVENTORY" -m shell -a "
    # Backup cmdline.txt
    sudo cp /mnt/nvme-boot/cmdline.txt /mnt/nvme-boot/cmdline.txt.bak.\$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
    
    # Ensure root is set to NVMe partition
    sudo sed -i 's|root=[^ ]*|root=/dev/nvme0n1p2|g' /mnt/nvme-boot/cmdline.txt 2>/dev/null || true
    
    # Ensure cgroup settings are correct
    if ! grep -q 'cgroup_enable' /mnt/nvme-boot/cmdline.txt; then
        sudo sed -i 's|$| cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory|' /mnt/nvme-boot/cmdline.txt 2>/dev/null || true
    fi
" --become &>/dev/null || true

echo -e "${GREEN}✅ NVMe fixes applied successfully${NC}"

echo ""

# Verify fixes on NVMe
echo ""
echo "Verifying fixes on NVMe..."

echo -n "  - NVMe fstab has nofail: "
if ssh -o StrictHostKeyChecking=no raolivei@"$IP" "sudo grep -q nofail /mnt/nvme-root/etc/fstab" &>/dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️  (may not be needed)${NC}"
fi

echo -n "  - Backup mount removed from NVMe fstab: "
if ssh -o StrictHostKeyChecking=no raolivei@"$IP" "sudo grep -q '/dev/sdb1.*backup' /mnt/nvme-root/etc/fstab" &>/dev/null; then
    echo -e "${RED}❌ Still present${NC}"
else
    echo -e "${GREEN}✅${NC}"
fi

echo -n "  - Root unlocked on NVMe: "
ROOT_STATUS=$(ssh -o StrictHostKeyChecking=no raolivei@"$IP" "sudo chroot /mnt/nvme-root passwd -S root 2>/dev/null | grep -o 'L\|P\|NP' | head -1" || echo "L")
if [[ "$ROOT_STATUS" != "L" ]]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
fi

echo -n "  - NVMe cmdline.txt configured: "
if ssh -o StrictHostKeyChecking=no raolivei@"$IP" "sudo grep -q 'root=/dev/nvme0n1p2' /mnt/nvme-boot/cmdline.txt" &>/dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️  Check manually${NC}"
fi

# Cleanup
rm -f "$TEMP_INVENTORY"

# Unmount NVMe (optional, can leave mounted for verification)
echo ""
echo "NVMe partitions are still mounted at /mnt/nvme-root and /mnt/nvme-boot"
echo "You can unmount them after verification, or leave them mounted."
echo ""

echo -e "${GREEN}=== Recovery Complete for $NODE_NAME ===${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: All fixes were applied to NVMe, not SD card!${NC}"
echo ""
echo "Next steps:"
echo "  1. Unmount NVMe (optional): ssh raolivei@$IP 'sudo umount /mnt/nvme-root /mnt/nvme-boot'"
echo "  2. Remove SD card from node"
echo "  3. Ensure NVMe is connected"
echo "  4. Reboot: ssh raolivei@$IP 'sudo reboot'"
echo "  5. Wait 2 minutes and verify: ping -c 1 $IP"
echo "  6. If it boots correctly from NVMe, node is recovered"
echo "  7. Repeat process for next node"
echo ""
echo "To configure hostname after recovery:"
echo "  cd $ANSIBLE_DIR"
echo "  ansible-playbook playbooks/setup-system.yml --limit $NODE_NAME -e hostname=$NODE_NAME.eldertree.local"

