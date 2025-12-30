#!/bin/bash
# SanDisk Extreme SD Drive Backup Setup for Longhorn
# Automates mounting, NFS server setup, and Longhorn backup target configuration

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BACKUP_MOUNT="/mnt/longhorn-backup"
BACKUP_LABEL="longhorn-backup"

echo "=== SanDisk Extreme SD Drive Backup Setup ==="
echo ""
echo "This script will:"
echo "1. Detect and identify the SanDisk Extreme SD drive"
echo "2. Format the drive (if needed)"
echo "3. Mount the drive to $BACKUP_MOUNT"
echo "4. Install and configure NFS server"
echo "5. Configure Longhorn backup target"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
    exit 1
fi

# 1. Detect SD drive
echo "1️⃣ Detecting SanDisk Extreme SD drive..."
echo ""
echo "Available block devices:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL
echo ""

read -p "Enter the device name (e.g., sda, sdb, mmcblk1): " DEVICE_INPUT
DEVICE="/dev/${DEVICE_INPUT}"

# Validate device exists
if [ ! -b "$DEVICE" ]; then
    echo -e "${RED}❌ Device $DEVICE not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Device $DEVICE found${NC}"

# Check if device has partitions
PARTITIONS=$(lsblk -ln -o NAME "$DEVICE" | tail -n +2 | wc -l)
if [ "$PARTITIONS" -gt 0 ]; then
    echo "   Device has partitions. Checking..."
    FIRST_PARTITION="${DEVICE}1"
    if [ -b "$FIRST_PARTITION" ]; then
        echo "   Using first partition: $FIRST_PARTITION"
        DEVICE="$FIRST_PARTITION"
    else
        echo -e "${YELLOW}⚠️  No partition found, using whole device${NC}"
    fi
fi

# 2. Check if device is mounted
if mountpoint -q "$DEVICE" 2>/dev/null || findmnt "$DEVICE" &>/dev/null; then
    CURRENT_MOUNT=$(findmnt -n -o TARGET "$DEVICE" 2>/dev/null || echo "unknown")
    echo -e "${YELLOW}⚠️  Device is already mounted at: $CURRENT_MOUNT${NC}"
    read -p "Unmount and continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        umount "$DEVICE" 2>/dev/null || true
        echo -e "${GREEN}✅ Device unmounted${NC}"
    else
        echo "Exiting..."
        exit 1
    fi
fi

# 3. Format device (if needed)
echo ""
echo "2️⃣ Checking filesystem..."
FSTYPE=$(blkid -o value -s TYPE "$DEVICE" 2>/dev/null || echo "none")

if [ "$FSTYPE" = "ext4" ]; then
    echo -e "${GREEN}✅ Device already formatted as ext4${NC}"
    read -p "Reformat? (y/N): " -n 1 -r
    echo
    REFORMAT=$REPLY
else
    echo -e "${YELLOW}⚠️  Device filesystem: ${FSTYPE:-none}${NC}"
    read -p "Format as ext4? (y/N): " -n 1 -r
    echo
    REFORMAT=$REPLY
fi

if [[ $REFORMAT =~ ^[Yy]$ ]]; then
    echo "   Formatting $DEVICE as ext4..."
    echo -e "${RED}⚠️  WARNING: This will erase all data on $DEVICE${NC}"
    read -p "   Continue? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi
    mkfs.ext4 -L "$BACKUP_LABEL" -F "$DEVICE"
    echo -e "${GREEN}✅ Device formatted${NC}"
fi

# 4. Create mount point and mount
echo ""
echo "3️⃣ Setting up mount point..."
if [ ! -d "$BACKUP_MOUNT" ]; then
    mkdir -p "$BACKUP_MOUNT"
    echo -e "${GREEN}✅ Created mount point: $BACKUP_MOUNT${NC}"
else
    echo -e "${GREEN}✅ Mount point exists: $BACKUP_MOUNT${NC}"
fi

# Get UUID for fstab
UUID=$(blkid -o value -s UUID "$DEVICE" 2>/dev/null || echo "")
if [ -z "$UUID" ]; then
    echo -e "${YELLOW}⚠️  Could not get UUID, using device name in fstab${NC}"
    FSTAB_ENTRY="$DEVICE $BACKUP_MOUNT ext4 defaults 0 2"
else
    FSTAB_ENTRY="UUID=$UUID $BACKUP_MOUNT ext4 defaults 0 2"
fi

# Mount device
mount "$DEVICE" "$BACKUP_MOUNT"
echo -e "${GREEN}✅ Device mounted to $BACKUP_MOUNT${NC}"

# Check if already in fstab
if grep -q "$BACKUP_MOUNT" /etc/fstab; then
    echo -e "${YELLOW}⚠️  Mount point already in /etc/fstab${NC}"
    read -p "Update fstab entry? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove old entry
        sed -i "\|$BACKUP_MOUNT|d" /etc/fstab
        # Add new entry
        echo "$FSTAB_ENTRY" >> /etc/fstab
        echo -e "${GREEN}✅ Updated /etc/fstab${NC}"
    fi
else
    echo "$FSTAB_ENTRY" >> /etc/fstab
    echo -e "${GREEN}✅ Added to /etc/fstab${NC}"
fi

# 5. Install NFS server
echo ""
echo "4️⃣ Installing NFS server..."
if command -v exportfs &> /dev/null; then
    echo -e "${GREEN}✅ NFS server already installed${NC}"
else
    apt-get update
    apt-get install -y nfs-kernel-server
    echo -e "${GREEN}✅ NFS server installed${NC}"
fi

# 6. Configure NFS export
echo ""
echo "5️⃣ Configuring NFS export..."
NFS_EXPORT="$BACKUP_MOUNT *(rw,sync,no_subtree_check,no_root_squash)"

if grep -q "$BACKUP_MOUNT" /etc/exports; then
    echo -e "${YELLOW}⚠️  Export already exists in /etc/exports${NC}"
    read -p "Update export? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove old entry
        sed -i "\|$BACKUP_MOUNT|d" /etc/exports
        # Add new entry
        echo "$NFS_EXPORT" >> /etc/exports
        echo -e "${GREEN}✅ Updated /etc/exports${NC}"
    fi
else
    echo "$NFS_EXPORT" >> /etc/exports
    echo -e "${GREEN}✅ Added to /etc/exports${NC}"
fi

# Apply exports
exportfs -ra
echo -e "${GREEN}✅ NFS exports applied${NC}"

# 7. Start and enable NFS server
echo ""
echo "6️⃣ Starting NFS server..."
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server

if systemctl is-active --quiet nfs-kernel-server; then
    echo -e "${GREEN}✅ NFS server is running${NC}"
else
    echo -e "${RED}❌ NFS server failed to start${NC}"
    systemctl status nfs-kernel-server
    exit 1
fi

# 8. Get node IP and configure Longhorn
echo ""
echo "7️⃣ Longhorn backup target configuration..."
NODE_IP=$(hostname -I | awk '{print $1}')
BACKUP_TARGET="nfs://$NODE_IP:$BACKUP_MOUNT"

echo -e "${BLUE}Backup target URL: $BACKUP_TARGET${NC}"
echo ""
echo "To configure Longhorn backup target:"
echo ""
echo "Option 1: Via Longhorn UI"
echo "  1. Port-forward to Longhorn UI:"
echo "     kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80"
echo "  2. Open http://localhost:8080"
echo "  3. Go to Settings → General → Backup Target"
echo "  4. Set to: $BACKUP_TARGET"
echo ""
echo "Option 2: Via kubectl"
echo "  kubectl -n longhorn-system create -f - <<EOF"
echo "  apiVersion: longhorn.io/v1beta2"
echo "  kind: Setting"
echo "  metadata:"
echo "    name: backup-target"
echo "    namespace: longhorn-system"
echo "  value: \"$BACKUP_TARGET\""
echo "  EOF"
echo ""

# 9. Test NFS export
echo ""
echo "8️⃣ Testing NFS export..."
if showmount -e localhost | grep -q "$BACKUP_MOUNT"; then
    echo -e "${GREEN}✅ NFS export is visible${NC}"
    showmount -e localhost | grep "$BACKUP_MOUNT"
else
    echo -e "${YELLOW}⚠️  NFS export not visible (may need time to propagate)${NC}"
fi

# 10. Set permissions
echo ""
echo "9️⃣ Setting permissions..."
chmod 755 "$BACKUP_MOUNT"
chown root:root "$BACKUP_MOUNT"
echo -e "${GREEN}✅ Permissions set${NC}"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "📋 Summary:"
echo "  - Device: $DEVICE"
echo "  - Mount point: $BACKUP_MOUNT"
echo "  - NFS export: $BACKUP_MOUNT"
echo "  - Backup target: $BACKUP_TARGET"
echo ""
echo "✅ Next steps:"
echo "  1. Configure Longhorn backup target (see instructions above)"
echo "  2. Test backup creation in Longhorn UI"
echo "  3. Verify backups appear in $BACKUP_MOUNT"
echo ""
echo "🔧 Useful commands:"
echo "  df -h $BACKUP_MOUNT                    # Check disk usage"
echo "  showmount -e localhost                 # List NFS exports"
echo "  systemctl status nfs-kernel-server     # Check NFS status"
echo "  ls -la $BACKUP_MOUNT                   # List backup files"
echo ""

