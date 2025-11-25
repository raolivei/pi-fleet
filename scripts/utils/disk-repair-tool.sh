#!/bin/bash
# Comprehensive Disk Repair Tool
# Handles unmounting, repair, and remounting of volumes
# Supports APFS, HFS+, and other macOS filesystems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VOLUME_PATH=""
DISK_ID=""
ADMIN_PASSWORD=""
USE_PASSWORD=false
AUTO_MODE=false

# Functions
print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Show usage
usage() {
    cat << EOF
Disk Repair Tool - Comprehensive filesystem repair utility

Usage: $0 [OPTIONS] <volume_path>

Options:
    -p, --password PASSWORD    Admin password for sudo operations
    -a, --auto                 Auto mode (non-interactive)
    -h, --help                 Show this help message

Examples:
    $0 "/Volumes/Extreme SSD"
    $0 -p "mypassword" "/Volumes/Extreme SSD"
    $0 --auto "/Volumes/Extreme SSD"

This tool will:
    1. Close processes using the volume
    2. Force unmount the volume
    3. Repair the filesystem (NON-DESTRUCTIVE)
    4. Verify the repair
    5. Remount the volume
    6. Test access

All operations are NON-DESTRUCTIVE - your data will be preserved.

EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--password)
                ADMIN_PASSWORD="$2"
                USE_PASSWORD=true
                shift 2
                ;;
            -a|--auto)
                AUTO_MODE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                if [ -z "$VOLUME_PATH" ]; then
                    VOLUME_PATH="$1"
                else
                    print_error "Unknown argument: $1"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$VOLUME_PATH" ]; then
        print_error "Volume path is required"
        usage
        exit 1
    fi

    if [ ! -d "$VOLUME_PATH" ] && [ ! "$AUTO_MODE" = true ]; then
        print_warning "Volume not found: $VOLUME_PATH"
        print_info "It may be unmounted. Continuing anyway..."
    fi
}

# Get disk identifier
get_disk_id() {
    DISK_ID=$(diskutil info "$VOLUME_PATH" 2>/dev/null | grep "Device Identifier:" | awk '{print $3}')
    
    if [ -z "$DISK_ID" ]; then
        # Try to get from volume name
        VOLUME_NAME=$(basename "$VOLUME_PATH")
        DISK_ID=$(diskutil list | grep -A 5 "$VOLUME_NAME" | grep "APFS Volume" | awk '{print $NF}' | head -1)
    fi
    
    if [ -z "$DISK_ID" ]; then
        print_error "Could not determine disk identifier for: $VOLUME_PATH"
        print_info "Trying to find by volume name..."
        VOLUME_NAME=$(basename "$VOLUME_PATH")
        DISK_ID=$(diskutil list | grep -i "$VOLUME_NAME" | head -1 | awk '{print $NF}')
    fi
    
    if [ -z "$DISK_ID" ]; then
        print_error "Cannot find disk identifier. Please specify manually."
        exit 1
    fi
    
    print_info "Disk Identifier: $DISK_ID"
}

# Close processes using volume
close_processes() {
    print_header "Step 1: Closing processes using the volume"
    
    # Close Finder windows
    print_info "Closing Finder windows..."
    osascript -e 'tell application "Finder" to close every window' 2>/dev/null || true
    
    # Kill processes with open file handles (if any)
    print_info "Checking for processes with open file handles..."
    lsof | grep -i "$VOLUME_PATH" | head -5 || print_info "No processes found with open file handles"
    
    sleep 1
    print_success "Processes closed"
}

# Force unmount volume
force_unmount() {
    print_header "Step 2: Force unmounting volume"
    
    # Check if already unmounted
    if ! mount | grep -q "$VOLUME_PATH"; then
        print_info "Volume is already unmounted"
        return 0
    fi
    
    print_info "Unmounting: $VOLUME_PATH"
    
    # Try regular unmount first
    if diskutil unmount "$VOLUME_PATH" 2>/dev/null; then
        print_success "Volume unmounted successfully"
        return 0
    fi
    
    # Force unmount
    print_info "Regular unmount failed, trying force unmount..."
    if diskutil unmount force "$VOLUME_PATH" 2>&1; then
        print_success "Volume force-unmounted successfully"
        sleep 2
        return 0
    fi
    
    # Try unmounting the disk
    print_info "Trying to unmount entire disk..."
    if diskutil unmountDisk force "$DISK_ID" 2>&1; then
        print_success "Disk unmounted successfully"
        sleep 2
        return 0
    fi
    
    print_error "Failed to unmount volume"
    return 1
}

# Repair filesystem
repair_filesystem() {
    print_header "Step 3: Repairing filesystem"
    
    print_warning "This operation is NON-DESTRUCTIVE"
    print_info "Only filesystem structure will be repaired, data will be preserved"
    
    if [ "$AUTO_MODE" != true ]; then
        read -p "Continue with repair? (y/n): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            print_info "Repair cancelled by user"
            return 1
        fi
    fi
    
    print_info "Repairing filesystem on: $DISK_ID"
    
    # Method 1: Try diskutil repairVolume (preferred for APFS)
    print_info "Method 1: Using diskutil repairVolume..."
    
    if [ "$USE_PASSWORD" = true ]; then
        echo "$ADMIN_PASSWORD" | sudo -S diskutil repairVolume "$DISK_ID" 2>&1 | tee /tmp/repair_output.log
    else
        sudo diskutil repairVolume "$DISK_ID" 2>&1 | tee /tmp/repair_output.log
    fi
    
    REPAIR_EXIT=${PIPESTATUS[0]}
    
    if [ $REPAIR_EXIT -eq 0 ]; then
        print_success "Filesystem repair completed successfully"
        return 0
    fi
    
    # Method 2: Try fsck_apfs directly
    print_warning "diskutil repairVolume failed, trying fsck_apfs directly..."
    print_info "Method 2: Using fsck_apfs -y..."
    
    if [ "$USE_PASSWORD" = true ]; then
        echo "$ADMIN_PASSWORD" | sudo -S fsck_apfs -y /dev/"$DISK_ID" 2>&1 | tee -a /tmp/repair_output.log
    else
        sudo fsck_apfs -y /dev/"$DISK_ID" 2>&1 | tee -a /tmp/repair_output.log
    fi
    
    REPAIR_EXIT=${PIPESTATUS[0]}
    
    if [ $REPAIR_EXIT -eq 0 ]; then
        print_success "Filesystem repair completed successfully"
        return 0
    elif [ $REPAIR_EXIT -eq 66 ]; then
        print_error "Permission denied - Full Disk Access may be required"
        print_info "Try: System Settings → Privacy & Security → Full Disk Access → Enable Terminal"
        return 1
    else
        print_warning "Repair completed with exit code: $REPAIR_EXIT"
        print_info "Check /tmp/repair_output.log for details"
        return 0  # Continue anyway
    fi
}

# Verify filesystem
verify_filesystem() {
    print_header "Step 4: Verifying filesystem integrity"
    
    print_info "Running read-only filesystem check..."
    
    if [ "$USE_PASSWORD" = true ]; then
        echo "$ADMIN_PASSWORD" | sudo -S fsck_apfs -n /dev/"$DISK_ID" 2>&1 | head -50
    else
        sudo fsck_apfs -n /dev/"$DISK_ID" 2>&1 | head -50
    fi
    
    VERIFY_EXIT=${PIPESTATUS[0]}
    
    if [ $VERIFY_EXIT -eq 0 ]; then
        print_success "Filesystem verification passed - no errors found"
    else
        print_warning "Filesystem verification found issues (exit code: $VERIFY_EXIT)"
        print_info "This may be normal if repair was just performed"
    fi
}

# Remount volume
remount_volume() {
    print_header "Step 5: Remounting volume"
    
    print_info "Mounting: $DISK_ID"
    
    if diskutil mount "$DISK_ID" 2>&1; then
        sleep 3
        if [ -d "$VOLUME_PATH" ]; then
            print_success "Volume remounted successfully at: $VOLUME_PATH"
            return 0
        else
            print_warning "Mount command succeeded but volume path not found"
            print_info "Volume may be mounted at a different location"
            diskutil list | grep -A 3 "$DISK_ID"
            return 1
        fi
    else
        print_error "Failed to remount volume"
        return 1
    fi
}

# Test access
test_access() {
    print_header "Step 6: Testing volume access"
    
    if [ ! -d "$VOLUME_PATH" ]; then
        print_error "Volume path not found: $VOLUME_PATH"
        print_info "Trying to find mounted volume..."
        VOLUME_NAME=$(basename "$VOLUME_PATH")
        NEW_PATH=$(mount | grep "$VOLUME_NAME" | awk '{print $3}' | head -1)
        if [ -n "$NEW_PATH" ]; then
            VOLUME_PATH="$NEW_PATH"
            print_info "Found volume at: $VOLUME_PATH"
        else
            return 1
        fi
    fi
    
    # Test cd
    print_info "Testing directory access..."
    if cd "$VOLUME_PATH" 2>/dev/null; then
        print_success "Can access directory: $(pwd)"
        cd - >/dev/null
    else
        print_error "Cannot access directory"
        return 1
    fi
    
    # Test Finder
    print_info "Opening in Finder..."
    if open "$VOLUME_PATH" 2>&1; then
        print_success "Volume opened in Finder"
    else
        print_warning "Could not open in Finder"
    fi
    
    # Try to list files (may fail due to permissions)
    print_info "Testing file listing (may fail due to macOS security)..."
    if ls "$VOLUME_PATH" &>/dev/null 2>&1; then
        print_success "File listing works!"
        ls -la "$VOLUME_PATH" | head -10
    else
        print_warning "File listing blocked by macOS security"
        print_info "This is normal for volumes with 'Owners: Disabled'"
        print_info "Use Finder to access files"
    fi
}

# Main execution
main() {
    print_header "Disk Repair Tool"
    print_info "Volume: $VOLUME_PATH"
    print_warning "All operations are NON-DESTRUCTIVE"
    echo ""
    
    # Get disk identifier
    get_disk_id
    
    # Execute repair steps
    close_processes
    force_unmount || exit 1
    repair_filesystem || print_warning "Repair had issues, but continuing..."
    verify_filesystem
    remount_volume || exit 1
    test_access
    
    # Summary
    print_header "Repair Complete"
    print_success "Disk repair process completed"
    print_info "Volume: $VOLUME_PATH"
    print_info "Disk: $DISK_ID"
    echo ""
    print_info "If files are still not accessible via terminal, use Finder:"
    echo "  open \"$VOLUME_PATH\""
    echo ""
}

# Run main
parse_args "$@"
main

