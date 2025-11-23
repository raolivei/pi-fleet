#!/bin/bash
# Move 100GOPRO Folders to NVMe Drive
# Finds all "100GOPRO" folders on the Raspberry Pi and moves them to /mnt/nvme/gopro

set -e

# Cleanup function for interruption
cleanup() {
    if [ -n "$TEMP_FAILED" ] && [ -f "$TEMP_FAILED" ]; then
        rm -f "$TEMP_FAILED"
    fi
    if [ -n "$TEMP_SIZE_FILE" ] && [ -f "$TEMP_SIZE_FILE" ]; then
        rm -f "$TEMP_SIZE_FILE"
    fi
    print_warning "Script interrupted. Partial moves may have occurred."
    exit 130
}

trap cleanup INT TERM

# Configuration
PI_HOST="${PI_HOST:-eldertree.local}"
PI_USER="${PI_USER:-raolivei}"
PI_PASSWORD="${PI_PASSWORD:-}"
DEST_DIR="/mnt/nvme/gopro"

# Validate required tools
if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass is required but not installed"
    echo "Install with: brew install hudochenkov/sshpass/sshpass (macOS) or apt-get install sshpass (Linux)"
    exit 1
fi

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

# Main function
main() {
    print_header "Move 100GOPRO Folders to NVMe"
    print_info "This script will find and move all '100GOPRO' folders to $DEST_DIR"
    echo ""

    # Step 1: Verify NVMe is mounted
    print_header "Step 1: Verifying NVMe Mount"
    
    print_info "Checking if NVMe is mounted..."
    NVME_MOUNTED=$(run_on_pi "mountpoint -q /mnt/nvme && echo 'yes' || echo 'no'" | tr -d '\r\n')
    
    if [ "$NVME_MOUNTED" != "yes" ]; then
        print_error "NVMe is not mounted at /mnt/nvme"
        print_info "Please ensure NVMe is properly mounted before running this script"
        exit 1
    fi
    
    print_success "NVMe is mounted at /mnt/nvme"
    
    # Check available space
    print_info "Checking available space on NVMe..."
    NVME_FREE_STR=$(run_on_pi "df -h /mnt/nvme | tail -1 | awk '{print \$4}'" | tr -d '\r\n')
    NVME_FREE_BYTES=$(run_on_pi "df /mnt/nvme | tail -1 | awk '{print \$4}'" | tr -d '\r\n')
    print_info "Free space on NVMe: $NVME_FREE_STR"
    
    # Check if we have write permissions
    if ! run_on_pi "test -w /mnt/nvme" 2>/dev/null; then
        print_warning "No write permission on /mnt/nvme, will use sudo for operations"
    fi
    echo ""

    # Step 2: Find all 100GOPRO folders
    print_header "Step 2: Finding 100GOPRO Folders"
    
    print_info "Searching for directories named '100GOPRO'..."
    # Find all 100GOPRO folders, excluding those already on NVMe
    GOPRO_FOLDERS=$(run_on_pi "find / -type d -name '100GOPRO' 2>/dev/null | grep -v '^/mnt/nvme' | grep -v '^/proc\|^/sys\|^/dev' || true")
    
    if [ -z "$GOPRO_FOLDERS" ]; then
        print_warning "No '100GOPRO' folders found (excluding /mnt/nvme)"
        print_info "Checking if any already exist on NVMe..."
        EXISTING_ON_NVME=$(run_on_pi "find /mnt/nvme -type d -name '100GOPRO' 2>/dev/null | wc -l" | tr -d '\r\n')
        if [ "$EXISTING_ON_NVME" -gt 0 ]; then
            print_info "Found $EXISTING_ON_NVME '100GOPRO' folder(s) already on NVMe"
        fi
        exit 0
    fi
    
    # Count folders
    FOLDER_COUNT=$(echo "$GOPRO_FOLDERS" | grep -c '100GOPRO' || echo "0")
    print_success "Found $FOLDER_COUNT '100GOPRO' folder(s) to move"
    echo ""
    
    # Display folders
    print_info "Folders to be moved:"
    echo "$GOPRO_FOLDERS" | while read -r folder; do
        if [ -n "$folder" ]; then
            SIZE=$(run_on_pi "du -sh '$folder' 2>/dev/null | awk '{print \$1}'" | tr -d '\r\n')
            echo "  - $folder ($SIZE)"
        fi
    done
    echo ""

    # Step 3: Calculate total size and verify space
    print_header "Step 3: Calculating Total Size"
    
    TOTAL_SIZE_BYTES=0
    TEMP_SIZE_FILE=$(mktemp)
    
    while IFS= read -r folder; do
        if [ -n "$folder" ]; then
            SIZE_BYTES=$(run_on_pi "du -sb '$folder' 2>/dev/null | awk '{print \$1}'" | tr -d '\r\n')
            if [ -n "$SIZE_BYTES" ] && [ "$SIZE_BYTES" -gt 0 ]; then
                SIZE_STR=$(run_on_pi "du -sh '$folder' 2>/dev/null | awk '{print \$1}'" | tr -d '\r\n')
                echo "  $folder: $SIZE_STR"
                echo "$SIZE_BYTES" >> "$TEMP_SIZE_FILE"
            else
                print_warning "Could not determine size for: $folder"
            fi
        fi
    done <<< "$GOPRO_FOLDERS"
    
    # Calculate total
    if [ -f "$TEMP_SIZE_FILE" ] && [ -s "$TEMP_SIZE_FILE" ]; then
        TOTAL_SIZE_BYTES=$(awk '{sum+=$1} END {print sum}' "$TEMP_SIZE_FILE")
    fi
    rm -f "$TEMP_SIZE_FILE"
    
    if [ "$TOTAL_SIZE_BYTES" -gt 0 ]; then
        TOTAL_SIZE_STR=$(run_on_pi "echo $TOTAL_SIZE_BYTES | awk '{printf \"%.2f\", \$1/1024/1024/1024}'" | tr -d '\r\n')
        print_info "Total size to move: ${TOTAL_SIZE_STR}GB"
        
        # Verify we have enough space (add 10% buffer)
        REQUIRED_SPACE=$((TOTAL_SIZE_BYTES + TOTAL_SIZE_BYTES / 10))
        if [ "$REQUIRED_SPACE" -gt "$NVME_FREE_BYTES" ]; then
            print_error "Insufficient space on NVMe!"
            print_warning "Required: ~${TOTAL_SIZE_STR}GB (with 10% buffer)"
            print_warning "Available: $NVME_FREE_STR"
            print_info "Please free up space or use a different destination"
            exit 1
        else
            print_success "Sufficient space available on NVMe"
        fi
    fi
    echo ""

    # Step 4: Confirm before proceeding
    print_header "Step 4: Confirmation"
    
    print_warning "This will:"
    echo "  1. Create destination directory: $DEST_DIR"
    echo "  2. Move all '100GOPRO' folders to $DEST_DIR/"
    echo "  3. Delete original folders after verification"
    echo ""
    
    read -p "Continue with move operation? (y/n): " CONFIRM
    
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        print_info "Operation cancelled"
        exit 0
    fi
    echo ""

    # Step 5: Create destination directory
    print_header "Step 5: Creating Destination Directory"
    
    print_info "Creating $DEST_DIR..."
    run_on_pi "sudo mkdir -p '$DEST_DIR' && sudo chmod 755 '$DEST_DIR'"
    print_success "Destination directory created: $DEST_DIR"
    echo ""

    # Step 6: Move folders
    print_header "Step 6: Moving Folders"
    
    # Use temporary file to track results (since while loop runs in subshell)
    TEMP_FAILED=$(mktemp)
    MOVED_COUNT=0
    
    while IFS= read -r folder; do
        if [ -z "$folder" ]; then
            continue
        fi
        
        FOLDER_NAME=$(basename "$folder")
        FOLDER_PARENT=$(dirname "$folder")
        DEST_PATH="$DEST_DIR/$FOLDER_NAME"
        
        # Handle duplicate names by appending parent directory
        if run_on_pi "test -d '$DEST_PATH'" 2>/dev/null; then
            PARENT_NAME=$(basename "$FOLDER_PARENT")
            DEST_PATH="$DEST_DIR/${PARENT_NAME}_${FOLDER_NAME}"
            print_warning "Folder already exists at destination, using: $DEST_PATH"
        fi
        
        print_info "Moving: $folder"
        print_info "  To: $DEST_PATH"
        
        # Verify folder exists and is accessible
        if ! run_on_pi "test -d '$folder'" 2>/dev/null; then
            print_error "Folder does not exist or is not accessible: $folder"
            echo "$folder" >> "$TEMP_FAILED"
            echo ""
            continue
        fi
        
        # Check if folder is already on NVMe (shouldn't happen due to grep filter, but double-check)
        if echo "$folder" | grep -q "^/mnt/nvme"; then
            print_warning "Folder is already on NVMe, skipping: $folder"
            echo ""
            continue
        fi
        
        # Get original size and file count for verification
        ORIGINAL_SIZE=$(run_on_pi "du -sb '$folder' 2>/dev/null | awk '{print \$1}'" | tr -d '\r\n')
        ORIGINAL_COUNT=$(run_on_pi "find '$folder' -type f 2>/dev/null | wc -l" | tr -d '\r\n')
        
        if [ -z "$ORIGINAL_SIZE" ] || [ "$ORIGINAL_SIZE" = "0" ]; then
            print_error "Cannot determine size of: $folder (may be empty or inaccessible)"
            echo "$folder" >> "$TEMP_FAILED"
            echo ""
            continue
        fi
        
        # Move the folder (using sudo for permissions)
        MOVE_OUTPUT=$(run_on_pi "sudo mv '$folder' '$DEST_PATH' 2>&1")
        MOVE_EXIT_CODE=$?
        
        if [ $MOVE_EXIT_CODE -eq 0 ]; then
            # Verify move was successful
            MOVED_SIZE=$(run_on_pi "du -sb '$DEST_PATH' 2>/dev/null | awk '{print \$1}'" | tr -d '\r\n')
            MOVED_COUNT_FILES=$(run_on_pi "find '$DEST_PATH' -type f 2>/dev/null | wc -l" | tr -d '\r\n')
            
            if [ -n "$MOVED_SIZE" ] && [ "$MOVED_SIZE" = "$ORIGINAL_SIZE" ] && [ "$MOVED_COUNT_FILES" = "$ORIGINAL_COUNT" ]; then
                print_success "Successfully moved: $folder"
                MOVED_COUNT=$((MOVED_COUNT + 1))
                
                # Delete original if it still exists (shouldn't, but double-check)
                if run_on_pi "test -d '$folder'" 2>/dev/null; then
                    print_warning "Original folder still exists, removing..."
                    run_on_pi "sudo rm -rf '$folder'" 2>/dev/null || true
                fi
            else
                print_error "Verification failed for: $folder"
                print_warning "Original size: $ORIGINAL_SIZE, Moved size: ${MOVED_SIZE:-unknown}"
                print_warning "Original files: $ORIGINAL_COUNT, Moved files: ${MOVED_COUNT_FILES:-unknown}"
                echo "$folder" >> "$TEMP_FAILED"
            fi
        else
            print_error "Failed to move: $folder"
            if [ -n "$MOVE_OUTPUT" ]; then
                print_warning "Error: $MOVE_OUTPUT"
            fi
            # Check if folder still exists at source
            if run_on_pi "test -d '$folder'" 2>/dev/null; then
                print_info "Source folder still exists, move failed"
            fi
            # Check if partial move occurred
            if run_on_pi "test -d '$DEST_PATH'" 2>/dev/null; then
                print_warning "Destination folder exists - partial move may have occurred"
                print_info "You may need to manually clean up: $DEST_PATH"
            fi
            echo "$folder" >> "$TEMP_FAILED"
        fi
        
        echo ""
    done <<< "$GOPRO_FOLDERS"
    
    # Count failed folders
    FAILED_COUNT=0
    if [ -f "$TEMP_FAILED" ] && [ -s "$TEMP_FAILED" ]; then
        FAILED_COUNT=$(wc -l < "$TEMP_FAILED" | tr -d ' ')
    fi
    
    # Count actual moved folders
    ACTUAL_MOVED=$(run_on_pi "find '$DEST_DIR' -type d -name '100GOPRO' 2>/dev/null | wc -l" | tr -d '\r\n')

    # Step 7: Summary
    print_header "Step 7: Summary"
    
    print_success "Operation completed!"
    echo ""
    print_info "Folders moved to: $DEST_DIR"
    print_info "Total folders on NVMe: $ACTUAL_MOVED"
    echo ""
    
    if [ "$FAILED_COUNT" -gt 0 ]; then
        print_warning "Some folders failed to move: $FAILED_COUNT"
        if [ -f "$TEMP_FAILED" ]; then
            while IFS= read -r failed; do
                echo "  - $failed"
            done < "$TEMP_FAILED"
        fi
        rm -f "$TEMP_FAILED"
    else
        print_success "All folders moved successfully!"
        rm -f "$TEMP_FAILED"
    fi
    
    echo ""
    print_info "You can verify the move with:"
    echo "  ssh $PI_USER@$PI_HOST 'ls -lh $DEST_DIR'"
    echo ""
}

# Run main function
main "$@"

