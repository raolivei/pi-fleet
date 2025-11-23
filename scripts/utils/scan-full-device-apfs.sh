#!/bin/bash
# Scan entire device for APFS structures, even beyond visible partition table

PI_HOST="eldertree.local"
PI_USER="raolivei"
PI_PASSWORD="Control01!"
DEVICE="/dev/sda"

run_on_pi() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$1"
}

echo "🔍 Deep Scan for APFS on Extreme SSD"
echo "====================================="
echo ""
echo "Device reports: 476.7 GB to Linux"
echo "Mac reported: 2TB with APFS"
echo ""
echo "Scanning entire device for APFS structures..."
echo ""

# Get device size
DEVICE_SIZE=$(run_on_pi "cat /sys/block/sda/size" | tr -d '\r\n')
echo "Device size in sectors: $DEVICE_SIZE"
echo ""

# Method 1: Scan for APFS magic bytes at various offsets
print_info() { echo "ℹ️  $1"; }
print_success() { echo "✅ $1"; }

print_info "Scanning for APFS magic bytes (NXSB = 4E 58 53 42)..."
print_info "This may take a few minutes..."

# Scan in chunks (every 1GB) for APFS signature
run_on_pi "sudo apt-get install -y pv 2>/dev/null || true"

# Create scan script on Pi
run_on_pi "cat > /tmp/scan_apfs.sh << 'EOF'
#!/bin/bash
DEVICE=$DEVICE
SECTOR_SIZE=512
CHUNK_SIZE=2097152  # 1GB chunks
TOTAL_SECTORS=$DEVICE_SIZE

echo \"Scanning device for APFS signatures...\"
for offset in \$(seq 0 \$CHUNK_SIZE \$TOTAL_SECTORS); do
    if [ \$offset -gt \$TOTAL_SECTORS ]; then
        break
    fi
    # Read 4KB and check for APFS magic
    sudo dd if=\$DEVICE bs=\$SECTOR_SIZE skip=\$offset count=8 2>/dev/null | \
        hexdump -C | grep -q '4e 58 53 42'
    if [ \$? -eq 0 ]; then
        GB=\$((offset * SECTOR_SIZE / 1024 / 1024 / 1024))
        echo \"Found APFS signature at offset: \$offset sectors (~\$GB GB)\"
    fi
    # Progress every 10GB
    if [ \$((offset % 20971520)) -eq 0 ]; then
        GB=\$((offset * SECTOR_SIZE / 1024 / 1024 / 1024))
        echo \"Scanned to ~\$GB GB...\"
    fi
done
EOF
chmod +x /tmp/scan_apfs.sh"

# Run scan in tmux (will take time)
print_info "Starting deep scan in tmux session: apfs-scan"
run_on_pi "tmux new-session -d -s apfs-scan"
run_on_pi "tmux send-keys -t apfs-scan 'sudo /tmp/scan_apfs.sh 2>&1 | tee /tmp/apfs_scan.log' C-m"

echo ""
print_success "Deep scan started in tmux session: apfs-scan"
print_info "Monitor progress: ssh $PI_USER@$PI_HOST && tmux attach -t apfs-scan"
print_info "Or check log: ssh $PI_USER@$PI_HOST 'tail -f /tmp/apfs_scan.log'"
echo ""
print_warning "This scan will take 30-60 minutes for a 2TB drive"
print_info "The scan checks every 1GB for APFS signatures"

