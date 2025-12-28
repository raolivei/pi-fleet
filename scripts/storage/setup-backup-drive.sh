#!/bin/bash
set -e

# Script to set up the 2TB SanDisk Extreme drive as backup location
# This prepares the drive for backing up everything before NVMe boot setup

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Setup 2TB SanDisk Extreme Backup Drive ===${NC}"
echo ""

# Find the 2TB drive
echo -e "${YELLOW}[1/4] Detecting drives...${NC}"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE

echo ""
echo -e "${YELLOW}Looking for 2TB drive...${NC}"

# Find drives that are ~2TB (between 1.8TB and 2.2TB)
BACKUP_DEVICE=""
for dev in /dev/sd*; do
    if [ -b "$dev" ] && [ "$dev" != "/dev/sda" ]; then  # Exclude the 512GB SD card
        SIZE_BYTES=$(sudo blockdev --getsize64 "$dev" 2>/dev/null || echo "0")
        SIZE_TB=$(echo "scale=2; $SIZE_BYTES / 1024 / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "0")
        
        if (( $(echo "$SIZE_TB > 1.8" | bc -l 2>/dev/null || echo 0) )) && \
           (( $(echo "$SIZE_TB < 2.2" | bc -l 2>/dev/null || echo 0) )); then
            BACKUP_DEVICE="$dev"
            echo -e "${GREEN}✓ Found 2TB drive: $dev (${SIZE_TB}TB)${NC}"
            break
        fi
    fi
done

# If not found by size, check all non-sda devices
if [ -z "$BACKUP_DEVICE" ]; then
    echo -e "${YELLOW}Checking all USB devices...${NC}"
    for dev in /dev/sdb /dev/sdc /dev/sdd; do
        if [ -b "$dev" ]; then
            SIZE_BYTES=$(sudo blockdev --getsize64 "$dev" 2>/dev/null || echo "0")
            SIZE_GB=$(echo "scale=2; $SIZE_BYTES / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "0")
            echo "  $dev: ${SIZE_GB}GB"
            
            # If it's large enough (>= 1.5TB), assume it's the backup drive
            if (( $(echo "$SIZE_GB > 1500" | bc -l 2>/dev/null || echo 0) )); then
                BACKUP_DEVICE="$dev"
                echo -e "${GREEN}✓ Found large drive: $dev (${SIZE_GB}GB)${NC}"
                break
            fi
        fi
    done
fi

if [ -z "$BACKUP_DEVICE" ]; then
    echo -e "${RED}❌ 2TB SanDisk Extreme drive not found${NC}"
    echo ""
    echo "Please ensure:"
    echo "  1. Drive is plugged into USB port"
    echo "  2. Drive is powered on (if external power required)"
    echo "  3. Wait a few seconds for detection"
    echo ""
    echo "Available drives:"
    lsblk -o NAME,SIZE,TYPE
    exit 1
fi

# Check if it has partitions
echo ""
echo -e "${YELLOW}[2/4] Checking partitions...${NC}"
PARTITIONS=$(lsblk -n -o NAME "$BACKUP_DEVICE" | grep -v "^$(basename $BACKUP_DEVICE)$" | wc -l)

if [ "$PARTITIONS" -gt 0 ]; then
    echo "Drive has existing partitions:"
    lsblk "$BACKUP_DEVICE"
    echo ""
    read -p "This will erase all data on $BACKUP_DEVICE. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    # Unmount any existing partitions
    for part in $(lsblk -n -o NAME "$BACKUP_DEVICE" | grep -v "^$(basename $BACKUP_DEVICE)$"); do
        if mountpoint -q "/dev/$part" 2>/dev/null || mount | grep -q "/dev/$part"; then
            echo "Unmounting /dev/$part..."
            sudo umount "/dev/$part" 2>/dev/null || true
        fi
    done
fi

# Create partition table and partition
echo ""
echo -e "${YELLOW}[3/4] Creating partition...${NC}"
echo "Creating GPT partition table..."
sudo parted -s "$BACKUP_DEVICE" mklabel gpt

echo "Creating single partition using all space..."
sudo parted -s "$BACKUP_DEVICE" mkpart primary ext4 0% 100%

# Wait for partition to be available
sleep 2
sudo partprobe "$BACKUP_DEVICE"
sleep 2

# Format partition
PARTITION="${BACKUP_DEVICE}1"
echo "Formatting partition as ext4..."
sudo mkfs.ext4 -F -L "backup-drive" "$PARTITION"

echo -e "${GREEN}✓ Partition created and formatted${NC}"

# Mount the drive
echo ""
echo -e "${YELLOW}[4/4] Mounting backup drive...${NC}"
sudo mkdir -p /mnt/backup
sudo mount "$PARTITION" /mnt/backup
sudo chown raolivei:raolivei /mnt/backup

# Add to fstab for automatic mounting
echo "Adding to /etc/fstab for automatic mounting..."
UUID=$(sudo blkid -s UUID -o value "$PARTITION")
if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID /mnt/backup ext4 defaults,noatime,nofail 0 2" | sudo tee -a /etc/fstab
    echo -e "${GREEN}✓ Added to fstab${NC}"
else
    echo -e "${YELLOW}⚠️  Already in fstab${NC}"
fi

# Verify
echo ""
echo -e "${YELLOW}Verifying setup...${NC}"
df -h /mnt/backup
echo ""

# Test write
if sudo touch /mnt/backup/test-write && sudo rm /mnt/backup/test-write; then
    echo -e "${GREEN}✓ Write test successful${NC}"
else
    echo -e "${RED}❌ Write test failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo -e "${BLUE}Backup drive ready at: /mnt/backup${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Backup NVMe data: ~/backup-nvme.sh"
echo "  2. Setup boot from NVMe: ~/setup-nvme-boot.sh"
echo ""

