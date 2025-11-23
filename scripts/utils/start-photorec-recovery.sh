#!/bin/bash
# Start PhotoRec recovery with proper destination selection

PI_HOST="eldertree.local"
PI_USER="raolivei"
PI_PASSWORD="Control01!"

run_on_pi() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$1"
}

echo "📸 PhotoRec Recovery - Destination Selection"
echo "============================================="
echo ""
echo "⚠️  IMPORTANT: You need 900+ GB free space for 823 GB recovery"
echo ""
echo "Available destinations:"
echo ""
echo "1. NVME (/mnt/nvme) - 221 GB free ❌ NOT ENOUGH"
echo "2. Extreme SSD exFAT (/media/raolivei/3230-3738) - 435 GB free ❌ NOT ENOUGH"
echo "3. External drive (you specify)"
echo ""
echo "⚠️  WARNING: Using Extreme SSD for recovery means:"
echo "   - Recovered files on same drive as source"
echo "   - Only 435 GB free (not enough for full 823 GB)"
echo "   - May overwrite data we're trying to recover"
echo ""
read -p "Select recovery destination (1/2/3 or path): " DEST_CHOICE

case $DEST_CHOICE in
    1)
        RECOVERY_DEST="/mnt/nvme/recovered_files"
        echo "⚠️  WARNING: Only 221 GB free, not enough for full recovery"
        ;;
    2)
        RECOVERY_DEST="/media/raolivei/3230-3738/recovered_files"
        echo "⚠️  WARNING: Only 435 GB free, not enough for full recovery"
        echo "⚠️  WARNING: This is the same drive - risky!"
        read -p "Continue anyway? (y/n): " RISK_CONFIRM
        if [ "$RISK_CONFIRM" != "y" ]; then
            echo "Cancelled"
            exit 0
        fi
        ;;
    3)
        read -p "Enter full path to external drive mount point: " RECOVERY_DEST
        ;;
    *)
        RECOVERY_DEST="$DEST_CHOICE"
        ;;
esac

if [ -z "$RECOVERY_DEST" ]; then
    echo "❌ Invalid destination"
    exit 1
fi

echo ""
echo "✅ Recovery destination: $RECOVERY_DEST"
echo ""

# Create destination
run_on_pi "sudo mkdir -p '$RECOVERY_DEST' && sudo chmod 777 '$RECOVERY_DEST'"

# Check space
FREE_SPACE=$(run_on_pi "df -h '$RECOVERY_DEST' 2>/dev/null | tail -1 | awk '{print \$4}'" | tr -d '\r\n')
echo "Free space: $FREE_SPACE"

if [ -z "$FREE_SPACE" ]; then
    echo "⚠️  Could not determine free space"
else
    # Extract number (rough check)
    FREE_GB=$(echo "$FREE_SPACE" | grep -oE '[0-9]+' | head -1)
    if [ -n "$FREE_GB" ] && [ "$FREE_GB" -lt 900 ]; then
        echo "⚠️  WARNING: Less than 900 GB free - recovery may be incomplete"
        read -p "Continue anyway? (y/n): " SPACE_CONFIRM
        if [ "$SPACE_CONFIRM" != "y" ]; then
            echo "Cancelled"
            exit 0
        fi
    fi
fi

echo ""
echo "Starting PhotoRec recovery..."
echo ""

# Create PhotoRec automation script
run_on_pi "cat > /tmp/photorec_auto.sh << 'PHOTOREC_EOF'
#!/bin/bash
cd $RECOVERY_DEST
echo \"========================================\"
echo \"PhotoRec Recovery\"
echo \"========================================\"
echo \"\"
echo \"Source: /dev/sda (Extreme SSD)\"
echo \"Destination: $RECOVERY_DEST\"
echo \"\"
echo \"PhotoRec will recover files by file signature\"
echo \"This works even if partition table is wrong\"
echo \"\"
echo \"Estimated time: 8-24 hours\"
echo \"\"
echo \"Starting PhotoRec (interactive)...\"
echo \"\"
photorec /log $RECOVERY_DEST/photorec.log /dev/sda
PHOTOREC_EOF
chmod +x /tmp/photorec_auto.sh"

# Start in tmux
run_on_pi "tmux new-session -d -s photorec-recovery"
run_on_pi "tmux send-keys -t photorec-recovery 'sudo /tmp/photorec_auto.sh' C-m"

echo "✅ PhotoRec started in tmux session: photorec-recovery"
echo ""
echo "📋 Next steps:"
echo "  1. Attach to tmux: ssh $PI_USER@$PI_HOST"
echo "     Then: tmux attach -t photorec-recovery"
echo ""
echo "  2. In PhotoRec, select:"
echo "     - [Proceed]"
echo "     - Disk: /dev/sda"
echo "     - Partition: [Whole disk] or [No partition]"
echo "     - Filesystem: [Other] (for APFS/unrecognized)"
echo "     - File types: [All] or select specific"
echo "     - Destination: $RECOVERY_DEST"
echo "     - Press Y to start"
echo ""
echo "  3. Detach: Ctrl+B, then D (recovery continues)"
echo ""
echo "  4. Monitor: ssh $PI_USER@$PI_HOST 'tail -f $RECOVERY_DEST/photorec.log'"
echo ""
echo "⚠️  Recovery will take 8-24 hours. Be patient!"

