#!/bin/bash
# Safe disk repair script - does NOT erase data
# This script performs non-destructive disk repairs

set -e

VOLUME_PATH="$1"

if [ -z "$VOLUME_PATH" ]; then
    echo "Usage: $0 <volume_path>"
    echo "Example: $0 \"/Volumes/Extreme SSD\""
    echo "Example: $0 \"/Volumes/Time Machine\""
    exit 1
fi

if [ ! -d "$VOLUME_PATH" ]; then
    echo "❌ Volume not found: $VOLUME_PATH"
    exit 1
fi

VOLUME_NAME=$(basename "$VOLUME_PATH")
echo "🔧 Safe Disk Repair for: $VOLUME_NAME"
echo "======================================"
echo ""
echo "⚠️  This will require your admin password"
echo "✅ All operations are NON-DESTRUCTIVE (no data will be erased)"
echo ""

# Get disk identifier
DISK_ID=$(diskutil info "$VOLUME_PATH" | grep "Device Identifier:" | awk '{print $3}')
if [ -z "$DISK_ID" ]; then
    echo "❌ Could not determine disk identifier"
    exit 1
fi

echo "📀 Disk Identifier: $DISK_ID"
echo ""

# Step 1: Verify file system (read-only check)
echo "Step 1: Verifying file system (read-only check)..."
echo "   This checks for errors without making changes"
echo ""
read -p "Continue? (y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "Running: sudo diskutil verifyVolume \"$VOLUME_PATH\""
echo "Enter your password when prompted:"
echo ""

sudo diskutil verifyVolume "$VOLUME_PATH" 2>&1
VERIFY_EXIT=$?

if [ $VERIFY_EXIT -eq 0 ]; then
    echo ""
    echo "✅ File system verification passed - no errors found!"
    echo "   Your disk is healthy, no repair needed."
    exit 0
else
    echo ""
    echo "⚠️  File system verification found issues"
    echo ""
fi

# Step 2: Repair file system (if errors found)
if [ $VERIFY_EXIT -ne 0 ]; then
    echo "Step 2: Repairing file system..."
    echo "   This will fix errors found in verification"
    echo "   ⚠️  The volume will be unmounted during repair"
    echo "   ✅ Your data will NOT be erased"
    echo ""
    read -p "Continue with repair? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Cancelled"
        exit 0
    fi
    
    echo ""
    echo "Running: sudo diskutil repairVolume \"$VOLUME_PATH\""
    echo "Enter your password when prompted:"
    echo ""
    
    sudo diskutil repairVolume "$VOLUME_PATH" 2>&1
    REPAIR_EXIT=$?
    
    if [ $REPAIR_EXIT -eq 0 ]; then
        echo ""
        echo "✅ Disk repair completed successfully!"
        echo ""
        
        # Remount if needed
        if [ ! -d "$VOLUME_PATH" ]; then
            echo "Remounting volume..."
            sudo diskutil mount "$DISK_ID" 2>&1
        fi
        
        echo "✅ Volume is ready to use"
    else
        echo ""
        echo "⚠️  Repair completed with warnings or errors"
        echo "   Check the output above for details"
    fi
fi

echo ""
echo "💡 Additional safe repair options:"
echo "   1. First Aid in Disk Utility (GUI):"
echo "      - Open Disk Utility"
echo "      - Select the volume"
echo "      - Click 'First Aid' → 'Run'"
echo ""
echo "   2. Check disk health:"
echo "      diskutil info \"$VOLUME_PATH\" | grep -i smart"
echo ""
echo "   3. If issues persist, backup data and consider:"
echo "      - Reformatting (ERASES DATA - last resort)"
echo "      - Professional data recovery service"


