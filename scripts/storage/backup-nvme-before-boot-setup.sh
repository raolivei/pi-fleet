#!/bin/bash
set -e

# Script to backup NVMe data before setting up boot from NVMe
# This backs up data to USB backup drive or another location

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Backup NVMe Data Before Boot Setup ===${NC}"
echo ""

NVME_MOUNT="/mnt/nvme"
BACKUP_LOCATION="${1:-/mnt/backup/nvme-backup-$(date +%Y%m%d-%H%M%S)}"

# Check if NVMe is mounted
if ! mountpoint -q "$NVME_MOUNT" 2>/dev/null; then
    echo -e "${RED}❌ NVMe is not mounted at $NVME_MOUNT${NC}"
    exit 1
fi

# Check backup location (prioritize backup SD card if mounted)
if [ -d "/mnt/backup-sd" ] && mountpoint -q /mnt/backup-sd 2>/dev/null; then
    echo -e "${GREEN}✓ Backup SD card found at /mnt/backup-sd${NC}"
    BACKUP_BASE="/mnt/backup-sd"
elif [ -d "/mnt/backup" ] && mountpoint -q /mnt/backup 2>/dev/null; then
    echo -e "${GREEN}✓ USB backup drive found at /mnt/backup${NC}"
    BACKUP_BASE="/mnt/backup"
elif [ -d "/mnt" ]; then
    echo -e "${YELLOW}⚠️  No backup drive found, using /mnt/nvme-backup${NC}"
    BACKUP_BASE="/mnt"
else
    echo -e "${RED}❌ No suitable backup location found${NC}"
    echo "Please mount a backup drive or specify backup location:"
    echo "  $0 /path/to/backup"
    exit 1
fi

# Allow user to specify backup location, or use default
if [ -n "$1" ] && [ -d "$(dirname "$1")" ]; then
    BACKUP_LOCATION="$1"
else
    BACKUP_LOCATION="$BACKUP_BASE/nvme-backup-$(date +%Y%m%d-%H%M%S)"
fi

echo ""
echo -e "${BLUE}Backup Configuration:${NC}"
echo "  Source: $NVME_MOUNT"
echo "  Destination: $BACKUP_LOCATION"
echo ""

# Check what will be backed up
echo -e "${YELLOW}Data to backup:${NC}"
sudo du -sh "$NVME_MOUNT"/* 2>/dev/null | while read size path; do
    echo "  $size - $(basename $path)"
done

TOTAL_SIZE=$(sudo du -sb "$NVME_MOUNT" 2>/dev/null | awk '{print $1}')
echo ""
echo "  Total: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE)"
echo ""

# Check available space
if [ -d "$BACKUP_BASE" ]; then
    AVAILABLE=$(df -B1 "$BACKUP_BASE" | tail -1 | awk '{print $4}')
    echo -e "${BLUE}Available space: $(numfmt --to=iec-i --suffix=B $AVAILABLE)${NC}"
    
    if [ "$AVAILABLE" -lt "$TOTAL_SIZE" ]; then
        echo -e "${RED}❌ Not enough space for backup${NC}"
        echo "  Required: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE)"
        echo "  Available: $(numfmt --to=iec-i --suffix=B $AVAILABLE)"
        exit 1
    fi
fi

echo ""
read -p "Proceed with backup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Create backup directory
echo ""
echo -e "${YELLOW}Creating backup directory...${NC}"
sudo mkdir -p "$BACKUP_LOCATION"
sudo chown $USER:$USER "$BACKUP_LOCATION"

# Backup data
echo -e "${YELLOW}Backing up data...${NC}"
echo "This may take a while depending on data size..."
echo ""

# Use rsync for efficient copying
sudo rsync -avh --progress "$NVME_MOUNT/" "$BACKUP_LOCATION/" \
    --exclude='lost+found' \
    --exclude='*.tmp' \
    --exclude='.Trash-*'

# Create backup manifest
echo ""
echo -e "${YELLOW}Creating backup manifest...${NC}"
sudo find "$NVME_MOUNT" -type f -exec ls -lh {} \; > "$BACKUP_LOCATION/backup-manifest.txt" 2>/dev/null || true
sudo chown $USER:$USER "$BACKUP_LOCATION/backup-manifest.txt"

# Verify backup
echo ""
echo -e "${YELLOW}Verifying backup...${NC}"
BACKUP_SIZE=$(sudo du -sb "$BACKUP_LOCATION" 2>/dev/null | awk '{print $1}')
if [ "$BACKUP_SIZE" -gt 0 ]; then
    echo -e "${GREEN}✓ Backup completed${NC}"
    echo "  Backup size: $(numfmt --to=iec-i --suffix=B $BACKUP_SIZE)"
    echo "  Location: $BACKUP_LOCATION"
    echo ""
    echo -e "${GREEN}=== Backup Complete ===${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Verify backup: ls -lh $BACKUP_LOCATION"
    echo "  2. Run boot setup: ~/setup-nvme-boot.sh"
    echo "  3. After boot from NVMe, restore data if needed"
else
    echo -e "${RED}❌ Backup verification failed${NC}"
    exit 1
fi

