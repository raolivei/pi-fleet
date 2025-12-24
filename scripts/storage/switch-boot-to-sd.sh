#!/bin/bash
# Switch boot to SD card so we can erase old NVMe
# This updates boot config to boot from SD card on next reboot

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Switch Boot to SD Card ===${NC}"
echo ""

# Check current boot
CURRENT_ROOT=$(df -h / | tail -1 | awk '{print $1}')
echo -e "${BLUE}Current root: $CURRENT_ROOT${NC}"

if [[ "$CURRENT_ROOT" == *"mmcblk0"* ]]; then
    echo -e "${GREEN}✓ Already booting from SD card${NC}"
    echo "  You can now erase the old NVMe drive"
    exit 0
fi

# Check SD card exists
SD_CARD="/dev/mmcblk0"
SD_BOOT="/dev/mmcblk0p1"
SD_ROOT="/dev/mmcblk0p2"

if [ ! -b "$SD_BOOT" ] || [ ! -b "$SD_ROOT" ]; then
    echo -e "${RED}❌ SD card partitions not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ SD card found${NC}"
echo ""

# Mount SD card boot partition
TEMP_MOUNT="/tmp/sd-boot-switch-$$"
sudo mkdir -p "$TEMP_MOUNT"

if ! sudo mount "$SD_BOOT" "$TEMP_MOUNT" 2>/dev/null; then
    echo -e "${RED}❌ Failed to mount SD card boot partition${NC}"
    exit 1
fi

# Update cmdline.txt on SD card to boot from SD
if [ -f "$TEMP_MOUNT/cmdline.txt" ]; then
    echo -e "${YELLOW}Updating SD card boot configuration...${NC}"
    sudo cp "$TEMP_MOUNT/cmdline.txt" "$TEMP_MOUNT/cmdline.txt.bak.$(date +%Y%m%d-%H%M%S)"
    
    # Update root to SD card
    sudo sed -i.bak "s|root=[^ ]*|root=$SD_ROOT|g" "$TEMP_MOUNT/cmdline.txt"
    
    echo -e "${GREEN}✓ SD card boot config updated${NC}"
    echo "  Updated cmdline.txt:"
    cat "$TEMP_MOUNT/cmdline.txt" | sed 's/^/    /'
else
    echo -e "${RED}❌ cmdline.txt not found on SD card boot partition${NC}"
    sudo umount "$TEMP_MOUNT"
    rmdir "$TEMP_MOUNT"
    exit 1
fi

sudo umount "$TEMP_MOUNT"
rmdir "$TEMP_MOUNT"

echo ""
echo -e "${GREEN}=== Boot Configuration Updated ===${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Reboot: sudo reboot"
echo "  2. System should boot from SD card"
echo "  3. Verify: df -h / (should show $SD_ROOT)"
echo "  4. Then erase old NVMe: sudo ./secure-erase-old-nvme.sh /dev/nvme0n1"
echo ""

