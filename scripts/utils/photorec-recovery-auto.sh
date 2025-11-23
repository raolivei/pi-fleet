#!/bin/bash
# PhotoRec recovery with device selection prompt
# Works even if partition table is wrong

PI_HOST="eldertree.local"
PI_USER="raolivei"
PI_PASSWORD="Control01!"

run_on_pi() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$1"
}

echo "📸 PhotoRec Recovery Setup"
echo "=========================="
echo ""
echo "PhotoRec can recover files even if:"
echo "  - Partition table is corrupted"
echo "  - Filesystem is unrecognized"
echo "  - Only part of drive is visible"
echo ""

# List available drives
echo "Available drives:"
run_on_pi "lsblk -o NAME,SIZE,MODEL,MOUNTPOINT | grep -E '^[a-z]|^sd|^nvme'"

echo ""
echo "Available space for recovery:"
run_on_pi "df -h | grep -E '^/dev|Filesystem'"

echo ""
read -p "Enter recovery destination path (must have 900+ GB free): " RECOVERY_DEST

if [ -z "$RECOVERY_DEST" ]; then
    echo "❌ Recovery destination required"
    exit 1
fi

# Verify destination exists and has space
FREE_SPACE=$(run_on_pi "df -h '$RECOVERY_DEST' 2>/dev/null | tail -1 | awk '{print \$4}'" | tr -d '\r\n')
if [ -z "$FREE_SPACE" ]; then
    echo "⚠️  Destination not found, will create: $RECOVERY_DEST"
    run_on_pi "sudo mkdir -p '$RECOVERY_DEST'"
else
    echo "✅ Free space at destination: $FREE_SPACE"
fi

echo ""
echo "⚠️  RECOVERY DESTINATION: $RECOVERY_DEST"
echo ""
read -p "Confirm this is correct? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled"
    exit 0
fi

# Create PhotoRec command file for automation
echo ""
echo "Setting up PhotoRec recovery..."
echo ""

# PhotoRec will be run interactively but we'll create a script to help
run_on_pi "cat > /tmp/photorec_recovery.sh << 'PHOTOREC_EOF'
#!/bin/bash
cd $RECOVERY_DEST
echo \"PhotoRec Recovery\"
echo \"=================\"
echo \"\"
echo \"Device: /dev/sda (Extreme SSD)\"
echo \"Destination: $RECOVERY_DEST\"
echo \"\"
echo \"PhotoRec will prompt you to:\"
echo \"  1. Select disk: Choose /dev/sda\"
echo \"  2. Select partition: Choose 'Whole disk' or 'No partition'\"
echo \"  3. Select filesystem: Choose 'Other' (for APFS)\"
echo \"  4. Select destination: Choose $RECOVERY_DEST\"
echo \"  5. Press 'Y' to start recovery\"
echo \"\"
echo \"Starting PhotoRec...\"
echo \"\"
photorec /log $RECOVERY_DEST/photorec.log /dev/sda
PHOTOREC_EOF
chmod +x /tmp/photorec_recovery.sh"

echo "✅ PhotoRec script created"
echo ""
echo "Starting PhotoRec in tmux session: photorec-recovery"
echo ""

# Start PhotoRec in tmux
run_on_pi "tmux new-session -d -s photorec-recovery"
run_on_pi "tmux send-keys -t photorec-recovery 'sudo /tmp/photorec_recovery.sh' C-m"

echo "✅ PhotoRec started in tmux session: photorec-recovery"
echo ""
echo "📋 Instructions:"
echo "  1. Attach to tmux: ssh $PI_USER@$PI_HOST && tmux attach -t photorec-recovery"
echo "  2. Follow PhotoRec prompts:"
echo "     - Select: [Proceed]"
echo "     - Disk: /dev/sda"
echo "     - Partition: [Whole disk] or [No partition]"
echo "     - Filesystem: [Other]"
echo "     - Destination: $RECOVERY_DEST"
echo "     - File types: [All] or select specific types"
echo "     - Press Y to start"
echo ""
echo "  3. Recovery will take 8-24 hours"
echo "  4. You can detach (Ctrl+B, then D) and come back later"
echo ""
echo "Monitor progress:"
echo "  ssh $PI_USER@$PI_HOST 'tail -f $RECOVERY_DEST/photorec.log'"

