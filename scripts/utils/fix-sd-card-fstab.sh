#!/bin/bash
# Fix fstab on SD card mounted on another system
# Usage: sudo ./fix-sd-card-fstab.sh /mnt/sd-root

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

MOUNT_POINT="${1:-/mnt/sd-root}"

echo -e "${BLUE}=== SD Card fstab Fix Tool ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    echo -e "${RED}❌ Mount point not found: $MOUNT_POINT${NC}"
    echo ""
    echo "Usage: sudo $0 /path/to/mounted/sd/root"
    echo ""
    echo "Example:"
    echo "  1. Mount SD card root partition:"
    echo "     sudo mkdir -p /mnt/sd-root"
    echo "     sudo mount /dev/sdb2 /mnt/sd-root  # Linux"
    echo "     sudo mount -t ext4 /dev/disk2s2 /mnt/sd-root  # macOS"
    echo ""
    echo "  2. Run this script:"
    echo "     sudo $0 /mnt/sd-root"
    exit 1
fi

# Check if fstab exists
if [ ! -f "$MOUNT_POINT/etc/fstab" ]; then
    echo -e "${RED}❌ fstab not found at $MOUNT_POINT/etc/fstab${NC}"
    echo "Are you sure this is the root partition?"
    exit 1
fi

echo -e "${YELLOW}Mount point: $MOUNT_POINT${NC}"
echo -e "${YELLOW}fstab location: $MOUNT_POINT/etc/fstab${NC}"
echo ""

# Show current fstab
echo -e "${BLUE}Current fstab:${NC}"
cat "$MOUNT_POINT/etc/fstab"
echo ""

# Backup fstab
BACKUP_FILE="$MOUNT_POINT/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"
echo -e "${YELLOW}Creating backup: $BACKUP_FILE${NC}"
cp "$MOUNT_POINT/etc/fstab" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created${NC}"
echo ""

# Fix fstab - add nofail to non-critical mounts
echo -e "${YELLOW}Fixing fstab...${NC}"

# Create temporary file for sed operations
TEMP_FSTAB=$(mktemp)

# Process each line
while IFS= read -r line; do
    # Skip comments and empty lines
    if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
        echo "$line" >> "$TEMP_FSTAB"
        continue
    fi
    
    # Check if this is a mount line
    if [[ "$line" =~ ^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+)[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+ ]]; then
        OPTIONS="${BASH_REMATCH[1]}"
        
        # Skip root and boot partitions
        if [[ "$line" =~ (root|boot|/dev/mmcblk0p|/dev/nvme0n1p1|/dev/nvme0n1p2) ]]; then
            echo "$line" >> "$TEMP_FSTAB"
            continue
        fi
        
        # If options don't contain nofail, add it
        if [[ ! "$OPTIONS" =~ nofail ]]; then
            # Add nofail to defaults
            if [[ "$OPTIONS" =~ defaults ]]; then
                NEW_LINE=$(echo "$line" | sed 's/defaults/defaults,nofail/g')
                echo "$NEW_LINE" >> "$TEMP_FSTAB"
                echo -e "${GREEN}  Fixed: $(echo "$line" | awk '{print $2}')${NC}"
            else
                # Add nofail to existing options
                NEW_LINE=$(echo "$line" | sed "s/$OPTIONS/$OPTIONS,nofail/g")
                echo "$NEW_LINE" >> "$TEMP_FSTAB"
                echo -e "${GREEN}  Fixed: $(echo "$line" | awk '{print $2}')${NC}"
            fi
        else
            # Already has nofail
            echo "$line" >> "$TEMP_FSTAB"
        fi
    else
        # Not a mount line, keep as is
        echo "$line" >> "$TEMP_FSTAB"
    fi
done < "$MOUNT_POINT/etc/fstab"

# Replace fstab with fixed version
mv "$TEMP_FSTAB" "$MOUNT_POINT/etc/fstab"

echo ""
echo -e "${GREEN}✓ fstab fixed${NC}"
echo ""

# Show fixed fstab
echo -e "${BLUE}Fixed fstab:${NC}"
cat "$MOUNT_POINT/etc/fstab"
echo ""

echo -e "${GREEN}=== Fix Complete ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Unmount the SD card:"
echo "     sudo umount $MOUNT_POINT"
echo ""
echo "  2. Put SD card back in node-1"
echo ""
echo "  3. Boot node-1 - it should boot normally now"
echo ""
echo "  4. Once booted, fix NVMe boot configuration"
echo ""

