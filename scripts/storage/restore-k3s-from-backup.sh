#!/bin/bash
# Restore K3s cluster data from SD card backup
# Usage: ./restore-k3s-from-backup.sh <node-name>
# Example: ./restore-k3s-from-backup.sh node-1

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

echo -e "${BLUE}=== Restore K3s from Backup for $NODE_NAME ===${NC}"
echo ""

# Detect node role
if [ "$NODE_NAME" = "node-1" ]; then
    NODE_ROLE="control-plane"
    K3S_SERVICE="k3s"
elif [ "$NODE_NAME" = "node-1" ]; then
    NODE_ROLE="worker"
    K3S_SERVICE="k3s-agent"
else
    echo -e "${YELLOW}⚠️  Unknown node name, assuming control-plane${NC}"
    NODE_ROLE="control-plane"
    K3S_SERVICE="k3s"
fi

echo -e "${BLUE}Node Role: $NODE_ROLE${NC}"
echo ""

# SD card root partition
SD_ROOT="/dev/mmcblk0p2"
MOUNT_POINT="/mnt/sd-restore"

# Check SD card exists
if [ ! -b "$SD_ROOT" ]; then
    echo -e "${RED}❌ SD card not found at $SD_ROOT${NC}"
    exit 1
fi

# Mount SD card
echo -e "${YELLOW}[1/5] Mounting SD card...${NC}"
sudo mkdir -p "$MOUNT_POINT"
if ! mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    sudo mount "$SD_ROOT" "$MOUNT_POINT"
    MOUNTED=true
else
    MOUNTED=false
fi
echo -e "${GREEN}✓ SD card mounted${NC}"
echo ""

# Find backup directory
echo -e "${YELLOW}[2/5] Finding backup...${NC}"
BACKUP_DIR=""

# Look for migration backup
if [ -d "$MOUNT_POINT/nvme-migration-backup-"* ]; then
    BACKUP_DIR=$(ls -td "$MOUNT_POINT/nvme-migration-backup-"* 2>/dev/null | head -1)
    echo "  Found migration backup: $BACKUP_DIR"
    if [ -d "$BACKUP_DIR/k3s" ]; then
        echo -e "${GREEN}✓ K3s backup found${NC}"
    fi
# Check for direct K3s data on SD card
elif [ -d "$MOUNT_POINT/var/lib/rancher/k3s" ]; then
    BACKUP_DIR="$MOUNT_POINT"
    echo "  Found K3s data directly on SD card: $BACKUP_DIR/var/lib/rancher/k3s"
    echo -e "${GREEN}✓ K3s data found${NC}"
else
    echo -e "${RED}❌ No K3s backup found on SD card${NC}"
    if [ "$MOUNTED" = true ]; then
        sudo umount "$MOUNT_POINT"
    fi
    exit 1
fi

# Determine K3s source path
if [ -d "$BACKUP_DIR/k3s" ]; then
    K3S_SOURCE="$BACKUP_DIR/k3s"
elif [ -d "$BACKUP_DIR/var/lib/rancher/k3s" ]; then
    K3S_SOURCE="$BACKUP_DIR/var/lib/rancher/k3s"
else
    echo -e "${RED}❌ K3s data not found in backup${NC}"
    if [ "$MOUNTED" = true ]; then
        sudo umount "$MOUNT_POINT"
    fi
    exit 1
fi

K3S_SIZE=$(sudo du -sh "$K3S_SOURCE" 2>/dev/null | awk '{print $1}' || echo "unknown")
echo "  K3s data size: $K3S_SIZE"
echo ""

# Check if K3s is installed
echo -e "${YELLOW}[3/5] Checking K3s installation...${NC}"
if command -v k3s &> /dev/null || [ -f /usr/local/bin/k3s ]; then
    echo -e "${GREEN}✓ K3s is installed${NC}"
    K3S_INSTALLED=true
else
    echo -e "${YELLOW}⚠️  K3s not installed, will install first${NC}"
    K3S_INSTALLED=false
fi

# Stop K3s if running
if systemctl is-active --quiet "$K3S_SERVICE" 2>/dev/null; then
    echo -e "${YELLOW}[4/5] Stopping K3s service...${NC}"
    sudo systemctl stop "$K3S_SERVICE"
    echo -e "${GREEN}✓ K3s service stopped${NC}"
else
    echo -e "${YELLOW}[4/5] K3s service not running${NC}"
fi
echo ""

# Restore K3s data
echo -e "${YELLOW}[5/5] Restoring K3s data...${NC}"
K3S_TARGET="/var/lib/rancher/k3s"

# Create target directory
sudo mkdir -p "$K3S_TARGET"

# Backup existing data if it exists
if [ -d "$K3S_TARGET" ] && [ "$(ls -A $K3S_TARGET 2>/dev/null)" ]; then
    BACKUP_EXISTING="$K3S_TARGET.backup-$(date +%Y%m%d-%H%M%S)"
    echo "  Backing up existing data to: $BACKUP_EXISTING"
    sudo mv "$K3S_TARGET" "$BACKUP_EXISTING"
    sudo mkdir -p "$K3S_TARGET"
fi

# Restore data
echo "  Copying from: $K3S_SOURCE"
echo "  Copying to: $K3S_TARGET"
echo "  This may take a few minutes..."

sudo rsync -aAXHv --info=progress2 \
    --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*"} \
    "$K3S_SOURCE/" "$K3S_TARGET/"

echo -e "${GREEN}✓ K3s data restored${NC}"
echo ""

# Set correct permissions
echo "  Setting permissions..."
sudo chown -R root:root "$K3S_TARGET"
sudo chmod -R 755 "$K3S_TARGET"
echo -e "${GREEN}✓ Permissions set${NC}"
echo ""

# Unmount SD card
if [ "$MOUNTED" = true ]; then
    sudo umount "$MOUNT_POINT"
    rmdir "$MOUNT_POINT" 2>/dev/null || true
fi

echo -e "${GREEN}=== Restore Complete ===${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Start K3s service: sudo systemctl start $K3S_SERVICE"
echo "  2. Check status: sudo systemctl status $K3S_SERVICE"
echo "  3. Verify cluster: kubectl get nodes (if on control plane)"
echo ""

