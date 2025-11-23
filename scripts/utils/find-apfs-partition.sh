#!/bin/bash
# Find hidden APFS partition on Extreme SSD
# Linux may not see APFS in partition table, need to scan raw device

set -e

PI_HOST="${PI_HOST:-eldertree.local}"
PI_USER="${PI_USER:-raolivei}"
PI_PASSWORD="${PI_PASSWORD:-}"

# Validate required environment variables
if [ -z "$PI_PASSWORD" ]; then
    echo "Error: PI_PASSWORD environment variable is required"
    echo "Usage: PI_PASSWORD='your-password' $0"
    exit 1
fi

DEVICE="/dev/sda"

print_info() { echo "ℹ️  $1"; }
print_success() { echo "✅ $1"; }
print_warning() { echo "⚠️  $1"; }

run_on_pi() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$1"
}

echo "🔍 Searching for APFS partition on Extreme SSD"
echo "=============================================="
echo ""

# Method 1: Check if apfs-fuse can detect it
print_info "Method 1: Trying apfs-fuse on raw device..."
if run_on_pi "which apfs-fuse" >/dev/null 2>&1; then
    print_info "apfs-fuse is installed"
    
    # Try mounting raw device (APFS containers can span multiple partitions)
    MOUNT_POINT="/mnt/apfs_scan"
    run_on_pi "sudo mkdir -p $MOUNT_POINT"
    
    # Try different offsets where APFS might be
    for offset in "0" "512" "4096" "1048576"; do
        print_info "Trying offset $offset..."
        if run_on_pi "sudo apfs-fuse -o offset=$offset $DEVICE $MOUNT_POINT 2>&1" | grep -q "mounted\|Mounted"; then
            print_success "Found APFS at offset $offset!"
            run_on_pi "ls -lah $MOUNT_POINT | head -20"
            break
        fi
    done
else
    print_warning "apfs-fuse not installed"
fi

echo ""

# Method 2: Scan for APFS magic bytes
print_info "Method 2: Scanning for APFS magic bytes (NXSB signature)..."
APFS_OFFSETS=$(run_on_pi "sudo hexdump -C $DEVICE | grep -a '4e 58 53 42' | head -5" || echo "")

if [ -n "$APFS_OFFSETS" ]; then
    print_success "Found APFS signatures!"
    echo "$APFS_OFFSETS"
else
    print_warning "No APFS signatures found in first scan"
fi

echo ""

# Method 3: Check GPT partition table (if exists)
print_info "Method 3: Checking for GPT partition table..."
GPT_INFO=$(run_on_pi "sudo gdisk -l $DEVICE 2>&1 | grep -A 20 'GPT\|APFS\|found' || sudo sgdisk -p $DEVICE 2>&1 | head -30")

if [ -n "$GPT_INFO" ]; then
    echo "$GPT_INFO"
    # Look for APFS partitions in GPT
    APFS_GPT=$(echo "$GPT_INFO" | grep -i "apfs\|48465300-0000-11AA-AA11-00306543ECAC")
    if [ -n "$APFS_GPT" ]; then
        print_success "Found APFS partition in GPT table!"
    fi
else
    print_warning "No GPT table found (or gdisk not available)"
fi

echo ""

# Method 4: Use testdisk to analyze partition structure
print_info "Method 4: Analyzing partition structure with testdisk..."
print_warning "This may reveal hidden partitions"

# Create testdisk command file for non-interactive analysis
run_on_pi "cat > /tmp/testdisk_analyze.cfg << 'EOF'
1
EOF
"

# Try to get partition info (testdisk needs interactive, but we can try)
PARTITION_INFO=$(run_on_pi "sudo testdisk /list $DEVICE 2>&1 || sudo fdisk -l $DEVICE 2>&1")

echo "$PARTITION_INFO"

echo ""

# Method 5: Check device size vs partition size
print_info "Method 5: Comparing device size to partition size..."
DEVICE_SIZE=$(run_on_pi "cat /sys/block/sda/size")
PARTITION_SIZE=$(run_on_pi "cat /sys/block/sda/sda1/size 2>/dev/null || echo '0'")

echo "Device total sectors: $DEVICE_SIZE"
echo "Partition 1 sectors: $PARTITION_SIZE"

if [ "$DEVICE_SIZE" -gt "$PARTITION_SIZE" ]; then
    DIFF=$((DEVICE_SIZE - PARTITION_SIZE))
    DIFF_GB=$((DIFF * 512 / 1024 / 1024 / 1024))
    print_warning "Unallocated space detected: ~${DIFF_GB} GB"
    print_info "This might be where the APFS partition is!"
fi

echo ""

# Method 6: Try to access unallocated space directly
if [ "$DEVICE_SIZE" -gt "$PARTITION_SIZE" ]; then
    print_info "Method 6: Scanning unallocated space for APFS..."
    START_SECTOR=$((PARTITION_SIZE + 1))
    print_info "Scanning from sector $START_SECTOR..."
    
    # Sample a few MB from unallocated area
    SAMPLE_OFFSET=$((START_SECTOR * 512))
    APFS_CHECK=$(run_on_pi "sudo dd if=$DEVICE bs=512 skip=$START_SECTOR count=8192 2>/dev/null | hexdump -C | grep -i '4e 58 53 42\|apfs' | head -3" || echo "")
    
    if [ -n "$APFS_CHECK" ]; then
        print_success "Found APFS signature in unallocated space!"
        echo "$APFS_CHECK"
    else
        print_warning "No APFS signature found in sampled area"
    fi
fi

echo ""
print_info "Summary:"
print_info "If APFS partition found, we can mount it with:"
print_info "  sudo apfs-fuse /dev/sdaX /mnt/apfs -o allow_other"
print_info "Or if at specific offset:"
print_info "  sudo apfs-fuse -o offset=XXXXX /dev/sda /mnt/apfs"

