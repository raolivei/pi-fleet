#!/bin/bash
# Pre-migration backup - Run BEFORE hardware replacement
# Backs up K3s data and critical configs from old NVMe to SD card
# Usage: ./pre-migration-backup.sh <node-name>

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

echo -e "${BLUE}=== Pre-Migration Backup for $NODE_NAME ===${NC}"
echo ""

# Check current boot device
CURRENT_ROOT=$(df -h / | tail -1 | awk '{print $1}')
echo -e "${BLUE}Current root: $CURRENT_ROOT${NC}"

if [[ "$CURRENT_ROOT" != *"nvme0n1"* ]]; then
    echo -e "${YELLOW}⚠️  Not currently booting from NVMe${NC}"
    echo "  This script is for backing up data before replacing NVMe hardware"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Backup directory on SD card
BACKUP_DIR="/mnt/sd-backup"
SD_ROOT="/dev/mmcblk0p2"

# Check SD card
if [ ! -b "$SD_ROOT" ]; then
    echo -e "${RED}❌ SD card root partition not found at $SD_ROOT${NC}"
    exit 1
fi

# Mount SD card root
echo -e "${YELLOW}[1/4] Mounting SD card...${NC}"
sudo mkdir -p "$BACKUP_DIR"
if ! mountpoint -q "$BACKUP_DIR" 2>/dev/null; then
    sudo mount "$SD_ROOT" "$BACKUP_DIR"
    MOUNTED=true
else
    MOUNTED=false
fi

# Create backup directory
BACKUP_PATH="$BACKUP_DIR/nvme-migration-backup-$(date +%Y%m%d-%H%M%S)"
sudo mkdir -p "$BACKUP_PATH"
echo -e "${GREEN}✓ SD card mounted${NC}"
echo "  Backup location: $BACKUP_PATH"
echo ""

# Backup K3s data
echo -e "${YELLOW}[2/4] Backing up K3s data...${NC}"
if [ -d /var/lib/rancher/k3s ]; then
    K3S_SIZE=$(du -sh /var/lib/rancher/k3s 2>/dev/null | awk '{print $1}' || echo "unknown")
    echo "  K3s data size: $K3S_SIZE"
    echo "  Copying to backup..."
    
    sudo mkdir -p "$BACKUP_PATH/k3s"
    sudo rsync -aAXHv --info=progress2 \
        --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*"} \
        /var/lib/rancher/k3s/ "$BACKUP_PATH/k3s/"
    
    echo -e "${GREEN}✓ K3s data backed up${NC}"
else
    echo -e "${YELLOW}⚠️  K3s data directory not found${NC}"
fi
echo ""

# Backup critical configs
echo -e "${YELLOW}[3/4] Backing up critical configurations...${NC}"
sudo mkdir -p "$BACKUP_PATH/configs"

# Backup fstab
if [ -f /etc/fstab ]; then
    sudo cp /etc/fstab "$BACKUP_PATH/configs/fstab"
    echo "  ✓ fstab"
fi

# Backup network configs
if [ -d /etc/netplan ]; then
    sudo cp -r /etc/netplan "$BACKUP_PATH/configs/" 2>/dev/null || true
    echo "  ✓ netplan"
fi

# Backup SSH keys
if [ -d /etc/ssh ]; then
    sudo cp -r /etc/ssh "$BACKUP_PATH/configs/" 2>/dev/null || true
    echo "  ✓ SSH config"
fi

# Backup hostname
if [ -f /etc/hostname ]; then
    sudo cp /etc/hostname "$BACKUP_PATH/configs/"
    echo "  ✓ hostname"
fi

echo -e "${GREEN}✓ Configurations backed up${NC}"
echo ""

# Create backup manifest
echo -e "${YELLOW}[4/4] Creating backup manifest...${NC}"
MANIFEST_FILE="$BACKUP_PATH/backup-manifest.txt"
{
    echo "Backup created: $(date)"
    echo "Node: $NODE_NAME"
    echo "Source root: $CURRENT_ROOT"
    echo ""
    echo "K3s data:"
    if [ -d "$BACKUP_PATH/k3s" ]; then
        du -sh "$BACKUP_PATH/k3s" | awk '{print "  " $0}'
    else
        echo "  (not found)"
    fi
    echo ""
    echo "Configurations:"
    ls -lh "$BACKUP_PATH/configs/" 2>/dev/null | tail -n +2 | awk '{print "  " $0}' || echo "  (none)"
} | sudo tee "$MANIFEST_FILE" > /dev/null

echo -e "${GREEN}✓ Backup manifest created${NC}"
echo ""

# Unmount if we mounted it
if [ "$MOUNTED" = true ]; then
    sudo umount "$BACKUP_DIR"
fi

echo -e "${GREEN}=== Backup Complete ===${NC}"
echo ""
echo -e "${YELLOW}Backup location: $BACKUP_PATH${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Power down this node: sudo poweroff"
echo "  2. Replace HAT and NVMe hardware"
echo "  3. Boot from SD card"
echo "  4. Run migration script: ./migrate-nvme-hat.sh $NODE_NAME"
echo ""

