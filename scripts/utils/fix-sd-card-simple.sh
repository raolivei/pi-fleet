#!/bin/bash
# Simple one-liner commands to fix SD card on node-1
# Copy and paste these commands one by one

echo "=== SD Card Fix Commands ==="
echo ""
echo "SSH to node-1 and run these commands:"
echo ""
echo "# 1. Find USB device:"
echo "lsblk | grep -E 'sd|mmc'"
echo ""
echo "# 2. Mount root partition (adjust /dev/sda2 to match your device):"
echo "sudo mkdir -p /mnt/sd-root"
echo "sudo mount /dev/sda2 /mnt/sd-root  # or /dev/sdb2 - check lsblk output first"
echo ""
echo "# 3. Backup and fix fstab:"
echo "sudo cp /mnt/sd-root/etc/fstab /mnt/sd-root/etc/fstab.bak"
echo "sudo sed -i 's|defaults 0 2|defaults,nofail 0 2|g' /mnt/sd-root/etc/fstab"
echo ""
echo "# 4. Verify fix:"
echo "cat /mnt/sd-root/etc/fstab"
echo ""
echo "# 5. Unmount:"
echo "sudo umount /mnt/sd-root"
echo ""
echo "Or run the automated script on node-1:"
echo "  ./fix-sd-card-on-pi.sh"

