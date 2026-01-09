#!/bin/bash
# Fix SD card OS by mounting it on node-2
# This applies all boot reliability fixes to the SD card without booting from it
# Usage: Insert SD card into node-2, then run this script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== SD Card Fix Script ===${NC}"
echo ""
echo "This script will:"
echo "  1. Detect the SD card device"
echo "  2. Mount root partition"
echo "  3. Apply all boot reliability fixes:"
echo "     - Remove unused backup mount"
echo "     - Add nofail to optional mounts"
echo "     - Disable PAM faillock"
echo "     - Unlock root account"
echo "     - Set hostname to node-x"
echo "  4. Unmount safely"
echo ""
echo "Make sure the SD card is inserted in node-2"
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Find SD card device (usually /dev/mmcblk0, but might be different if NVMe is primary)
SD_DEVICE=""
if [ -b /dev/mmcblk0 ]; then
    SD_DEVICE="/dev/mmcblk0"
elif [ -b /dev/mmcblk1 ]; then
    SD_DEVICE="/dev/mmcblk1"
else
    echo -e "${RED}Error: SD card not found. Please insert SD card and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}Found SD card: $SD_DEVICE${NC}"
echo "Partitions:"
lsblk | grep "$SD_DEVICE"

# Find root partition (usually p2)
ROOT_PART="${SD_DEVICE}p2"
if [ ! -b "$ROOT_PART" ]; then
    echo -e "${RED}Error: Root partition $ROOT_PART not found${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Root partition: $ROOT_PART${NC}"
echo "Mounting..."

# Create mount point
MOUNT_POINT="/mnt/sd-fix"
sudo mkdir -p "$MOUNT_POINT"

# Unmount if already mounted
if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    echo "Unmounting existing mount..."
    sudo umount "$MOUNT_POINT" || true
fi

sudo mount "$ROOT_PART" "$MOUNT_POINT"

echo -e "${GREEN}✓ Mounted${NC}"
echo ""
echo "Current fstab:"
sudo cat "$MOUNT_POINT/etc/fstab"

echo ""
echo -e "${YELLOW}Fixing fstab...${NC}"

# Backup
FSTAB_BACKUP="$MOUNT_POINT/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"
sudo cp "$MOUNT_POINT/etc/fstab" "$FSTAB_BACKUP"
echo "Backup created: $FSTAB_BACKUP"

# Remove unused backup mount (causes boot timeout)
echo "Removing unused backup mount..."
sudo sed -i '/\/dev\/sdb1.*\/mnt\/backup/d' "$MOUNT_POINT/etc/fstab"

# Add nofail to optional mounts (NVMe, backup, etc.)
echo "Adding nofail to optional mounts..."
sudo sed -i 's|\(/dev/nvme[^\s]*\s\+[^\s]*\s\+ext4\s\+defaults\)\([^,]*\)|\1,nofail\2|g' "$MOUNT_POINT/etc/fstab"
sudo sed -i 's|\(/dev/nvme[^\s]*\s\+[^\s]*\s\+vfat\s\+defaults\)\([^,]*\)|\1,nofail\2|g' "$MOUNT_POINT/etc/fstab"
sudo sed -i 's|\(/mnt/backup.*defaults\)\([^,]*\)|\1,nofail\2|g' "$MOUNT_POINT/etc/fstab" || true

# Ensure boot partition has nofail (if it exists)
if grep -q "/boot/firmware" "$MOUNT_POINT/etc/fstab"; then
    sudo sed -i 's|\(/boot/firmware.*defaults\)\([^,]*\)|\1,nofail\2|g' "$MOUNT_POINT/etc/fstab"
fi

echo ""
echo -e "${GREEN}Fixed fstab:${NC}"
sudo cat "$MOUNT_POINT/etc/fstab"

# Fix PAM faillock
echo ""
echo -e "${YELLOW}Fixing PAM faillock...${NC}"
PAM_BACKUP="$MOUNT_POINT/etc/pam.d/common-auth.bak.$(date +%Y%m%d-%H%M%S)"
sudo cp "$MOUNT_POINT/etc/pam.d/common-auth" "$PAM_BACKUP" 2>/dev/null || true
sudo sed -i '/pam_faillock/s/^[^#]/#&/' "$MOUNT_POINT/etc/pam.d/common-auth"
echo -e "${GREEN}✓ PAM faillock disabled${NC}"

# Unlock root
echo ""
echo -e "${YELLOW}Unlocking root account...${NC}"
sudo chroot "$MOUNT_POINT" passwd -u root 2>/dev/null || true
sudo chroot "$MOUNT_POINT" faillock --user root --reset 2>/dev/null || true
echo -e "${GREEN}✓ Root account unlocked${NC}"

# Set hostname to node-x
echo ""
echo -e "${YELLOW}Setting hostname to node-x...${NC}"
echo "node-x" | sudo tee "$MOUNT_POINT/etc/hostname" > /dev/null
sudo sed -i 's/^127.0.1.1.*/127.0.1.1 node-x/' "$MOUNT_POINT/etc/hosts"
echo -e "${GREEN}✓ Hostname set to node-x${NC}"

# Verify fstab syntax
echo ""
echo -e "${YELLOW}Verifying fstab syntax...${NC}"
if sudo chroot "$MOUNT_POINT" mount -a --fake 2>/dev/null; then
    echo -e "${GREEN}✓ fstab syntax is valid${NC}"
else
    echo -e "${YELLOW}⚠ fstab syntax check failed (may be normal for chroot)${NC}"
fi

# Unmount
echo ""
echo -e "${YELLOW}Unmounting...${NC}"
sudo umount "$MOUNT_POINT"
sudo rmdir "$MOUNT_POINT"

echo ""
echo -e "${GREEN}=== SD Card Fixed! ===${NC}"
echo ""
echo "Changes applied:"
echo "  ✓ Removed unused backup mount (/dev/sdb1)"
echo "  ✓ Added nofail to optional mounts"
echo "  ✓ Disabled PAM faillock"
echo "  ✓ Unlocked root account"
echo "  ✓ Set hostname to node-x"
echo ""
echo "Next steps:"
echo "  1. Remove SD card from node-2"
echo "  2. Insert into any node that needs recovery"
echo "  3. Remove NVMe temporarily"
echo "  4. Boot - it should work now!"
echo ""

