#!/bin/bash
# Verify NVMe migration was successful
# Usage: ./verify-nvme-migration.sh [node-name]
# Can be run locally on the node or remotely via SSH

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NODE_NAME="${1:-$(hostname)}"

echo -e "${BLUE}=== NVMe Migration Verification for $NODE_NAME ===${NC}"
echo ""

# Check root filesystem
echo -e "${YELLOW}[1/5] Checking root filesystem...${NC}"
ROOT_DEVICE=$(df -h / | tail -1 | awk '{print $1}')
echo "  Root device: $ROOT_DEVICE"

if [[ "$ROOT_DEVICE" == *"nvme0n1p2"* ]]; then
    echo -e "${GREEN}✓ Booting from new NVMe${NC}"
    BOOT_FROM_NVME=true
else
    echo -e "${YELLOW}⚠️  Not booting from new NVMe (currently: $ROOT_DEVICE)${NC}"
    BOOT_FROM_NVME=false
fi
echo ""

# Check boot partition
echo -e "${YELLOW}[2/5] Checking boot partition...${NC}"
BOOT_MOUNT=$(mount | grep "/boot/firmware" | awk '{print $1}' || echo "")
if [ -n "$BOOT_MOUNT" ]; then
    echo "  Boot partition: $BOOT_MOUNT"
    if [[ "$BOOT_MOUNT" == *"nvme0n1p1"* ]]; then
        echo -e "${GREEN}✓ Boot partition on new NVMe${NC}"
    else
        echo -e "${YELLOW}⚠️  Boot partition not on new NVMe${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Boot partition not mounted${NC}"
fi
echo ""

# Check NVMe device
echo -e "${YELLOW}[3/5] Checking NVMe device...${NC}"
if [ -b /dev/nvme0n1 ]; then
    NVME_SIZE=$(blockdev --getsize64 /dev/nvme0n1)
    NVME_SIZE_GB=$((NVME_SIZE / 1024 / 1024 / 1024))
    echo "  NVMe device: /dev/nvme0n1"
    echo "  Size: ${NVME_SIZE_GB}GB"
    
    if [ "$NVME_SIZE_GB" -ge 100 ] && [ "$NVME_SIZE_GB" -le 150 ]; then
        echo -e "${GREEN}✓ NVMe size matches expected 128GB${NC}"
    else
        echo -e "${YELLOW}⚠️  NVMe size (${NVME_SIZE_GB}GB) doesn't match expected 128GB${NC}"
    fi
    
    echo ""
    echo "  Partition layout:"
    lsblk /dev/nvme0n1 | sed 's/^/    /'
else
    echo -e "${RED}❌ NVMe device not found${NC}"
fi
echo ""

# Check K3s status
echo -e "${YELLOW}[4/5] Checking K3s status...${NC}"
if systemctl is-active --quiet k3s 2>/dev/null; then
    echo -e "${GREEN}✓ K3s server is running${NC}"
    K3S_STATUS="server"
elif systemctl is-active --quiet k3s-agent 2>/dev/null; then
    echo -e "${GREEN}✓ K3s agent is running${NC}"
    K3S_STATUS="agent"
else
    echo -e "${YELLOW}⚠️  K3s is not running${NC}"
    K3S_STATUS="none"
fi

if [ -d /var/lib/rancher/k3s ]; then
    echo -e "${GREEN}✓ K3s data directory exists${NC}"
    K3S_DATA_SIZE=$(du -sh /var/lib/rancher/k3s 2>/dev/null | awk '{print $1}' || echo "unknown")
    echo "  Data size: $K3S_DATA_SIZE"
else
    echo -e "${YELLOW}⚠️  K3s data directory not found${NC}"
fi
echo ""

# Check boot configuration
echo -e "${YELLOW}[5/5] Checking boot configuration...${NC}"
if [ -f /boot/firmware/cmdline.txt ]; then
    if grep -q "root=/dev/nvme0n1p2" /boot/firmware/cmdline.txt; then
        echo -e "${GREEN}✓ cmdline.txt configured for new NVMe${NC}"
    else
        echo -e "${YELLOW}⚠️  cmdline.txt may not be configured for new NVMe${NC}"
        echo "  Current root setting:"
        grep -o "root=[^ ]*" /boot/firmware/cmdline.txt | sed 's/^/    /' || echo "    (not found)"
    fi
else
    echo -e "${YELLOW}⚠️  cmdline.txt not found${NC}"
fi

if [ -f /etc/fstab ]; then
    if grep -q "nvme0n1" /etc/fstab; then
        echo -e "${GREEN}✓ fstab references new NVMe${NC}"
    else
        echo -e "${YELLOW}⚠️  fstab may not reference new NVMe${NC}"
    fi
fi
echo ""

# Summary
echo -e "${BLUE}=== Verification Summary ===${NC}"
echo ""
if [ "$BOOT_FROM_NVME" = true ]; then
    echo -e "${GREEN}✅ Migration appears successful${NC}"
    echo "  - Booting from new NVMe"
    echo "  - K3s status: $K3S_STATUS"
    echo ""
    echo -e "${YELLOW}Recommendations:${NC}"
    echo "  1. Verify cluster health: kubectl get nodes"
    echo "  2. Check all pods: kubectl get pods -A"
    echo "  3. Test storage performance if needed"
else
    echo -e "${YELLOW}⚠️  Migration may not be complete${NC}"
    echo "  - Not currently booting from new NVMe"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Reboot the system: sudo reboot"
    echo "  2. After reboot, run this script again to verify"
fi
echo ""

