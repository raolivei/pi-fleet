#!/bin/bash
# Remote fix script - runs on your Mac, connects to node-1 to fix SD card
# Usage: ./fix-sd-card-remote-exec.sh

set -e

NODE0_IP="192.168.2.86"
NODE0_USER="raolivei"

echo "=== SD Card Fix via node-1 ==="
echo ""
echo "This script will:"
echo "  1. Connect to node-1 ($NODE0_IP)"
echo "  2. Find the USB device with SD card"
echo "  3. Mount and fix fstab"
echo "  4. Unmount safely"
echo ""

# Check if sshpass is available
# Password should be set via environment variable: PI_PASSWORD
if command -v sshpass &> /dev/null && [ -n "$PI_PASSWORD" ]; then
    echo "Using sshpass for password authentication"
    SSHPASS_CMD="sshpass -p '$PI_PASSWORD'"
else
    if [ -z "$PI_PASSWORD" ]; then
        echo "⚠️  PI_PASSWORD environment variable not set"
        echo "   Set it with: export PI_PASSWORD='your-password'"
    fi
    echo "sshpass not found or password not set - you'll need to enter password manually"
    SSHPASS_CMD=""
fi

# Create remote script
REMOTE_SCRIPT=$(cat << 'REMOTEEOF'
#!/bin/bash
set -e

# Find USB device
echo "Looking for USB device..."
USB_DEVICE=""
for dev in /dev/sd[a-z]; do
    if [ -b "$dev" ]; then
        if lsblk "$dev" 2>/dev/null | grep -q "part"; then
            USB_DEVICE="$dev"
            echo "Found: $USB_DEVICE"
            lsblk "$USB_DEVICE"
            break
        fi
    fi
done

if [ -z "$USB_DEVICE" ]; then
    echo "ERROR: No USB device found"
    exit 1
fi

# Find root partition
ROOT_PART="${USB_DEVICE}2"
if [ ! -b "$ROOT_PART" ]; then
    ROOT_PART="${USB_DEVICE}p2"
fi

if [ ! -b "$ROOT_PART" ]; then
    echo "ERROR: Root partition not found"
    lsblk "$USB_DEVICE"
    exit 1
fi

echo "Root partition: $ROOT_PART"

# Mount
MOUNT_POINT="/mnt/sd-root-$$"
sudo mkdir -p "$MOUNT_POINT"
sudo mount "$ROOT_PART" "$MOUNT_POINT"

# Backup and fix
sudo cp "$MOUNT_POINT/etc/fstab" "$MOUNT_POINT/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"
sudo sed -i.bak \
    -e 's|\(/mnt/backup.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' \
    -e 's|\(/dev/sdb1.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' \
    -e 's|\(UUID=.*/mnt/backup.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' \
    -e '/^[^#].*\/mnt\/backup/s/defaults[^,]*/defaults,nofail/g' \
    -e '/^[^#].*\/dev\/sdb/s/defaults[^,]*/defaults,nofail/g' \
    "$MOUNT_POINT/etc/fstab"

echo "=== Fixed fstab ==="
cat "$MOUNT_POINT/etc/fstab"

# Unmount
sudo umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

echo "✓ Done!"
REMOTEEOF
)

# Execute on remote
echo "Connecting to node-1..."
if [ -n "$SSHPASS_CMD" ]; then
    echo "$REMOTE_SCRIPT" | $SSHPASS_CMD ssh -o StrictHostKeyChecking=no "$NODE0_USER@$NODE0_IP" "bash -s"
else
    echo "$REMOTE_SCRIPT" | ssh -o StrictHostKeyChecking=no "$NODE0_USER@$NODE0_IP" "bash -s"
fi

echo ""
echo "✓ SD card fixed! You can now:"
echo "  1. Remove SD card from node-1 USB port"
echo "  2. Put it back in node-1"
echo "  3. Boot node-1 - it should work now"

