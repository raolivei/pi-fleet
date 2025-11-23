#!/bin/bash
# Detect and mount 512GB SD card

PI_HOST="eldertree.local"
PI_USER="raolivei"
PI_PASSWORD="Control01!"

run_on_pi() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$1"
}

echo "🔍 Detecting 512GB SD Card"
echo "=========================="
echo ""

# Check for SD card reader
echo "USB devices:"
run_on_pi "lsusb | grep -i 'sd\|card\|storage'"

echo ""
echo "Block devices:"
run_on_pi "lsblk -o NAME,SIZE,TYPE,MOUNTPOINT"

echo ""
echo "Checking for unmounted devices..."
run_on_pi "sudo blkid 2>/dev/null | grep -v 'loop\|zram'"

echo ""
echo "Trying to detect SD card..."
# Check if card reader has a device
for dev in sdb sdc mmcblk1; do
    if run_on_pi "test -b /dev/$dev" 2>/dev/null; then
        echo "✅ Found device: /dev/$dev"
        run_on_pi "sudo fdisk -l /dev/$dev 2>/dev/null | head -10"
        echo ""
    fi
done

echo ""
echo "If SD card is not detected:"
echo "  1. Make sure card is inserted in reader"
echo "  2. Try unplugging and replugging the reader"
echo "  3. Check dmesg: ssh $PI_USER@$PI_HOST 'dmesg | tail -50'"

