#!/bin/bash
# Final PhotoRec recovery start - uses best available destination

PI_HOST="eldertree.local"
PI_USER="raolivei"
PI_PASSWORD="Control01!"

run_on_pi() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$1"
}

echo "🚀 Starting PhotoRec Recovery - Final Setup"
echo "==========================================="
echo ""

# Check available destinations
NVME_FREE=$(run_on_pi "df -h /mnt/nvme 2>/dev/null | tail -1 | awk '{print \$4}'" | tr -d '\r\n')
EXTREME_FREE=$(run_on_pi "df -h /media/raolivei/3230-3738 2>/dev/null | tail -1 | awk '{print \$4}'" | tr -d '\r\n')

echo "Available recovery destinations:"
echo "  1. NVME (/mnt/nvme): $NVME_FREE free"
echo "  2. Extreme SSD exFAT (/media/raolivei/3230-3738): $EXTREME_FREE free"
echo "  3. 512GB SD card: Not detected (if it appears, we can switch)"
echo ""

# Recommend best option
if [ -n "$EXTREME_FREE" ]; then
    EXTREME_GB=$(echo "$EXTREME_FREE" | grep -oE '[0-9]+' | head -1)
    if [ -n "$EXTREME_GB" ] && [ "$EXTREME_GB" -ge 400 ]; then
        echo "⚠️  RECOMMENDATION: Use Extreme SSD exFAT ($EXTREME_FREE free)"
        echo "   - Most space available"
        echo "   - ⚠️  Same drive as source (risky but manageable)"
        echo "   - PhotoRec writes to different partition than source data"
        echo ""
        read -p "Use Extreme SSD for recovery? (y/n): " USE_EXTREME
        
        if [ "$USE_EXTREME" = "y" ] || [ "$USE_EXTREME" = "Y" ]; then
            RECOVERY_DEST="/media/raolivei/3230-3738/recovered_files"
        else
            RECOVERY_DEST="/mnt/nvme/recovered_files"
            echo "Using NVME instead ($NVME_FREE free - partial recovery)"
        fi
    else
        RECOVERY_DEST="/mnt/nvme/recovered_files"
        echo "Using NVME ($NVME_FREE free - partial recovery)"
    fi
else
    RECOVERY_DEST="/mnt/nvme/recovered_files"
    echo "Using NVME ($NVME_FREE free - partial recovery)"
fi

echo ""
echo "✅ Recovery destination: $RECOVERY_DEST"
echo ""

# Create destination
run_on_pi "mkdir -p '$RECOVERY_DEST' && chmod 777 '$RECOVERY_DEST'"

# Start PhotoRec in tmux
echo "Starting PhotoRec in tmux session: photorec-recovery"
echo ""

run_on_pi "tmux new-session -d -s photorec-recovery"
run_on_pi "tmux send-keys -t photorec-recovery 'cd $RECOVERY_DEST' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'clear' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"========================================\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"PhotoRec Recovery - Extreme SSD\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"========================================\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"Source: /dev/sda (Extreme SSD)\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"Destination: $RECOVERY_DEST\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"PhotoRec will recover files even from APFS partition\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"that Linux cannot see. This will take 8-24 hours.\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'echo \"\"' C-m"
run_on_pi "tmux send-keys -t photorec-recovery 'photorec /log $RECOVERY_DEST/photorec.log /dev/sda' C-m"

echo "✅ PhotoRec started in tmux!"
echo ""
echo "📋 Connect to PhotoRec:"
echo "   ssh $PI_USER@$PI_HOST"
echo "   tmux attach -t photorec-recovery"
echo ""
echo "📋 In PhotoRec, select:"
echo "   1. [Proceed]"
echo "   2. Disk: /dev/sda"
echo "   3. Partition: [Whole disk] or [No partition]"
echo "   4. Filesystem: [Other]"
echo "   5. File types: [All] or select specific"
echo "   6. Destination: $RECOVERY_DEST"
echo "   7. Press Y to start"
echo ""
echo "💡 Detach: Ctrl+B, then D (recovery continues)"
echo "💡 Monitor: ssh $PI_USER@$PI_HOST 'tail -f $RECOVERY_DEST/photorec.log'"
echo ""
echo "⚠️  If 512GB SD card appears later, we can pause and switch destinations"

