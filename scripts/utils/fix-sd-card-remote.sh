#!/bin/bash
# Fix SD card fstab when SD card is in another Pi
# Usage: Run this on a Pi that can access the SD card

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== SD Card fstab Fix (Remote Pi) ===${NC}"
echo ""

# Find SD card
echo -e "${YELLOW}Looking for SD card...${NC}"
SD_CARD=$(lsblk -d -n -o NAME,TYPE | grep disk | grep -v nvme | head -1 | awk '{print $1}')
if [ -z "$SD_CARD" ]; then
    echo -e "${RED}❌ No SD card found${NC}"
    exit 1
fi

SD_DEVICE="/dev/$SD_CARD"
echo -e "${GREEN}✓ Found SD card: $SD_DEVICE${NC}"

# Check partitions
ROOT_PART="${SD_DEVICE}p2"
if [ ! -b "$ROOT_PART" ]; then
    ROOT_PART="${SD_DEVICE}2"
fi

if [ ! -b "$ROOT_PART" ]; then
    echo -e "${RED}❌ Root partition not found${NC}"
    lsblk "$SD_DEVICE"
    exit 1
fi

echo -e "${GREEN}✓ Root partition: $ROOT_PART${NC}"
echo ""

# Mount root partition
MOUNT_POINT="/mnt/sd-root-$$"
echo -e "${YELLOW}Mounting root partition...${NC}"
sudo mkdir -p "$MOUNT_POINT"
sudo mount "$ROOT_PART" "$MOUNT_POINT"

# Run the fix
cd "$(dirname "$0")"
sudo ./fix-sd-card-fstab.sh "$MOUNT_POINT"

# Unmount
echo -e "${YELLOW}Unmounting...${NC}"
sudo umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

echo -e "${GREEN}✓ Done! SD card is ready to use.${NC}"

