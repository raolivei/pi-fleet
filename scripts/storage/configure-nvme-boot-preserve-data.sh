#!/bin/bash
# Configure NVMe boot WITHOUT erasing existing data
# This script updates boot configuration while preserving K3s data and other content

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Configure NVMe Boot (Preserve Data) ===${NC}"
echo ""

# Device paths
SD_CARD="/dev/mmcblk0"
NVME_DEVICE="/dev/nvme0n1"
BOOT_PARTITION="${SD_CARD}p1"
ROOT_PARTITION="${SD_CARD}p2"
NVME_BOOT="${NVME_DEVICE}p1"
NVME_ROOT="${NVME_DEVICE}p2"

# Check if devices exist
if [ ! -b "$SD_CARD" ]; then
    echo -e "${RED}❌ SD card not found at $SD_CARD${NC}"
    exit 1
fi

if [ ! -b "$NVME_DEVICE" ]; then
    echo -e "${RED}❌ NVMe device not found at $NVME_DEVICE${NC}"
    exit 1
fi

# Check if NVMe partitions exist
if [ ! -b "$NVME_BOOT" ] || [ ! -b "$NVME_ROOT" ]; then
    echo -e "${RED}❌ NVMe partitions not found${NC}"
    echo "  Boot: $NVME_BOOT"
    echo "  Root: $NVME_ROOT"
    exit 1
fi

echo -e "${GREEN}✓ Devices found${NC}"
echo "  SD Card: $SD_CARD"
echo "  NVMe: $NVME_DEVICE"
echo ""

# Check if NVMe root has data
if [ -d "/mnt/nvme-root/var/lib/rancher/k3s" ]; then
    echo -e "${YELLOW}⚠️  K3s data found on NVMe root partition${NC}"
    echo "  This will be preserved"
    echo ""
fi

# Mount points
MOUNT_SD_BOOT="/mnt/sd-boot-$$"
MOUNT_NVME_BOOT="/mnt/nvme-boot-$$"
MOUNT_NVME_ROOT="/mnt/nvme-root-$$"

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    sudo umount "$MOUNT_SD_BOOT" 2>/dev/null || true
    sudo umount "$MOUNT_NVME_BOOT" 2>/dev/null || true
    sudo umount "$MOUNT_NVME_ROOT" 2>/dev/null || true
    rmdir "$MOUNT_SD_BOOT" "$MOUNT_NVME_BOOT" "$MOUNT_NVME_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

# Create mount points
sudo mkdir -p "$MOUNT_SD_BOOT" "$MOUNT_NVME_BOOT" "$MOUNT_NVME_ROOT"

# Mount partitions
echo -e "${YELLOW}[1/5] Mounting partitions...${NC}"
sudo mount "$BOOT_PARTITION" "$MOUNT_SD_BOOT"
sudo mount "$NVME_BOOT" "$MOUNT_NVME_BOOT"
sudo mount "$NVME_ROOT" "$MOUNT_NVME_ROOT"

echo -e "${GREEN}✓ Partitions mounted${NC}"
echo ""

# Check if NVMe boot partition has boot files
echo -e "${YELLOW}[2/5] Checking boot partition...${NC}"
if [ ! -f "$MOUNT_NVME_BOOT/cmdline.txt" ]; then
    echo -e "${YELLOW}⚠️  Boot partition missing cmdline.txt, copying from SD card...${NC}"
    sudo cp -a "$MOUNT_SD_BOOT"/* "$MOUNT_NVME_BOOT/" 2>/dev/null || true
    echo -e "${GREEN}✓ Boot files copied${NC}"
else
    echo -e "${GREEN}✓ Boot partition has files${NC}"
fi
echo ""

# Update cmdline.txt on NVMe boot partition
echo -e "${YELLOW}[3/5] Updating boot configuration...${NC}"
if [ -f "$MOUNT_NVME_BOOT/cmdline.txt" ]; then
    # Backup
    sudo cp "$MOUNT_NVME_BOOT/cmdline.txt" "$MOUNT_NVME_BOOT/cmdline.txt.bak.$(date +%Y%m%d-%H%M%S)"
    
    # Update root partition reference
    sudo sed -i.bak "s|root=/dev/mmcblk0p2|root=$NVME_ROOT|g" "$MOUNT_NVME_BOOT/cmdline.txt"
    sudo sed -i.bak "s|root=PARTUUID=[^ ]*|root=$NVME_ROOT|g" "$MOUNT_NVME_BOOT/cmdline.txt"
    
    # If root= is not in cmdline.txt, add it
    if ! grep -q "root=" "$MOUNT_NVME_BOOT/cmdline.txt"; then
        echo -e "${YELLOW}⚠️  Adding root parameter to cmdline.txt...${NC}"
        sudo sed -i "s|\$| root=$NVME_ROOT|" "$MOUNT_NVME_BOOT/cmdline.txt"
    fi
    
    echo -e "${GREEN}✓ cmdline.txt updated${NC}"
    echo "  Content:"
    cat "$MOUNT_NVME_BOOT/cmdline.txt" | sed 's/^/    /'
else
    echo -e "${RED}❌ cmdline.txt not found after copy${NC}"
    exit 1
fi
echo ""

# Update fstab on NVMe root partition
echo -e "${YELLOW}[4/5] Updating fstab on NVMe root...${NC}"
if [ -f "$MOUNT_NVME_ROOT/etc/fstab" ]; then
    # Backup
    sudo cp "$MOUNT_NVME_ROOT/etc/fstab" "$MOUNT_NVME_ROOT/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"
    
    # Update device references
    sudo sed -i.bak "s|/dev/mmcblk0p1|$NVME_BOOT|g" "$MOUNT_NVME_ROOT/etc/fstab"
    sudo sed -i.bak "s|/dev/mmcblk0p2|$NVME_ROOT|g" "$MOUNT_NVME_ROOT/etc/fstab"
    
    echo -e "${GREEN}✓ fstab updated${NC}"
    echo "  Content:"
    cat "$MOUNT_NVME_ROOT/etc/fstab" | sed 's/^/    /'
else
    echo -e "${YELLOW}⚠️  fstab not found, creating from SD card...${NC}"
    sudo cp "$MOUNT_SD_BOOT/../root/etc/fstab" "$MOUNT_NVME_ROOT/etc/fstab" 2>/dev/null || \
    sudo cp /etc/fstab "$MOUNT_NVME_ROOT/etc/fstab"
    sudo sed -i "s|/dev/mmcblk0p1|$NVME_BOOT|g" "$MOUNT_NVME_ROOT/etc/fstab"
    sudo sed -i "s|/dev/mmcblk0p2|$NVME_ROOT|g" "$MOUNT_NVME_ROOT/etc/fstab"
    echo -e "${GREEN}✓ fstab created${NC}"
fi
echo ""

# Verify K3s data is still there
echo -e "${YELLOW}[5/5] Verifying data preservation...${NC}"
if [ -d "$MOUNT_NVME_ROOT/var/lib/rancher/k3s" ]; then
    echo -e "${GREEN}✓ K3s data preserved${NC}"
    echo "  Location: $MOUNT_NVME_ROOT/var/lib/rancher/k3s"
    ls -la "$MOUNT_NVME_ROOT/var/lib/rancher/k3s" | head -5 | sed 's/^/    /'
else
    echo -e "${YELLOW}⚠️  No K3s data found (may not have been set up yet)${NC}"
fi
echo ""

# Unmount
cleanup

echo -e "${GREEN}=== Configuration Complete ===${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Reboot: sudo reboot"
echo "  2. System should boot from NVMe"
echo "  3. Verify: df -h / (should show $NVME_ROOT)"
echo "  4. K3s data is preserved at /var/lib/rancher/k3s"
echo ""
echo -e "${BLUE}Note:${NC} SD card remains as backup boot option"
echo ""

