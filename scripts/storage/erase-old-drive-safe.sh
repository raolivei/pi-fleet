#!/bin/bash
# Safe erase of old NVMe drive - checks boot source first
# Usage: ./erase-old-drive-safe.sh [device]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DEVICE="${1:-/dev/nvme0n1}"

echo -e "${BLUE}=== Safe Erase Old NVMe Drive ===${NC}"
echo ""

# Check current boot device
CURRENT_ROOT=$(df -h / | tail -1 | awk '{print $1}')
echo -e "${BLUE}Current root: $CURRENT_ROOT${NC}"

# Check if we're trying to erase the boot device
if [[ "$CURRENT_ROOT" == *"$(basename $DEVICE)"* ]]; then
    echo -e "${RED}❌ ERROR: Cannot erase the drive you're booting from!${NC}"
    echo ""
    echo "Current situation:"
    echo "  Booting from: $CURRENT_ROOT"
    echo "  Trying to erase: $DEVICE"
    echo ""
    echo -e "${YELLOW}To erase the old drive:${NC}"
    echo "  1. Boot from SD card (not NVMe)"
    echo "  2. Then run this script again"
    echo ""
    echo "To boot from SD card:"
    echo "  Option A: Remove NVMe temporarily and boot"
    echo "  Option B: Update boot config to use SD card, then reboot"
    echo ""
    echo "After booting from SD card, verify:"
    echo "  df -h /  # Should show /dev/mmcblk0p2"
    echo "  Then run: sudo ./secure-erase-old-nvme.sh $DEVICE"
    exit 1
fi

# Check device size to verify it's the old drive
if [ -b "$DEVICE" ]; then
    DEVICE_SIZE=$(blockdev --getsize64 "$DEVICE")
    DEVICE_SIZE_GB=$((DEVICE_SIZE / 1024 / 1024 / 1024))
    echo -e "${BLUE}Device size: ${DEVICE_SIZE_GB}GB${NC}"
    
    if [ "$DEVICE_SIZE_GB" -ge 200 ] && [ "$DEVICE_SIZE_GB" -le 300 ]; then
        echo -e "${GREEN}✓ This appears to be the old ~256GB drive${NC}"
    else
        echo -e "${YELLOW}⚠️  Warning: Size doesn't match expected ~256GB${NC}"
    fi
else
    echo -e "${RED}❌ Device not found: $DEVICE${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Safe to erase - not booting from this device${NC}"
echo "  Booting from: $CURRENT_ROOT"
echo "  Will erase: $DEVICE"
echo ""

# Run the secure erase script
if [ -f ./secure-erase-old-nvme.sh ]; then
    sudo ./secure-erase-old-nvme.sh "$DEVICE"
elif [ -f ~/secure-erase-old-nvme.sh ]; then
    sudo ~/secure-erase-old-nvme.sh "$DEVICE"
else
    echo -e "${RED}❌ secure-erase-old-nvme.sh not found${NC}"
    echo "  Please ensure the script is in current directory or home directory"
    exit 1
fi

