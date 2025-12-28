#!/bin/bash
# Easy script to mount APFS drive for GoPro data recovery
# Usage: ./mount-apfs-drive.sh [node-ip]

# Exit on error
set -e

NODE_IP="${1:-192.168.2.86}"

# Check for password
if [ -z "$PI_PASSWORD" ]; then
    echo "Error: PI_PASSWORD environment variable not set."
    echo "Please set it: export PI_PASSWORD='your_password'"
    exit 1
fi

echo "=== Mounting APFS Drive on node ==="
echo ""

sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no raolivei@$NODE_IP "
    echo 'Step 1: Detecting APFS drive...'
    DRIVE=\$(sudo lsblk -n -o NAME | grep -E '^sd[a-z]' | head -1)
    
    if [ -z \"\$DRIVE\" ]; then
        echo '❌ No external drive detected'
        exit 1
    fi
    
    echo \"Found drive: /dev/\$DRIVE\"
    echo ''
    echo 'Step 2: Checking partitions...'
    sudo fdisk -l /dev/\$DRIVE | grep -E 'Device|APFS'
    echo ''
    
    echo 'Step 3: Mounting APFS partitions...'
    PART_NUM=1
    for part in \$(sudo lsblk -n -o NAME /dev/\$DRIVE | grep -E '^\${DRIVE}[0-9]+'); do
        FSTYPE=\$(sudo blkid -o value -s TYPE /dev/\$part 2>/dev/null)
        if [ \"\$FSTYPE\" = \"apfs\" ]; then
            MOUNT=\"/mnt/apfs-part\${PART_NUM}\"
            echo \"Mounting /dev/\$part to \$MOUNT...\"
            sudo mkdir -p \$MOUNT
            if sudo apfs-fuse /dev/\$part \$MOUNT 2>&1; then
                echo \"  ✅ Mounted successfully!\"
                echo \"  Location: \$MOUNT\"
            else
                echo \"  ❌ Mount failed\"
            fi
            PART_NUM=\$((PART_NUM + 1))
        fi
    done
    
    echo ''
    echo 'Step 4: Searching for GoPro data...'
    for mount_point in /mnt/apfs-part*; do
        if [ -d \"\$mount_point\" ] && mountpoint -q \"\$mount_point\" 2>/dev/null; then
            echo \"=== \$mount_point ===\"
            sudo find \"\$mount_point\" -type d -iname '*gopro*' -o -iname '*100gopro*' 2>&1 | head -10
        fi
    done
    
    echo ''
    echo '✅ Done! GoPro data found at: /mnt/apfs-part1/root/GOPRO/100GOPRO'
    echo 'To unmount: sudo fusermount -u /mnt/apfs-part*'
"
