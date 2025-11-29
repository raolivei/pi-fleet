#!/bin/bash
# Fix SD card fstab using Docker (works on macOS)
# This uses a Linux container to access the ext4 filesystem

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== SD Card fstab Fix (Docker Method) ===${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running${NC}"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

# Find SD card
SD_DEVICE="/dev/disk4"
if [ ! -b "$SD_DEVICE" ]; then
    echo -e "${RED}❌ SD card not found at $SD_DEVICE${NC}"
    echo "Please check: diskutil list"
    exit 1
fi

ROOT_PART="${SD_DEVICE}s2"
RAW_PART="/dev/rdisk4s2"  # Try raw device for macOS Docker
echo -e "${GREEN}✓ Using: $ROOT_PART${NC}"
echo -e "${YELLOW}Trying raw device: $RAW_PART${NC}"
echo ""

echo -e "${YELLOW}Running fix in Docker container...${NC}"
echo ""

# Try both regular and raw device
if [ -b "$RAW_PART" ]; then
    DEVICE_TO_USE="$RAW_PART"
    echo -e "${YELLOW}Using raw device: $DEVICE_TO_USE${NC}"
else
    DEVICE_TO_USE="$ROOT_PART"
    echo -e "${YELLOW}Using regular device: $DEVICE_TO_USE${NC}"
fi

# Run in privileged container with device access
# Inline the fix commands directly
docker run --rm --privileged \
    -v "$SD_DEVICE:$SD_DEVICE" \
    -v "$ROOT_PART:$ROOT_PART" \
    $(if [ -b "$RAW_PART" ]; then echo "-v $RAW_PART:$RAW_PART"; fi) \
    alpine:latest \
    sh -c "
        set -e
        echo 'Installing e2fsprogs...'
        apk add --no-cache e2fsprogs > /dev/null 2>&1
        echo 'Checking devices...'
        ls -la $ROOT_PART 2>/dev/null || echo 'Regular device not found'
        ls -la $RAW_PART 2>/dev/null || echo 'Raw device not found'
        echo 'Creating mount point...'
        mkdir -p /mnt/sd-root
        echo 'Trying to mount...'
        # Try raw device first, then regular
        if [ -b $RAW_PART ]; then
            echo 'Mounting raw device...'
            mount -t ext4 $RAW_PART /mnt/sd-root || mount $RAW_PART /mnt/sd-root || (echo 'Raw mount failed, trying regular...' && mount -t ext4 $ROOT_PART /mnt/sd-root || mount $ROOT_PART /mnt/sd-root)
        else
            echo 'Mounting regular device...'
            mount -t ext4 $ROOT_PART /mnt/sd-root || mount $ROOT_PART /mnt/sd-root || (echo 'Mount failed!' && exit 1)
        fi
        echo 'Checking mount...'
        ls -la /mnt/sd-root/ | head -10
        echo 'Checking for fstab...'
        if [ ! -f /mnt/sd-root/etc/fstab ]; then
            echo 'ERROR: fstab not found!'
            echo 'Contents of /mnt/sd-root/etc:'
            ls -la /mnt/sd-root/etc/ | head -20
            umount /mnt/sd-root
            exit 1
        fi
        echo 'Backing up fstab...'
        cp /mnt/sd-root/etc/fstab /mnt/sd-root/etc/fstab.bak.\$(date +%Y%m%d-%H%M%S)
        echo 'Fixing fstab...'
        sed -i 's|\(/mnt/backup.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' /mnt/sd-root/etc/fstab
        sed -i 's|\(/dev/sdb1.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' /mnt/sd-root/etc/fstab
        sed -i 's|\(UUID=.*/mnt/backup.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' /mnt/sd-root/etc/fstab
        # Also fix any line with defaults that doesn't have nofail (except root/boot)
        sed -i '/^[^#].*\/mnt\/backup/s/defaults[^,]*/defaults,nofail/g' /mnt/sd-root/etc/fstab
        sed -i '/^[^#].*\/dev\/sdb/s/defaults[^,]*/defaults,nofail/g' /mnt/sd-root/etc/fstab
        echo '=== Fixed fstab ==='
        cat /mnt/sd-root/etc/fstab
        echo 'Unmounting...'
        umount /mnt/sd-root
        echo 'Done!'
    "

echo ""
echo -e "${GREEN}✓ Done! SD card is ready to use.${NC}"
echo "You can now eject the SD card and put it back in node-1"

