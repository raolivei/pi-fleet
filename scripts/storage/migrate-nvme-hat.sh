#!/bin/bash
# Migrate from old NVMe HAT to new M.2 NVMe M-key & PoE+ HAT
# Preserves boot partition, OS, and K3s cluster data
# Usage: ./migrate-nvme-hat.sh <node-name>
# Example: ./migrate-nvme-hat.sh node-1

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NODE_NAME="${1:-}"
if [ -z "$NODE_NAME" ]; then
    echo -e "${RED}❌ Error: Node name required${NC}"
    echo "Usage: $0 <node-name>"
    echo "Example: $0 node-1"
    exit 1
fi

echo -e "${BLUE}=== NVMe HAT Migration for $NODE_NAME ===${NC}"
echo ""

# Detect if running on control plane or worker
if systemctl is-active --quiet k3s 2>/dev/null; then
    NODE_ROLE="control-plane"
    K3S_SERVICE="k3s"
elif systemctl is-active --quiet k3s-agent 2>/dev/null; then
    NODE_ROLE="worker"
    K3S_SERVICE="k3s-agent"
else
    NODE_ROLE="unknown"
    K3S_SERVICE=""
fi

echo -e "${BLUE}Node Role: $NODE_ROLE${NC}"
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
    echo "  Please ensure new HAT and NVMe are installed"
    exit 1
fi

echo -e "${GREEN}✓ Devices found${NC}"
echo "  SD Card: $SD_CARD"
echo "  NVMe: $NVME_DEVICE"
echo ""

# Check new NVMe size (should be ~128GB)
NVME_SIZE=$(blockdev --getsize64 "$NVME_DEVICE")
NVME_SIZE_GB=$((NVME_SIZE / 1024 / 1024 / 1024))
echo -e "${BLUE}New NVMe size: ${NVME_SIZE_GB}GB${NC}"

if [ "$NVME_SIZE_GB" -lt 100 ] || [ "$NVME_SIZE_GB" -gt 150 ]; then
    echo -e "${YELLOW}⚠️  Warning: NVMe size (${NVME_SIZE_GB}GB) doesn't match expected 128GB${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Determine source for migration
# After hardware replacement, we'll be booting from SD card, so always use SD as source
CURRENT_ROOT=$(df -h / | tail -1 | awk '{print $1}')
echo -e "${BLUE}Current root filesystem: $CURRENT_ROOT${NC}"

# Check if we're currently booting from old NVMe
if [[ "$CURRENT_ROOT" == *"nvme0n1"* ]]; then
    echo -e "${YELLOW}⚠️  Currently booting from old NVMe${NC}"
    echo "  After hardware replacement, you'll boot from SD card"
    echo "  This script will clone from SD card to new NVMe"
    echo ""
    
    # Check if SD card has bootable partitions
    if [ ! -b "$BOOT_PARTITION" ] || [ ! -b "$ROOT_PARTITION" ]; then
        echo -e "${RED}❌ SD card partitions not found${NC}"
        echo "  Boot: $BOOT_PARTITION"
        echo "  Root: $ROOT_PARTITION"
        echo "  Please ensure SD card has bootable OS before hardware replacement"
        exit 1
    fi
    
    # Verify SD card has OS
    if ! mountpoint -q /boot/firmware 2>/dev/null; then
        # Try to mount SD boot to check
        TEMP_MOUNT="/tmp/sd-boot-check-$$"
        sudo mkdir -p "$TEMP_MOUNT"
        if sudo mount "$BOOT_PARTITION" "$TEMP_MOUNT" 2>/dev/null; then
            if [ -f "$TEMP_MOUNT/cmdline.txt" ]; then
                echo -e "${GREEN}✓ SD card has bootable OS${NC}"
            else
                echo -e "${YELLOW}⚠️  SD card boot partition may not be bootable${NC}"
            fi
            sudo umount "$TEMP_MOUNT"
            rmdir "$TEMP_MOUNT"
        fi
    fi
fi

# After hardware replacement, we'll always use SD card as source
SOURCE_TYPE="SD"
SOURCE_BOOT="$BOOT_PARTITION"
SOURCE_ROOT="$ROOT_PARTITION"

echo -e "${BLUE}Migration source: $SOURCE_TYPE${NC}"
echo "  Boot: $SOURCE_BOOT"
echo "  Root: $SOURCE_ROOT"
echo ""

# Check if K3s is running
if [ -n "$K3S_SERVICE" ] && systemctl is-active --quiet "$K3S_SERVICE" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  K3s ($K3S_SERVICE) is running. We'll stop it during migration.${NC}"
    K3S_RUNNING=true
else
    K3S_RUNNING=false
fi
echo ""

# Check if new NVMe already has partitions
if [ -b "$NVME_BOOT" ] || [ -b "$NVME_ROOT" ]; then
    echo -e "${YELLOW}⚠️  New NVMe already has partitions${NC}"
    lsblk "$NVME_DEVICE"
    echo ""
    read -p "This will erase all data on new NVMe. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Stop K3s if running
if [ "$K3S_RUNNING" = true ]; then
    echo -e "${YELLOW}[1/8] Stopping K3s...${NC}"
    sudo systemctl stop "$K3S_SERVICE"
    sleep 2
    echo -e "${GREEN}✓ K3s stopped${NC}"
    echo ""
fi

# Unmount new NVMe if mounted
echo -e "${YELLOW}[2/8] Unmounting new NVMe if mounted...${NC}"
for mount in $(mount | grep "$NVME_DEVICE" | awk '{print $3}'); do
    sudo umount "$mount" 2>/dev/null || true
done
echo -e "${GREEN}✓ NVMe unmounted${NC}"
echo ""

# Create partition table on new NVMe
echo -e "${YELLOW}[3/8] Creating partitions on new NVMe...${NC}"
echo "  Creating GPT partition table..."
sudo parted -s "$NVME_DEVICE" mklabel gpt

# Calculate partition sizes (boot = 1GB to be safe, rest for root)
# Check actual boot partition size first
if [ -b "$SOURCE_BOOT" ]; then
    SOURCE_BOOT_SIZE=$(sudo blockdev --getsize64 "$SOURCE_BOOT" 2>/dev/null || echo "536870912")
    SOURCE_BOOT_SIZE_MB=$((SOURCE_BOOT_SIZE / 1024 / 1024))
    # Use source size + 10% buffer, minimum 512MB, maximum 2GB
    BOOT_SIZE_MB=$((SOURCE_BOOT_SIZE_MB + SOURCE_BOOT_SIZE_MB / 10))
    if [ "$BOOT_SIZE_MB" -lt 512 ]; then
        BOOT_SIZE_MB=512
    elif [ "$BOOT_SIZE_MB" -gt 2048 ]; then
        BOOT_SIZE_MB=2048
    fi
else
    BOOT_SIZE_MB=1024  # Default 1GB
fi
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

# Clone boot partition
echo -e "${YELLOW}[4/8] Cloning boot partition...${NC}"
echo "  Source: $SOURCE_BOOT"
echo "  Target: $NVME_BOOT"
echo "  This may take a few minutes..."
sudo dd if="$SOURCE_BOOT" of="$NVME_BOOT" bs=4M status=progress conv=fsync
sudo sync
echo -e "${GREEN}✓ Boot partition cloned${NC}"
echo ""

# Mount new boot partition to update cmdline.txt
echo -e "${YELLOW}[5/8] Updating boot configuration...${NC}"
sudo mkdir -p /mnt/new-boot
sudo mount "$NVME_BOOT" /mnt/new-boot

# Update cmdline.txt
if [ -f /mnt/new-boot/cmdline.txt ]; then
    sudo cp /mnt/new-boot/cmdline.txt /mnt/new-boot/cmdline.txt.bak.$(date +%Y%m%d-%H%M%S)
    sudo sed -i.bak "s|root=[^ ]*|root=$NVME_ROOT|g" /mnt/new-boot/cmdline.txt
    echo -e "${GREEN}✓ cmdline.txt updated${NC}"
    echo "  Content:"
    cat /mnt/new-boot/cmdline.txt | sed 's/^/    /'
else
    echo -e "${YELLOW}⚠️  cmdline.txt not found, creating default...${NC}"
    echo "console=serial0,115200 console=tty1 root=$NVME_ROOT rootfstype=ext4 fsck.repair=yes rootwait quiet init=/usr/lib/raspberrypi-sys-mods/first-boot" | sudo tee /mnt/new-boot/cmdline.txt
fi

sudo umount /mnt/new-boot
rmdir /mnt/new-boot
echo ""

# Clone root filesystem
echo -e "${YELLOW}[6/8] Cloning root filesystem...${NC}"
echo "  Source: $SOURCE_ROOT"
echo "  Target: $NVME_ROOT"
echo "  This is the longest step (10-30 minutes)..."
echo "  Preserving K3s data and all configurations..."

# Use rsync for better data preservation
sudo mkdir -p /mnt/source-root /mnt/new-root
sudo mount "$SOURCE_ROOT" /mnt/source-root
sudo mount "$NVME_ROOT" /mnt/new-root

# Clone with rsync, excluding some directories
sudo rsync -aAXHv --info=progress2 \
    --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} \
    /mnt/source-root/ /mnt/new-root/

# Update fstab on new root
echo -e "${YELLOW}[7/8] Updating fstab...${NC}"
if [ -f /mnt/new-root/etc/fstab ]; then
    sudo cp /mnt/new-root/etc/fstab /mnt/new-root/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)
    sudo sed -i.bak "s|/dev/mmcblk0p1|$NVME_BOOT|g" /mnt/new-root/etc/fstab
    sudo sed -i.bak "s|/dev/mmcblk0p2|$NVME_ROOT|g" /mnt/new-root/etc/fstab
    # Update any old NVMe references
    sudo sed -i.bak "s|/dev/nvme0n1p1|$NVME_BOOT|g" /mnt/new-root/etc/fstab
    sudo sed -i.bak "s|/dev/nvme0n1p2|$NVME_ROOT|g" /mnt/new-root/etc/fstab
    echo -e "${GREEN}✓ fstab updated${NC}"
    echo "  Content:"
    cat /mnt/new-root/etc/fstab | sed 's/^/    /'
fi

# Verify K3s data preservation
if [ -d /mnt/new-root/var/lib/rancher/k3s ]; then
    echo -e "${GREEN}✓ K3s data preserved${NC}"
    echo "  Location: /mnt/new-root/var/lib/rancher/k3s"
    ls -la /mnt/new-root/var/lib/rancher/k3s | head -5 | sed 's/^/    /'
fi

sudo umount /mnt/new-root
sudo umount /mnt/source-root
rmdir /mnt/new-root /mnt/source-root
echo ""

# Final sync
echo -e "${YELLOW}[8/8] Finalizing...${NC}"
sudo sync
echo -e "${GREEN}✓ Migration complete${NC}"
echo ""

# Restart K3s if it was running
if [ "$K3S_RUNNING" = true ]; then
    echo -e "${YELLOW}Restarting K3s...${NC}"
    sudo systemctl start "$K3S_SERVICE"
    sleep 5
    if systemctl is-active --quiet "$K3S_SERVICE" 2>/dev/null; then
        echo -e "${GREEN}✓ K3s restarted${NC}"
    else
        echo -e "${YELLOW}⚠️  K3s may need manual restart after reboot${NC}"
    fi
fi

echo ""
echo -e "${GREEN}=== Migration Complete ===${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Reboot: sudo reboot"
echo "  2. System should boot from new NVMe"
echo "  3. Verify: df -h / (should show $NVME_ROOT)"
echo "  4. Check K3s: sudo systemctl status $K3S_SERVICE"
echo ""
echo -e "${BLUE}Note:${NC} SD card remains as backup boot option"
echo ""
echo -e "${BLUE}Secure Erase Old Drive:${NC}"
echo "  After verifying migration, you can securely erase the old 256GB drive:"
echo "  sudo ./secure-erase-old-nvme.sh /dev/nvme0n1"
echo "  (Replace device path if old drive is on different device)"
echo ""

