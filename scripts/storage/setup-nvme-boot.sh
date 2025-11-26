#!/bin/bash
set -e

# Script to configure Raspberry Pi 5 to boot from NVMe
# This clones the current OS from SD card to NVMe and configures boot

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Raspberry Pi 5 NVMe Boot Setup ===${NC}"
echo ""

# Check if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo -e "${RED}❌ This script must be run on a Raspberry Pi${NC}"
    exit 1
fi

# Check if Raspberry Pi 5
if ! grep -q "Raspberry Pi 5" /proc/device-tree/model 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Warning: This script is designed for Raspberry Pi 5${NC}"
    echo "NVMe boot support may vary on other models"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Device paths
SD_CARD="/dev/mmcblk0"
NVME_DEVICE="/dev/nvme0n1"
BOOT_PARTITION="${SD_CARD}p1"
ROOT_PARTITION="${SD_CARD}p2"

# Check if devices exist
if [ ! -b "$SD_CARD" ]; then
    echo -e "${RED}❌ SD card not found at $SD_CARD${NC}"
    exit 1
fi

if [ ! -b "$NVME_DEVICE" ]; then
    echo -e "${RED}❌ NVMe device not found at $NVME_DEVICE${NC}"
    exit 1
fi

echo -e "${BLUE}Current Setup:${NC}"
echo "  SD Card: $SD_CARD"
echo "  NVMe: $NVME_DEVICE"
echo ""

# Check current NVMe status
echo -e "${YELLOW}[1/7] Checking NVMe status...${NC}"
NVME_PARTITIONS=$(lsblk -n -o NAME "$NVME_DEVICE" | grep -v "^nvme0n1$" | wc -l)
if [ "$NVME_PARTITIONS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  NVMe already has partitions${NC}"
    lsblk "$NVME_DEVICE"
    echo ""
    read -p "This will erase all data on NVMe. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Check if K3s is running
echo -e "${YELLOW}[2/7] Checking K3s status...${NC}"
if systemctl is-active --quiet k3s; then
    echo -e "${YELLOW}⚠️  K3s is running. We'll stop it during the process.${NC}"
    K3S_RUNNING=true
else
    K3S_RUNNING=false
fi
echo ""

# Backup warning
echo -e "${RED}⚠️  WARNING: This will:${NC}"
echo "  1. Erase all data on NVMe device"
echo "  2. Clone OS from SD card to NVMe"
echo "  3. Configure boot from NVMe"
echo "  4. Keep SD card as backup boot option"
echo ""
read -p "Have you backed up important data? Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Get partition sizes
echo -e "${YELLOW}[3/7] Analyzing partitions...${NC}"
BOOT_SIZE=$(parted -s "$SD_CARD" unit B print | grep "^ 1" | awk '{print $3}' | sed 's/B$//')
ROOT_SIZE=$(parted -s "$SD_CARD" unit B print | grep "^ 2" | awk '{print $3}' | sed 's/B$//')
NVME_SIZE=$(blockdev --getsize64 "$NVME_DEVICE")

echo "  Boot partition size: $(numfmt --to=iec-i --suffix=B $BOOT_SIZE)"
echo "  Root partition size: $(numfmt --to=iec-i --suffix=B $ROOT_SIZE)"
echo "  NVMe size: $(numfmt --to=iec-i --suffix=B $NVME_SIZE)"
echo ""

# Check if NVMe is large enough
REQUIRED_SIZE=$((BOOT_SIZE + ROOT_SIZE + 1048576000)) # Add 1GB buffer
if [ "$NVME_SIZE" -lt "$REQUIRED_SIZE" ]; then
    echo -e "${RED}❌ NVMe is too small${NC}"
    echo "  Required: $(numfmt --to=iec-i --suffix=B $REQUIRED_SIZE)"
    echo "  Available: $(numfmt --to=iec-i --suffix=B $NVME_SIZE)"
    exit 1
fi

# Stop K3s if running
if [ "$K3S_RUNNING" = true ]; then
    echo -e "${YELLOW}[4/7] Stopping K3s...${NC}"
    sudo systemctl stop k3s
    sleep 2
fi

# Unmount NVMe if mounted
echo -e "${YELLOW}[5/7] Unmounting NVMe if mounted...${NC}"
if mountpoint -q /mnt/nvme 2>/dev/null; then
    sudo umount /mnt/nvme
fi
# Unmount any other NVMe mounts
for mount in $(mount | grep "$NVME_DEVICE" | awk '{print $3}'); do
    sudo umount "$mount" 2>/dev/null || true
done
echo -e "${GREEN}✓ NVMe unmounted${NC}"
echo ""

# Create partition table on NVMe
echo -e "${YELLOW}[6/7] Creating partitions on NVMe...${NC}"
echo "  Creating GPT partition table..."
sudo parted -s "$NVME_DEVICE" mklabel gpt

# Calculate partition sizes (boot = 512MB, rest for root)
BOOT_SIZE_MB=512
ROOT_START_MB=$((BOOT_SIZE_MB + 1))

echo "  Creating boot partition (${BOOT_SIZE_MB}MB)..."
sudo parted -s "$NVME_DEVICE" mkpart primary fat32 1MiB ${BOOT_SIZE_MB}MiB
sudo parted -s "$NVME_DEVICE" set 1 esp on  # Set EFI System Partition flag

echo "  Creating root partition (remaining space)..."
sudo parted -s "$NVME_DEVICE" mkpart primary ext4 ${ROOT_START_MB}MiB 100%

# Wait for partitions to be available
sleep 2
sudo partprobe "$NVME_DEVICE"
sleep 2

# Format partitions
echo "  Formatting boot partition..."
sudo mkfs.vfat -F 32 -n BOOT "${NVME_DEVICE}p1"

echo "  Formatting root partition..."
sudo mkfs.ext4 -F -L rootfs "${NVME_DEVICE}p2"

echo -e "${GREEN}✓ Partitions created and formatted${NC}"
echo ""

# Clone partitions
echo -e "${YELLOW}[7/7] Cloning OS from SD card to NVMe...${NC}"
echo "  This may take 10-30 minutes depending on SD card speed..."
echo ""

# Clone boot partition
echo "  Cloning boot partition..."
sudo dd if="$BOOT_PARTITION" of="${NVME_DEVICE}p1" bs=4M status=progress conv=fsync
sudo sync

# Clone root partition
echo ""
echo "  Cloning root partition (this is the longest step)..."
sudo dd if="$ROOT_PARTITION" of="${NVME_DEVICE}p2" bs=4M status=progress conv=fsync
sudo sync

echo -e "${GREEN}✓ OS cloned to NVMe${NC}"
echo ""

# Mount NVMe root to update fstab and boot config
echo -e "${YELLOW}Configuring boot settings...${NC}"
sudo mkdir -p /mnt/nvme-root
sudo mount "${NVME_DEVICE}p2" /mnt/nvme-root

# Update fstab to use NVMe partitions
echo "  Updating /etc/fstab on NVMe..."
sudo sed -i.bak "s|$BOOT_PARTITION|${NVME_DEVICE}p1|g" /mnt/nvme-root/etc/fstab
sudo sed -i.bak "s|$ROOT_PARTITION|${NVME_DEVICE}p2|g" /mnt/nvme-root/etc/fstab

# Update cmdline.txt to boot from NVMe
echo "  Updating boot configuration..."
sudo mkdir -p /mnt/nvme-boot
sudo mount "${NVME_DEVICE}p1" /mnt/nvme-boot

# Copy current cmdline.txt and update root partition
if [ -f /mnt/nvme-boot/cmdline.txt ]; then
    sudo sed -i.bak "s|root=$ROOT_PARTITION|root=${NVME_DEVICE}p2|g" /mnt/nvme-boot/cmdline.txt
    sudo sed -i.bak "s|root=PARTUUID=[^ ]*|root=${NVME_DEVICE}p2|g" /mnt/nvme-boot/cmdline.txt
fi

# Unmount
sudo umount /mnt/nvme-boot
sudo umount /mnt/nvme-root

echo -e "${GREEN}✓ Boot configuration updated${NC}"
echo ""

# Configure Raspberry Pi 5 to boot from NVMe
echo -e "${YELLOW}Configuring Raspberry Pi 5 boot order...${NC}"
echo ""
echo -e "${BLUE}For Raspberry Pi 5, boot order is configured via:${NC}"
echo "  1. Boot order priority (NVMe > USB > SD card by default on Pi 5)"
echo "  2. Or via rpi-eeprom-config"
echo ""

# Check current boot order
if [ -f /boot/firmware/config.txt ]; then
    echo "Current boot configuration:"
    grep -E "boot_order|priority" /boot/firmware/config.txt || echo "  (using default boot order)"
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Reboot the Pi: sudo reboot"
echo "  2. The Pi should boot from NVMe automatically (Pi 5 supports this natively)"
echo "  3. Verify boot source: lsblk (root should be on ${NVME_DEVICE}p2)"
echo "  4. If boot fails, remove NVMe and boot from SD card, then check logs"
echo ""
echo -e "${BLUE}Boot order on Raspberry Pi 5:${NC}"
echo "  - Pi 5 automatically tries NVMe first if present"
echo "  - Falls back to SD card if NVMe boot fails"
echo "  - SD card remains as backup boot option"
echo ""

# Restart K3s if it was running
if [ "$K3S_RUNNING" = true ]; then
    echo -e "${YELLOW}Restarting K3s...${NC}"
    sudo systemctl start k3s
    sleep 5
    if systemctl is-active --quiet k3s; then
        echo -e "${GREEN}✓ K3s restarted${NC}"
    else
        echo -e "${YELLOW}⚠️  K3s may need manual restart after reboot${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Ready to reboot!${NC}"

