#!/bin/bash
# Backup eldertree NVMe data before repartitioning for boot
# This backs up data from /mnt/nvme to a safe location

set -e

HOST="${1:-192.168.2.83}"
BACKUP_DEST="${2:-}"

echo "=== Backup eldertree NVMe Data ==="
echo "Host: $HOST"
echo ""

# Check current NVMe usage
echo "Checking NVMe data..."
DATA_SIZE=$(sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "sudo du -sh /mnt/nvme 2>/dev/null | awk '{print \$1}'" 2>&1)
echo "NVMe data size: $DATA_SIZE"
echo ""

# Find backup destination
if [ -z "$BACKUP_DEST" ]; then
    echo "Searching for backup destination..."
    
    # Check for 2TB backup drive
    BACKUP_DEV=$(sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "lsblk -o NAME,SIZE,TYPE | grep -E 'sd[a-z]|nvme' | grep -v 'nvme0n1' | head -1 | awk '{print \$1}'" 2>&1)
    
    if [ -n "$BACKUP_DEV" ]; then
        echo "Found potential backup device: /dev/$BACKUP_DEV"
        # Check if it's mounted
        MOUNT_POINT=$(sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "mount | grep /dev/$BACKUP_DEV | awk '{print \$3}'" 2>&1)
        
        if [ -n "$MOUNT_POINT" ]; then
            BACKUP_DEST="$MOUNT_POINT/eldertree-nvme-backup-$(date +%Y%m%d)"
            echo "Using mounted backup location: $BACKUP_DEST"
        else
            echo "Device not mounted. Options:"
            echo "  1. Mount manually: sudo mount /dev/${BACKUP_DEV}1 /mnt/backup"
            echo "  2. Use SD card (if enough space)"
            echo "  3. Use network storage"
            exit 1
        fi
    else
        echo "No backup device found. Options:"
        echo "  1. Connect 2TB backup drive"
        echo "  2. Use SD card free space (check available space first)"
        echo "  3. Use network storage"
        exit 1
    fi
fi

# Check available space
echo ""
echo "Checking available space at backup destination..."
AVAILABLE=$(sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "df -h $BACKUP_DEST 2>/dev/null | tail -1 | awk '{print \$4}' || echo 'Destination not accessible'" 2>&1)
echo "Available space: $AVAILABLE"
echo ""

# Confirm backup
echo "⚠️  WARNING: This will backup data from /mnt/nvme to $BACKUP_DEST"
echo "Data to backup:"
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "sudo du -sh /mnt/nvme/* 2>/dev/null | sort -h" 2>&1
echo ""
read -p "Continue with backup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Backup cancelled"
    exit 1
fi

# Create backup directory
echo "Creating backup directory..."
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "sudo mkdir -p $BACKUP_DEST" 2>&1

# Backup data
echo "Starting backup (this may take a while)..."
echo "Backing up /mnt/nvme/* to $BACKUP_DEST/"
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "sudo rsync -avh --progress /mnt/nvme/ $BACKUP_DEST/ 2>&1" | tee /tmp/backup-progress.log

# Verify backup
echo ""
echo "Verifying backup..."
BACKUP_SIZE=$(sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "sudo du -sh $BACKUP_DEST 2>/dev/null | awk '{print \$1}'" 2>&1)
echo "Backup size: $BACKUP_SIZE"
echo "Original size: $DATA_SIZE"

echo ""
echo "✅ Backup complete!"
echo "Backup location: $BACKUP_DEST"
echo ""
echo "Next steps:"
echo "  1. Verify backup integrity"
echo "  2. Proceed with NVMe repartitioning for boot"
echo "  3. After boot setup, restore data if needed"

