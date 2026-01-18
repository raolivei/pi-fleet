#!/bin/bash
# Fix SD card fstab when SD card is plugged into another Pi via USB
# Run this on node-1 (or any Pi) with the SD card plugged in via USB

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== SD Card fstab Fix (USB on Pi) ===${NC}"
echo ""

# Find USB device (usually /dev/sda or /dev/sdb)
echo -e "${YELLOW}Looking for USB device with SD card...${NC}"
USB_DEVICE=""
for dev in /dev/sd[a-z]; do
    if [ -b "$dev" ]; then
        # Check if it has partitions
        if lsblk "$dev" | grep -q "part"; then
            USB_DEVICE="$dev"
            echo -e "${GREEN}✓ Found USB device: $USB_DEVICE${NC}"
            lsblk "$USB_DEVICE"
            break
        fi
    fi
done

if [ -z "$USB_DEVICE" ]; then
    echo -e "${RED}❌ No USB device with partitions found${NC}"
    echo "Please check: lsblk"
    exit 1
fi

# Find root partition (usually partition 2)
ROOT_PART="${USB_DEVICE}2"
if [ ! -b "$ROOT_PART" ]; then
    ROOT_PART="${USB_DEVICE}p2"
fi

if [ ! -b "$ROOT_PART" ]; then
    echo -e "${RED}❌ Root partition not found${NC}"
    echo "Available partitions:"
    lsblk "$USB_DEVICE"
    echo ""
    echo "Please specify the root partition manually:"
    echo "Usage: $0 /dev/sdX2"
    exit 1
fi

echo -e "${GREEN}✓ Root partition: $ROOT_PART${NC}"
echo ""

# Mount root partition
MOUNT_POINT="/mnt/sd-root-$$"
echo -e "${YELLOW}Mounting root partition...${NC}"
sudo mkdir -p "$MOUNT_POINT"
sudo mount "$ROOT_PART" "$MOUNT_POINT"

# Check if fstab exists
if [ ! -f "$MOUNT_POINT/etc/fstab" ]; then
    echo -e "${RED}❌ fstab not found at $MOUNT_POINT/etc/fstab${NC}"
    echo "Are you sure this is the root partition?"
    sudo umount "$MOUNT_POINT"
    rmdir "$MOUNT_POINT"
    exit 1
fi

# Show current fstab
echo -e "${BLUE}Current fstab:${NC}"
cat "$MOUNT_POINT/etc/fstab"
echo ""

# Backup
BACKUP_FILE="$MOUNT_POINT/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"
echo -e "${YELLOW}Creating backup: $BACKUP_FILE${NC}"
sudo cp "$MOUNT_POINT/etc/fstab" "$BACKUP_FILE"

# Fix fstab - add nofail to non-critical mounts
echo -e "${YELLOW}Fixing fstab...${NC}"
sudo sed -i.bak \
    -e 's|\(/mnt/backup.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' \
    -e 's|\(/dev/sdb1.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' \
    -e 's|\(UUID=.*/mnt/backup.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' \
    -e '/^[^#].*\/mnt\/backup/s/defaults[^,]*/defaults,nofail/g' \
    -e '/^[^#].*\/dev\/sdb/s/defaults[^,]*/defaults,nofail/g' \
    "$MOUNT_POINT/etc/fstab"

# Show fixed fstab
echo -e "${GREEN}✓ Fixed fstab:${NC}"
cat "$MOUNT_POINT/etc/fstab"
echo ""

# Unmount
echo -e "${YELLOW}Unmounting...${NC}"
sudo umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

echo ""
echo -e "${GREEN}=== Fix Complete ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Safely remove the USB device"
echo "  2. Put the SD card back in node-1"
echo "  3. Boot node-1 - it should boot normally now"
echo ""

