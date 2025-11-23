#!/bin/bash
# Data Recovery Script for Extreme SSD
# Since terminal access is blocked, this uses alternative methods

set -e

VOLUME_PATH="/Volumes/Extreme SSD"
DISK_ID="disk8s1"
PHYSICAL_DISK="disk5"

echo "🔍 Extreme SSD Data Recovery"
echo "============================"
echo ""
echo "Volume shows 823.1 GB used but files are not visible"
echo "This may indicate filesystem metadata corruption"
echo ""

# Check if PhotoRec is available
if command -v photorec &> /dev/null; then
    echo "✅ PhotoRec is installed"
    PHOTOREC_AVAILABLE=true
else
    echo "⚠️  PhotoRec not installed"
    echo "   Install with: brew install testdisk"
    PHOTOREC_AVAILABLE=false
fi

echo ""
echo "Recovery Options:"
echo ""

# Option 1: Try to repair filesystem metadata
echo "Option 1: Repair filesystem metadata"
echo "   This may restore file visibility"
echo ""
read -p "Attempt filesystem metadata repair? (y/n): " confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    echo ""
    echo "Unmounting volume..."
    diskutil unmount force "$VOLUME_PATH" 2>&1 || true
    sleep 2
    
    echo "Running filesystem repair..."
    echo "monkeys-37" | sudo -S diskutil repairVolume "$DISK_ID" 2>&1 || echo "Repair failed, continuing..."
    
    echo "Remounting..."
    diskutil mount "$DISK_ID" 2>&1
    sleep 3
    
    echo "✅ Repair completed"
    echo "   Check Finder to see if files are now visible"
fi

echo ""

# Option 2: Use PhotoRec to recover files
if [ "$PHOTOREC_AVAILABLE" = true ]; then
    echo "Option 2: Use PhotoRec to recover files"
    echo "   PhotoRec can recover files even from corrupted filesystems"
    echo "   It recovers files by file type (photos, documents, etc.)"
    echo ""
    read -p "Run PhotoRec recovery? (y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo ""
        echo "⚠️  PhotoRec will need:"
        echo "   1. A destination folder for recovered files"
        echo "   2. The physical disk device: /dev/$PHYSICAL_DISK"
        echo ""
        read -p "Enter destination folder for recovered files: " DEST_FOLDER
        
        if [ -d "$DEST_FOLDER" ]; then
            echo ""
            echo "Starting PhotoRec..."
            echo "⚠️  This will be interactive - follow the prompts"
            echo ""
            photorec /log "$DEST_FOLDER/photorec.log" /dev/"$PHYSICAL_DISK"
        else
            echo "❌ Destination folder not found: $DEST_FOLDER"
        fi
    fi
else
    echo "Option 2: Install PhotoRec for file recovery"
    echo "   Run: brew install testdisk"
    echo "   Then run this script again"
fi

echo ""

# Option 3: Check for alternative mount points
echo "Option 3: Check for alternative access methods"
echo "   Sometimes files are accessible via different paths"
echo ""

# Try to find if volume is mounted elsewhere
ALTERNATIVE_PATH=$(mount | grep "Extreme SSD" | awk '{print $3}' | head -1)
if [ -n "$ALTERNATIVE_PATH" ] && [ "$ALTERNATIVE_PATH" != "$VOLUME_PATH" ]; then
    echo "   Found alternative mount: $ALTERNATIVE_PATH"
    echo "   Try accessing: $ALTERNATIVE_PATH"
fi

echo ""

# Option 4: Professional recovery
echo "Option 4: Professional Data Recovery"
echo "   If files are critical and other methods fail:"
echo "   - DriveSavers (drivesavers.com)"
echo "   - Ontrack (ontrack.com)"
echo "   - Cost: $300-$3000+ depending on damage"
echo ""

# Summary
echo "=========================================="
echo "Summary:"
echo "  - Volume has 823.1 GB of data"
echo "  - Files are not visible (likely metadata corruption)"
echo "  - Terminal access is blocked by macOS security"
echo ""
echo "Next Steps:"
echo "  1. Check Finder again (hidden files are now visible)"
echo "  2. Try Option 1 (filesystem repair)"
echo "  3. If that fails, use PhotoRec (Option 2)"
echo "  4. Last resort: Professional recovery (Option 4)"
echo ""

