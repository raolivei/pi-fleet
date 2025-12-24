#!/bin/bash
# Create a fix script on the boot partition (FAT32, accessible on macOS)
# This script will be placed on the boot partition and can be run when Pi boots

set -e

BOOT_MOUNT="/Volumes/bootfs"
FIX_SCRIPT="$BOOT_MOUNT/fix-fstab.sh"

if [ ! -d "$BOOT_MOUNT" ]; then
    echo "❌ Boot partition not mounted at $BOOT_MOUNT"
    echo "Please mount the bootfs volume first"
    exit 1
fi

echo "Creating fix script on boot partition..."

cat > "$FIX_SCRIPT" << 'FIXEOF'
#!/bin/bash
# Fix fstab - add nofail to problematic mounts
# Run this with: sudo bash /boot/firmware/fix-fstab.sh

set -e

echo "=== Fixing fstab ==="

# Backup
cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d-%H%M%S)

# Fix - add nofail to non-critical mounts
sed -i.bak 's|\(/mnt/backup.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' /etc/fstab
sed -i.bak 's|\(/dev/sdb1.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' /etc/fstab
sed -i.bak 's|\(UUID=.*/mnt/backup.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' /etc/fstab

# Also fix any line with defaults that doesn't have nofail (except root/boot)
sed -i.bak '/^[^#].*\/mnt\/backup/s/defaults[^,]*/defaults,nofail/g' /etc/fstab
sed -i.bak '/^[^#].*\/dev\/sdb/s/defaults[^,]*/defaults,nofail/g' /etc/fstab

echo "=== Fixed fstab ==="
cat /etc/fstab

echo ""
echo "✓ fstab fixed! Now run: sudo systemctl default"
echo "Or reboot: sudo reboot"
FIXEOF

chmod +x "$FIX_SCRIPT"

echo "✓ Fix script created at: $FIX_SCRIPT"
echo ""
echo "Next steps:"
echo "1. Eject the SD card and put it back in node-1"
echo "2. Boot the Pi (it will still enter emergency mode)"
echo "3. Try SSH: ssh raolivei@192.168.2.85"
echo "4. If SSH works, run: sudo bash /boot/firmware/fix-fstab.sh"
echo "5. Then run: sudo systemctl default"
echo ""
echo "If SSH doesn't work, you'll need physical access to run the script."

