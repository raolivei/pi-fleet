#!/bin/bash
# Complete NVMe boot setup after cloning
# This configures boot after OS has been cloned to NVMe

set -e

HOST="${1:-}"
if [ -z "$HOST" ]; then
    echo "Usage: $0 <hostname-or-ip>"
    echo "Example: $0 192.168.2.85"
    exit 1
fi

echo "=== Completing NVMe Boot Setup on $HOST ==="
echo ""

# Wait for clone to complete if still running
echo "Checking if clone is still running..."
if sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "pgrep -f 'dd if=/dev/mmcblk0p2' > /dev/null" 2>/dev/null; then
    echo "Clone still running, waiting for completion..."
    while sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "pgrep -f 'dd if=/dev/mmcblk0p2' > /dev/null" 2>/dev/null; do
        echo -n "."
        sleep 30
    done
    echo ""
    echo "Clone completed!"
fi

# Sync filesystem
echo "Syncing filesystem..."
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "sudo sync" 2>&1

# Fix filesystem first (required after cloning)
echo "Fixing filesystem..."
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "sudo e2fsck -fy /dev/nvme0n1p2 2>&1 | tail -10" 2>&1

# Resize filesystem to match partition
echo "Resizing filesystem to match partition..."
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "sudo resize2fs -f /dev/nvme0n1p2 2>&1 | tail -5" 2>&1

# Mount partitions
echo "Mounting partitions..."
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "sudo mkdir -p /mnt/nvme-root /mnt/nvme-boot && sudo mount /dev/nvme0n1p2 /mnt/nvme-root && sudo mount /dev/nvme0n1p1 /mnt/nvme-boot" 2>&1

# Update fstab
echo "Updating fstab..."
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "sudo sed -i.bak 's|/dev/mmcblk0p1|/dev/nvme0n1p1|g' /mnt/nvme-root/etc/fstab && sudo sed -i.bak 's|/dev/mmcblk0p2|/dev/nvme0n1p2|g' /mnt/nvme-root/etc/fstab" 2>&1

# Update cmdline.txt
echo "Updating cmdline.txt..."
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "sudo sed -i.bak 's|root=/dev/mmcblk0p2|root=/dev/nvme0n1p2|g' /mnt/nvme-boot/cmdline.txt && sudo sed -i.bak 's|root=PARTUUID=[^ ]*|root=/dev/nvme0n1p2|g' /mnt/nvme-boot/cmdline.txt" 2>&1

# Verify
echo "Verifying configuration..."
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "echo 'fstab:' && grep -E 'nvme|mmcblk' /mnt/nvme-root/etc/fstab && echo '' && echo 'cmdline.txt:' && cat /mnt/nvme-boot/cmdline.txt" 2>&1

# Unmount
echo "Unmounting..."
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$HOST "sudo umount /mnt/nvme-boot /mnt/nvme-root" 2>&1

echo ""
echo "✅ NVMe boot setup complete for $HOST!"
echo ""
echo "Next step: Reboot the Pi"
echo "  sshpass -p 'Control01!' ssh raolivei@$HOST 'sudo reboot'"
echo ""
echo "After reboot, verify:"
echo "  sshpass -p 'Control01!' ssh raolivei@$HOST 'df -h /'"
echo "  (should show /dev/nvme0n1p2)"

