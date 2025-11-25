#!/bin/bash
# Extreme SSD Data Recovery Utility
# Comprehensive recovery tool for APFS volumes on Raspberry Pi
# Handles PhotoRec recovery, APFS mounting, and disk imaging

set -e

# Configuration
PI_HOST="${PI_HOST:-eldertree.local}"
PI_USER="${PI_USER:-raolivei}"
PI_PASSWORD="${PI_PASSWORD:-}"
TMUX_SESSION="photorec-recovery"

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

# Helper functions
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

# Run command on Pi
run_on_pi() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$1"
}

# Main recovery function
main() {
    print_header "Extreme SSD Data Recovery Utility"
    print_warning "This tool recovers data from corrupted APFS volumes"
    print_info "All long operations run in tmux sessions"
    echo ""

    # Step 1: Detect drive
    print_header "Step 1: Detecting Extreme SSD"
    
    print_info "Scanning for connected drives..."
    DRIVES=$(run_on_pi "lsblk -o NAME,SIZE,MODEL,MOUNTPOINT | grep -v '^loop\|^zram'")
    echo "$DRIVES"
    echo ""
    
    # Auto-detect or prompt
    SOURCE_DEVICE=$(run_on_pi "lsblk -o NAME,SIZE,MODEL | grep -i 'extreme\|sandisk\|2.0T' | head -1 | awk '{print \$1}'" | tr -d '\r\n')
    
    if [ -z "$SOURCE_DEVICE" ]; then
        print_warning "Could not auto-detect Extreme SSD"
        read -p "Enter device name (e.g., sda, sdb): " SOURCE_DEVICE_INPUT
        SOURCE_DEVICE="$SOURCE_DEVICE_INPUT"
    fi
    
    SOURCE_DEVICE="/dev/$SOURCE_DEVICE"
    print_success "Source device: $SOURCE_DEVICE"
    
    # Check if device exists
    if ! run_on_pi "test -b $SOURCE_DEVICE" 2>/dev/null; then
        print_error "Device $SOURCE_DEVICE not found"
        exit 1
    fi
    
    # Step 2: Select recovery destination
    print_header "Step 2: Selecting Recovery Destination"
    
    print_info "Checking available storage..."
    STORAGE=$(run_on_pi "df -h | grep -E '/dev/sd|/dev/mmc|/dev/nvme|/mnt/' | grep -v 'boot'")
    echo "$STORAGE"
    echo ""
    
    print_warning "You need 900+ GB free for full recovery (823 GB data)"
    echo ""
    read -p "Enter recovery destination path (e.g., /mnt/nvme/recovered_files): " RECOVERY_DEST
    
    if [ -z "$RECOVERY_DEST" ]; then
        print_error "Recovery destination required"
        exit 1
    fi
    
    # Create destination
    run_on_pi "sudo mkdir -p '$RECOVERY_DEST' && sudo chmod 777 '$RECOVERY_DEST'"
    print_success "Recovery destination: $RECOVERY_DEST"
    
    # Check free space
    FREE_SPACE=$(run_on_pi "df -h '$RECOVERY_DEST' 2>/dev/null | tail -1 | awk '{print \$4}'" | tr -d '\r\n')
    print_info "Free space: $FREE_SPACE"
    
    # Step 3: Install tools
    print_header "Step 3: Installing Recovery Tools"
    
    print_info "Checking for required tools..."
    MISSING_TOOLS=()
    
    for tool in photorec testdisk; do
        if ! run_on_pi "which $tool" >/dev/null 2>&1; then
            MISSING_TOOLS+=("$tool")
        fi
    done
    
    if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
        print_warning "Missing tools: ${MISSING_TOOLS[*]}"
        print_info "Installing..."
        run_on_pi "sudo apt-get update && sudo apt-get install -y testdisk" || {
            print_error "Failed to install tools"
            exit 1
        }
    else
        print_success "All tools installed"
    fi
    
    # Step 4: Start PhotoRec
    print_header "Step 4: Starting PhotoRec Recovery"
    
    print_info "PhotoRec will recover files even from APFS partitions Linux can't see"
    print_warning "This will take 8-24 hours"
    echo ""
    
    read -p "Start PhotoRec recovery now? (y/n): " START_RECOVERY
    
    if [ "$START_RECOVERY" != "y" ] && [ "$START_RECOVERY" != "Y" ]; then
        print_info "Recovery cancelled"
        exit 0
    fi
    
    # Kill existing session if any
    run_on_pi "tmux kill-session -t $TMUX_SESSION 2>/dev/null || true"
    
    # Start PhotoRec in tmux
    print_info "Starting PhotoRec in tmux session: $TMUX_SESSION"
    
    run_on_pi "tmux new-session -d -s $TMUX_SESSION"
    run_on_pi "tmux send-keys -t $TMUX_SESSION 'cd $RECOVERY_DEST' C-m"
    run_on_pi "tmux send-keys -t $TMUX_SESSION 'clear' C-m"
    run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"PhotoRec Recovery - Extreme SSD\"' C-m"
    run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"Source: $SOURCE_DEVICE\"' C-m"
    run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"Destination: $RECOVERY_DEST\"' C-m"
    run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"\"' C-m"
    run_on_pi "tmux send-keys -t $TMUX_SESSION 'sudo photorec $SOURCE_DEVICE' C-m"
    
    print_success "PhotoRec started in tmux session!"
    echo ""
    
    # Instructions
    print_header "Recovery Instructions"
    
    echo "1. Connect to PhotoRec:"
    echo "   ssh $PI_USER@$PI_HOST"
    echo "   tmux attach -t $TMUX_SESSION"
    echo ""
    echo "2. In PhotoRec interface:"
    echo "   - Select [Proceed]"
    echo "   - Disk: $SOURCE_DEVICE"
    echo "   - Partition: [Whole disk] or [No partition]"
    echo "   - Filesystem: [Other]"
    echo "   - File types: [All] or select specific"
    echo "   - Destination: $RECOVERY_DEST"
    echo "   - Press Y to start"
    echo ""
    echo "3. Detach from tmux:"
    echo "   Press Ctrl+B, then D"
    echo "   (Recovery continues in background)"
    echo ""
    echo "4. Monitor progress:"
    echo "   ssh $PI_USER@$PI_HOST 'ls -lh $RECOVERY_DEST/recup_dir.* 2>/dev/null | wc -l'"
    echo ""
    echo "5. Check recovery log:"
    echo "   ssh $PI_USER@$PI_HOST 'tail -f $RECOVERY_DEST/photorec.log'"
    echo ""
    print_warning "Recovery will take 8-24 hours. Be patient!"
}

# Run main function
main "$@"

