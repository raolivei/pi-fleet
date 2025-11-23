#!/bin/bash
# Start PhotoRec recovery immediately
# Will prompt for destination in PhotoRec interface

PI_HOST="eldertree.local"
PI_USER="raolivei"
PI_PASSWORD="Control01!"

run_on_pi() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$1"
}

echo "🚀 Starting PhotoRec Recovery"
echo "============================="
echo ""
echo "PhotoRec will recover files from Extreme SSD (/dev/sda)"
echo "Even though Linux only sees 476GB, PhotoRec can scan the entire device"
echo "and recover files from the APFS partition the Mac saw."
echo ""
echo "Available destinations:"
echo "  1. /mnt/nvme/recovered_files (221 GB free) - Partial recovery"
echo "  2. /media/raolivei/3230-3738/recovered_files (435 GB free) - Same drive, risky"
echo "  3. 512GB SD card (if you insert/mount it)"
echo ""
echo "⚠️  If 512GB SD card is inserted, please mount it first:"
echo "   ssh $PI_USER@$PI_HOST"
echo "   sudo mkdir -p /mnt/sd_card"
echo "   sudo mount /dev/sdX1 /mnt/sd_card  # (replace sdX1 with actual device)"
echo ""

# Check if SD card appears
echo "Checking for SD card..."
SD_CARD=$(run_on_pi "lsblk -o NAME,SIZE | grep -E '^sd[b-z]|^mmcblk[1-9]' | head -1" | awk '{print $1}' | tr -d '\r\n')

if [ -n "$SD_CARD" ]; then
    echo "✅ Found potential SD card: /dev/$SD_CARD"
    SD_SIZE=$(run_on_pi "lsblk -o NAME,SIZE | grep $SD_CARD | awk '{print \$2}'" | tr -d '\r\n')
    echo "   Size: $SD_SIZE"
    echo ""
    read -p "Use this SD card for recovery? (y/n): " USE_SD
    if [ "$USE_SD" = "y" ] || [ "$USE_SD" = "Y" ]; then
        # Try to mount it
        MOUNT_POINT="/mnt/sd_card_recovery"
        run_on_pi "sudo mkdir -p $MOUNT_POINT"
        # Try to mount (may need partition)
        if run_on_pi "sudo mount /dev/${SD_CARD}1 $MOUNT_POINT 2>/dev/null || sudo mount /dev/$SD_CARD $MOUNT_POINT 2>/dev/null"; then
            RECOVERY_DEST="$MOUNT_POINT/recovered_files"
            echo "✅ SD card mounted at $MOUNT_POINT"
        else
            echo "⚠️  Could not auto-mount, you'll need to mount manually"
            read -p "Enter mount point for SD card: " RECOVERY_DEST
        fi
    else
        RECOVERY_DEST=""
    fi
else
    echo "⚠️  No SD card detected"
    RECOVERY_DEST=""
fi

# If no SD card selected, use NVME
if [ -z "$RECOVERY_DEST" ]; then
    echo ""
    echo "Using NVME for recovery (221 GB - partial recovery only)"
    RECOVERY_DEST="/mnt/nvme/recovered_files"
    run_on_pi "sudo mkdir -p $RECOVERY_DEST && sudo chmod 777 $RECOVERY_DEST"
fi

echo ""
echo "✅ Recovery destination: $RECOVERY_DEST"
echo ""

# Start PhotoRec in tmux
echo "Starting PhotoRec in tmux session: photorec-recovery"
echo ""

run_on_pi "tmux new-session -d -s photorec-recovery"
run_on_pi "tmux send-keys -t photorec-recovery 'cd $RECOVERY_DEST' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"PhotoRec Recovery\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"Source: /dev/sda (Extreme SSD)\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"Destination: $RECOVERY_DEST\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'photorec /log $RECOVERY_DEST/photorec.log /dev/sda' C-m"

echo "✅ PhotoRec started in tmux session!"
echo ""
echo "📋 Instructions:"
echo ""
echo "1. Attach to tmux session:"
echo "   ssh $PI_USER@$PI_HOST"
echo "   tmux attach -t photorec-recovery"
echo ""
echo "2. In PhotoRec interface, select:"
echo "   - [Proceed]"
echo "   - Disk: /dev/sda (Extreme SSD)"
echo "   - Partition: [Whole disk] or [No partition]"
echo "   - Filesystem: [Other] (for APFS/unrecognized)"
echo "   - File types: [All] or select specific types"
echo "   - Destination: $RECOVERY_DEST"
echo "   - Press Y to start recovery"
echo ""
echo "3. Detach from tmux:"
echo "   Press Ctrl+B, then D"
echo "   (Recovery continues in background)"
echo ""
echo "4. Monitor progress:"
echo "   ssh $PI_USER@$PI_HOST 'tail -f $RECOVERY_DEST/photorec.log'"
echo ""
echo "5. Check recovery status:"
echo "   ssh $PI_USER@$PI_HOST 'ls -lh $RECOVERY_DEST/recup_dir.* | wc -l'"
echo ""
echo "⚠️  Recovery will take 8-24 hours"
echo "⚠️  PhotoRec will recover files even from the APFS partition Linux can't see"

