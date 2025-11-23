#!/bin/bash
# Repair Extreme SSD on Raspberry Pi
# No corporate restrictions on Pi!

set -e

PI_HOST="eldertree.local"
PI_USER="raolivei"
PI_PASSWORD="Control01!"

echo "🔧 Repairing Extreme SSD on Raspberry Pi"
echo "========================================"
echo ""

# Function to run command on Pi
run_on_pi() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$1"
}

# Step 1: Check if drive is connected
echo "Step 1: Checking if Extreme SSD is connected..."
echo ""

# List all block devices
echo "Block devices:"
run_on_pi "lsblk" || echo "lsblk not available, trying ls /dev/sd*"
run_on_pi "ls -la /dev/sd* 2>/dev/null | head -20"

echo ""
echo "USB devices:"
run_on_pi "dmesg | tail -100 | grep -i 'usb\|new.*device\|attached' | tail -10"

echo ""

# Step 2: Find the Extreme SSD device
echo "Step 2: Identifying Extreme SSD device..."
echo ""

# Try to find 2TB drive
DEVICE=$(run_on_pi "lsblk -o NAME,SIZE,MODEL | grep -i '2.0T\|extreme\|sandisk' | head -1 | awk '{print \$1}'" | tr -d '\r\n')

if [ -z "$DEVICE" ]; then
    # Try alternative method
    DEVICE=$(run_on_pi "fdisk -l 2>/dev/null | grep -i '2.0.*TiB\|extreme\|sandisk' | head -1" || echo "")
    if [ -n "$DEVICE" ]; then
        DEVICE=$(echo "$DEVICE" | grep -o '/dev/sd[a-z]' | head -1)
    fi
fi

if [ -z "$DEVICE" ]; then
    echo "⚠️  Could not automatically detect Extreme SSD"
    echo ""
    echo "Please identify the device manually:"
    run_on_pi "lsblk -o NAME,SIZE,MODEL"
    echo ""
    read -p "Enter device name (e.g., sda, sdb): " DEVICE_INPUT
    DEVICE="/dev/$DEVICE_INPUT"
else
    DEVICE="/dev/$DEVICE"
    echo "✅ Found device: $DEVICE"
fi

echo ""

# Step 3: Check if mounted
echo "Step 3: Checking mount status..."
MOUNTED=$(run_on_pi "mount | grep $DEVICE | awk '{print \$3}'" | head -1 | tr -d '\r\n')

if [ -n "$MOUNTED" ]; then
    echo "⚠️  Device is mounted at: $MOUNTED"
    echo "Unmounting..."
    run_on_pi "sudo umount $DEVICE* 2>/dev/null || sudo umount $MOUNTED 2>/dev/null || true"
    sleep 2
    echo "✅ Unmounted"
else
    echo "✅ Device is not mounted"
fi

echo ""

# Step 4: Check filesystem type
echo "Step 4: Checking filesystem type..."
FS_TYPE=$(run_on_pi "sudo blkid $DEVICE* 2>/dev/null | grep -o 'TYPE=\"[^\"]*\"' | cut -d'\"' -f2" | head -1 | tr -d '\r\n')

if [ -z "$FS_TYPE" ]; then
    # Try to detect partition
    PARTITION=$(run_on_pi "ls ${DEVICE}* 2>/dev/null | grep -E '${DEVICE}[0-9]+' | head -1" | tr -d '\r\n')
    if [ -n "$PARTITION" ]; then
        FS_TYPE=$(run_on_pi "sudo blkid $PARTITION 2>/dev/null | grep -o 'TYPE=\"[^\"]*\"' | cut -d'\"' -f2" | tr -d '\r\n')
        DEVICE="$PARTITION"
    fi
fi

echo "Filesystem type: ${FS_TYPE:-Unknown}"
echo "Device: $DEVICE"
echo ""

# Step 5: Repair filesystem
echo "Step 5: Repairing filesystem..."
echo "⚠️  This is NON-DESTRUCTIVE - data will be preserved"
echo ""

if [ "$FS_TYPE" = "apfs" ] || [ -z "$FS_TYPE" ]; then
    echo "⚠️  APFS detected - Linux has limited APFS support"
    echo "Trying to mount as read-only first to check..."
    
    # Try to mount read-only
    MOUNT_POINT="/mnt/extreme_ssd"
    run_on_pi "sudo mkdir -p $MOUNT_POINT"
    
    # Try with apfs-fuse if available
    if run_on_pi "which apfs-fuse" >/dev/null 2>&1; then
        echo "Using apfs-fuse..."
        run_on_pi "sudo apfs-fuse $DEVICE $MOUNT_POINT -o allow_other" || echo "apfs-fuse failed"
    else
        echo "⚠️  apfs-fuse not installed"
        echo "Installing apfs-fuse..."
        run_on_pi "sudo apt-get update && sudo apt-get install -y apfs-fuse" || echo "Install failed"
    fi
    
    # List files if mounted
    if run_on_pi "mount | grep $MOUNT_POINT" >/dev/null 2>&1; then
        echo "✅ Mounted successfully!"
        echo "Files:"
        run_on_pi "ls -la $MOUNT_POINT | head -20"
    fi
    
elif [ "$FS_TYPE" = "exfat" ] || [ "$FS_TYPE" = "vfat" ] || [ "$FS_TYPE" = "ntfs" ]; then
    echo "Repairing $FS_TYPE filesystem..."
    run_on_pi "sudo fsck.${FS_TYPE} -y $DEVICE" || run_on_pi "sudo fsck -y $DEVICE"
    
elif [ "$FS_TYPE" = "ext4" ] || [ "$FS_TYPE" = "ext3" ] || [ "$FS_TYPE" = "ext2" ]; then
    echo "Repairing ext filesystem..."
    run_on_pi "sudo fsck.${FS_TYPE} -y $DEVICE" || run_on_pi "sudo e2fsck -y $DEVICE"
    
else
    echo "⚠️  Unknown filesystem type: $FS_TYPE"
    echo "Trying generic fsck..."
    run_on_pi "sudo fsck -y $DEVICE"
fi

echo ""

# Step 6: Remount and list files
echo "Step 6: Remounting and checking files..."
echo ""

if [ -z "$MOUNTED" ]; then
    MOUNT_POINT="/mnt/extreme_ssd"
    run_on_pi "sudo mkdir -p $MOUNT_POINT"
    
    if [ "$FS_TYPE" = "apfs" ]; then
        run_on_pi "sudo apfs-fuse $DEVICE $MOUNT_POINT -o allow_other" || echo "Mount failed"
    else
        run_on_pi "sudo mount $DEVICE $MOUNT_POINT" || echo "Mount failed"
    fi
    
    if run_on_pi "mount | grep $MOUNT_POINT" >/dev/null 2>&1; then
        echo "✅ Mounted at: $MOUNT_POINT"
        echo ""
        echo "Files:"
        run_on_pi "ls -lah $MOUNT_POINT | head -30"
        echo ""
        echo "Disk usage:"
        run_on_pi "df -h $MOUNT_POINT"
    fi
fi

echo ""
echo "=========================================="
echo "Repair Complete"
echo "=========================================="
echo ""
echo "Device: $DEVICE"
echo "Filesystem: ${FS_TYPE:-Unknown}"
echo "Mount point: ${MOUNT_POINT:-Not mounted}"
echo ""
echo "💡 To access files from Pi:"
echo "   ssh $PI_USER@$PI_HOST"
echo "   ls $MOUNT_POINT"
echo ""
echo "💡 To copy files from Pi to Mac:"
echo "   scp -r $PI_USER@$PI_HOST:$MOUNT_POINT/* ~/recovered-files/"

