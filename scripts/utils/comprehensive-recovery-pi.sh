#!/bin/bash
# Comprehensive Extreme SSD Data Recovery on Raspberry Pi
# Uses tmux for long operations, prompts for device selection

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

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}$1${NC}"
    echo "=========================================="
    echo ""
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Function to run command on Pi
run_on_pi() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$1"
}

# Function to run command in tmux session
run_in_tmux() {
    local SESSION_NAME="$1"
    local COMMAND="$2"
    
    # Create or attach to tmux session
    run_on_pi "tmux new-session -d -s '$SESSION_NAME' 2>/dev/null || tmux attach-session -t '$SESSION_NAME' -d"
    
    # Send command to tmux session
    run_on_pi "tmux send-keys -t '$SESSION_NAME' '$COMMAND' C-m"
    
    print_info "Command running in tmux session: $SESSION_NAME"
    print_info "Attach with: ssh $PI_USER@$PI_HOST && tmux attach -t $SESSION_NAME"
}

print_header "Comprehensive Extreme SSD Data Recovery"
print_warning "This will recover 823 GB of CRITICAL data"
print_info "All long operations will run in tmux sessions"
echo ""

# Step 1: Detect drive
print_header "Step 1: Detecting Extreme SSD"

print_info "Checking connected drives..."
DRIVE_INFO=$(run_on_pi "lsblk -o NAME,SIZE,MODEL | grep -i '2.0T\|extreme\|sandisk' || lsblk -o NAME,SIZE")

if [ -z "$DRIVE_INFO" ]; then
    print_error "Could not detect Extreme SSD"
    print_info "Listing all drives:"
    run_on_pi "lsblk"
    exit 1
fi

echo "$DRIVE_INFO"
echo ""

# Get device name
SOURCE_DEVICE=$(run_on_pi "lsblk -o NAME,SIZE,MODEL | grep -i '2.0T\|extreme\|sandisk' | head -1 | awk '{print \$1}'" | tr -d '\r\n')

if [ -z "$SOURCE_DEVICE" ]; then
    print_warning "Could not auto-detect, please identify device manually"
    run_on_pi "lsblk -o NAME,SIZE,MODEL"
    read -p "Enter device name (e.g., sda, sdb): " SOURCE_DEVICE_INPUT
    SOURCE_DEVICE="$SOURCE_DEVICE_INPUT"
fi

SOURCE_DEVICE="/dev/$SOURCE_DEVICE"
print_success "Source device: $SOURCE_DEVICE"

# Check if mounted
MOUNTED=$(run_on_pi "mount | grep $SOURCE_DEVICE | awk '{print \$3}'" | head -1 | tr -d '\r\n')
if [ -n "$MOUNTED" ]; then
    print_warning "Device is mounted at: $MOUNTED"
    print_info "Unmounting..."
    run_on_pi "sudo umount $SOURCE_DEVICE* 2>/dev/null || true"
fi

echo ""

# Step 2: Check drive health
print_header "Step 2: Checking Drive Health"

print_info "Checking SMART status..."
run_on_pi "sudo smartctl -a $SOURCE_DEVICE 2>/dev/null | head -30 || echo 'SMART not available'"

echo ""

# Step 3: Device selection for recovery
print_header "Step 3: Selecting Recovery Destination"

print_info "Checking available space on Extreme SSD..."
EXTREME_FREE=$(run_on_pi "df -h | grep -i 'extreme\|sandisk' | awk '{print \$4}'" | head -1 | tr -d '\r\n' || echo "0")

print_info "Checking all available drives..."
ALL_DRIVES=$(run_on_pi "lsblk -o NAME,SIZE,MOUNTPOINT,FSTYPE | grep -E '^[a-z]'")

echo "$ALL_DRIVES"
echo ""

print_warning "RECOVERY DESTINATION SELECTION"
print_info "You need to choose where to save recovered files:"
print_info "  - Option 1: Use Extreme SSD itself (if enough free space)"
print_info "  - Option 2: Use another external drive"
print_info "  - Option 3: Use Pi's internal storage (if enough space)"
echo ""

# Check Extreme SSD free space
if [ -n "$EXTREME_FREE" ] && [ "$EXTREME_FREE" != "0" ]; then
    print_info "Extreme SSD free space: $EXTREME_FREE"
    print_warning "Using Extreme SSD for recovery means:"
    print_warning "  - Recovered files will be on the same drive"
    print_warning "  - Need at least 900 GB free (for 823 GB + overhead)"
    echo ""
    read -p "Use Extreme SSD for recovery? (y/n): " USE_EXTREME
else
    USE_EXTREME="n"
fi

if [ "$USE_EXTREME" = "y" ] || [ "$USE_EXTREME" = "Y" ]; then
    # Find mount point of Extreme SSD
    RECOVERY_MOUNT=$(run_on_pi "mount | grep -i 'extreme\|sandisk' | awk '{print \$3}'" | head -1 | tr -d '\r\n')
    if [ -z "$RECOVERY_MOUNT" ]; then
        print_info "Mounting Extreme SSD..."
        RECOVERY_MOUNT="/mnt/extreme_recovery"
        run_on_pi "sudo mkdir -p $RECOVERY_MOUNT"
        # Try to mount (will need to identify partition)
        PARTITION=$(run_on_pi "ls ${SOURCE_DEVICE}* | grep -E '[0-9]+' | head -1" | tr -d '\r\n')
        if [ -n "$PARTITION" ]; then
            run_on_pi "sudo mount $PARTITION $RECOVERY_MOUNT 2>/dev/null || echo 'Mount failed'"
        fi
    fi
    RECOVERY_PATH="$RECOVERY_MOUNT/recovered_files"
else
    print_info "Please identify recovery destination:"
    run_on_pi "df -h | grep -E '/dev/sd|/dev/mmc'"
    read -p "Enter mount point or device path: " RECOVERY_INPUT
    
    if [ -n "$RECOVERY_INPUT" ]; then
        RECOVERY_PATH="$RECOVERY_INPUT/recovered_files"
    else
        print_error "Recovery destination required"
        exit 1
    fi
fi

print_success "Recovery destination: $RECOVERY_PATH"
run_on_pi "sudo mkdir -p '$RECOVERY_PATH'"
echo ""

# Step 4: Install tools
print_header "Step 4: Installing Recovery Tools"

print_info "Installing required tools on Pi..."
run_in_tmux "install-tools" "sudo apt-get update && sudo apt-get install -y testdisk gddrescue apfs-fuse smartmontools && echo 'Tools installed successfully'"

print_info "Waiting for installation to complete..."
sleep 10

# Check if tools are installed
TOOLS_OK=true
for tool in photorec ddrescue apfs-fuse smartctl; do
    if ! run_on_pi "which $tool" >/dev/null 2>&1; then
        print_warning "$tool not found, may need manual installation"
        TOOLS_OK=false
    fi
done

if [ "$TOOLS_OK" = true ]; then
    print_success "All tools installed"
else
    print_warning "Some tools missing, continuing anyway"
fi

echo ""

# Step 5: Create disk image
print_header "Step 5: Creating Disk Image Backup"

print_warning "This will create a full disk image (2TB)"
print_info "This protects the original drive and allows multiple recovery attempts"
print_info "Estimated time: 4-8 hours"
echo ""

read -p "Create disk image backup? (strongly recommended) (y/n): " CREATE_IMAGE

if [ "$CREATE_IMAGE" = "y" ] || [ "$CREATE_IMAGE" = "Y" ]; then
    IMAGE_PATH="$RECOVERY_PATH/extreme_ssd_image.img"
    LOG_PATH="$RECOVERY_PATH/ddrescue.log"
    
    print_info "Starting ddrescue in tmux session: ddrescue-backup"
    print_info "Image will be saved to: $IMAGE_PATH"
    
    # Create tmux session and run ddrescue
    run_on_pi "tmux new-session -d -s ddrescue-backup"
    run_on_pi "tmux send-keys -t ddrescue-backup 'sudo ddrescue -f -n $SOURCE_DEVICE $IMAGE_PATH $LOG_PATH' C-m"
    
    print_success "ddrescue started in tmux session: ddrescue-backup"
    print_info "Monitor progress: ssh $PI_USER@$PI_HOST && tmux attach -t ddrescue-backup"
    print_info "Or check log: ssh $PI_USER@$PI_HOST 'tail -f $LOG_PATH'"
    echo ""
    print_warning "This will take 4-8 hours. You can detach and come back later."
    echo ""
    read -p "Press Enter to continue to next step (ddrescue will continue in background)..."
else
    IMAGE_PATH=""
    print_info "Skipping disk image (not recommended for critical data)"
fi

echo ""

# Step 6: Try APFS mount
print_header "Step 6: Attempting APFS Mount"

print_info "Trying to mount APFS volume read-only..."
MOUNT_POINT="/mnt/extreme_ssd"

run_on_pi "sudo mkdir -p $MOUNT_POINT"

# Find APFS partition
APFS_PARTITION=$(run_on_pi "sudo blkid $SOURCE_DEVICE* | grep -i apfs | head -1 | cut -d: -f1" | tr -d '\r\n')

if [ -z "$APFS_PARTITION" ]; then
    # Try first partition
    APFS_PARTITION="${SOURCE_DEVICE}1"
fi

print_info "Attempting to mount: $APFS_PARTITION"

if run_on_pi "sudo apfs-fuse $APFS_PARTITION $MOUNT_POINT -o allow_other" 2>/dev/null; then
    sleep 2
    if run_on_pi "mount | grep $MOUNT_POINT" >/dev/null 2>&1; then
        print_success "APFS mounted successfully!"
        print_info "Listing files..."
        FILE_COUNT=$(run_on_pi "find $MOUNT_POINT -type f 2>/dev/null | wc -l" | tr -d '\r\n')
        print_info "Files found: $FILE_COUNT"
        
        if [ "$FILE_COUNT" -gt 0 ]; then
            print_success "Files are accessible via APFS mount!"
            print_info "Starting file extraction in tmux..."
            
            EXTRACT_PATH="$RECOVERY_PATH/apfs_extracted"
            run_on_pi "sudo mkdir -p $EXTRACT_PATH"
            
            run_in_tmux "apfs-extract" "sudo rsync -av --progress $MOUNT_POINT/ $EXTRACT_PATH/ 2>&1 | tee $RECOVERY_PATH/extract.log"
            
            print_success "File extraction started in tmux session: apfs-extract"
            APFS_WORKED=true
        else
            print_warning "Mount succeeded but no files found"
            APFS_WORKED=false
        fi
    else
        print_warning "Mount command succeeded but volume not mounted"
        APFS_WORKED=false
    fi
else
    print_warning "APFS mount failed - metadata likely corrupted"
    APFS_WORKED=false
fi

echo ""

# Step 7: PhotoRec recovery
print_header "Step 7: PhotoRec File Recovery"

if [ "$APFS_WORKED" != "true" ]; then
    print_info "APFS mount failed, using PhotoRec for file-by-file recovery"
    print_warning "PhotoRec will:"
    print_warning "  - Recover files by file signatures"
    print_warning "  - NOT preserve directory structure or filenames"
    print_warning "  - Organize files by type"
    print_info "Estimated time: 8-24 hours"
    echo ""
    
    read -p "Start PhotoRec recovery? (y/n): " START_PHOTOREC
    
    if [ "$START_PHOTOREC" = "y" ] || [ "$START_PHOTOREC" = "Y" ]; then
        PHOTOREC_PATH="$RECOVERY_PATH/photorec_recovered"
        run_on_pi "sudo mkdir -p $PHOTOREC_PATH"
        
        # Use image if available, otherwise use device
        if [ -n "$IMAGE_PATH" ] && [ -f "$IMAGE_PATH" ]; then
            RECOVERY_SOURCE="$IMAGE_PATH"
            print_info "Using disk image for recovery (safer)"
        else
            RECOVERY_SOURCE="$SOURCE_DEVICE"
            print_warning "Using device directly (image recommended)"
        fi
        
        print_info "Starting PhotoRec in tmux session: photorec-recovery"
        print_info "Recovery destination: $PHOTOREC_PATH"
        
        # PhotoRec needs to be run interactively or with specific parameters
        # For automation, we'll create a script
        run_on_pi "cat > /tmp/photorec_auto.sh << 'PHOTOREC_EOF'
#!/bin/bash
cd $PHOTOREC_PATH
photorec /log $PHOTOREC_PATH/photorec.log $RECOVERY_SOURCE <<EOF
1
1
1
1
1
y
EOF
PHOTOREC_EOF
sudo chmod +x /tmp/photorec_auto.sh"
        
        run_in_tmux "photorec-recovery" "sudo /tmp/photorec_auto.sh"
        
        print_success "PhotoRec started in tmux session: photorec-recovery"
        print_info "Monitor: ssh $PI_USER@$PI_HOST && tmux attach -t photorec-recovery"
    fi
else
    print_info "APFS mount worked, PhotoRec may not be needed"
    print_info "But you can run it anyway to catch any missed files"
    read -p "Run PhotoRec anyway? (y/n): " RUN_ANYWAY
    if [ "$RUN_ANYWAY" = "y" ]; then
        # Same PhotoRec setup as above
        print_info "PhotoRec setup would go here"
    fi
fi

echo ""

# Summary
print_header "Recovery Operations Started"

print_success "Recovery operations are running in tmux sessions"
echo ""
print_info "Active tmux sessions:"
run_on_pi "tmux list-sessions 2>/dev/null || echo 'No tmux sessions'"
echo ""
print_info "To monitor progress:"
print_info "  ssh $PI_USER@$PI_HOST"
print_info "  tmux attach -t <session-name>"
echo ""
print_info "Recovery destination: $RECOVERY_PATH"
print_info "Recovered files will be in:"
if [ "$APFS_WORKED" = "true" ]; then
    print_info "  - $RECOVERY_PATH/apfs_extracted (from APFS mount)"
fi
if [ "$START_PHOTOREC" = "y" ] || [ "$START_PHOTOREC" = "Y" ]; then
    print_info "  - $RECOVERY_PATH/photorec_recovered (from PhotoRec)"
fi
if [ -n "$IMAGE_PATH" ]; then
    print_info "  - $IMAGE_PATH (disk image backup)"
fi
echo ""
print_warning "Recovery will take many hours. Check back periodically."
print_info "All operations are logged and can be resumed if interrupted."

