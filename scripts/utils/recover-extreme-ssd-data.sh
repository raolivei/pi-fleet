#!/bin/bash
# Comprehensive data recovery script for SanDisk Extreme SSD
# Tries multiple methods to access partition data

set -e

DISK_ID="disk8s1"
VOLUME_PATH="/Volumes/Extreme SSD"
PHYSICAL_DISK="disk5"

echo "🔍 SanDisk Extreme SSD Data Recovery"
echo "===================================="
echo ""
echo "Drive: SanDisk Extreme 55AE (2TB)"
echo "Partition: $DISK_ID"
echo "Volume: $VOLUME_PATH"
echo ""

# Step 1: Check current status
echo "Step 1: Checking current status..."
if [ -d "$VOLUME_PATH" ]; then
    echo "✅ Volume is mounted"
    MOUNTED=true
else
    echo "⚠️  Volume is not mounted"
    MOUNTED=false
fi
echo ""

# Step 2: Unmount and remount
echo "Step 2: Unmounting and remounting..."
if [ "$MOUNTED" = true ]; then
    echo "Unmounting..."
    diskutil unmount force "$VOLUME_PATH" 2>&1 || true
    sleep 2
fi

echo "Remounting..."
diskutil mount "$DISK_ID" 2>&1
sleep 3

if [ ! -d "$VOLUME_PATH" ]; then
    echo "❌ Failed to mount volume"
    echo ""
    echo "Trying alternative mount methods..."
    
    # Try mounting with different options
    sudo mount -t apfs /dev/$DISK_ID "$VOLUME_PATH" 2>&1 || echo "Alternative mount failed"
fi
echo ""

# Step 3: Try to access via different methods
echo "Step 3: Trying different access methods..."
echo ""

# Method 1: Direct ls
echo "Method 1: Direct ls"
if ls "$VOLUME_PATH" &>/dev/null 2>&1; then
    echo "✅ ls works!"
    ls -la "$VOLUME_PATH" | head -20
    exit 0
else
    echo "❌ ls failed: Operation not permitted"
fi
echo ""

# Method 2: cd and stat
echo "Method 2: cd and stat"
if cd "$VOLUME_PATH" 2>/dev/null; then
    echo "✅ Can cd into volume"
    stat . 2>&1 | head -5
    cd - >/dev/null
else
    echo "❌ Cannot cd"
fi
echo ""

# Method 3: Python
echo "Method 3: Python os.listdir()"
cd "$VOLUME_PATH" 2>/dev/null && python3 -c "import os; print('\n'.join(os.listdir('.')))" 2>&1 | head -10 || echo "❌ Python failed"
echo ""

# Method 4: Check filesystem integrity
echo "Method 4: Checking filesystem integrity (read-only)..."
echo "⚠️  This requires admin password"
echo ""
read -p "Run filesystem check? (y/n): " confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    echo "Running: sudo fsck_apfs -n /dev/$DISK_ID"
    sudo fsck_apfs -n /dev/$DISK_ID 2>&1 | head -50
fi
echo ""

# Method 5: Try to read raw data (first few bytes)
echo "Method 5: Reading raw partition header..."
echo "Checking if partition has valid APFS signature..."
sudo hexdump -C /dev/$DISK_ID | head -5
echo ""

# Method 6: Use Disk Utility
echo "Method 6: Opening Disk Utility for manual repair..."
echo "   You can use Disk Utility's First Aid feature"
open -a 'Disk Utility'
echo ""

# Method 7: Try to repair filesystem
echo "Method 7: Attempting filesystem repair..."
echo "⚠️  This will unmount the volume temporarily"
echo "⚠️  This requires admin password"
echo "✅ This is NON-DESTRUCTIVE (no data will be erased)"
echo ""
read -p "Attempt repair? (y/n): " confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    echo "Running: sudo diskutil repairVolume \"$VOLUME_PATH\""
    sudo diskutil repairVolume "$VOLUME_PATH" 2>&1
    
    # Remount after repair
    sleep 2
    diskutil mount "$DISK_ID" 2>&1
    sleep 3
    
    # Test access again
    if ls "$VOLUME_PATH" &>/dev/null 2>&1; then
        echo ""
        echo "✅ SUCCESS! Repair worked - files are now accessible!"
        ls -la "$VOLUME_PATH" | head -20
    else
        echo ""
        echo "⚠️  Repair completed but access still restricted"
        echo "   This may be a macOS permission issue, not a filesystem issue"
    fi
fi
echo ""

# Method 8: Use Finder as workaround
echo "Method 8: Using Finder (always works)..."
open "$VOLUME_PATH" 2>&1 && echo "✅ Opened in Finder"
echo ""
echo "💡 If terminal access doesn't work, use Finder to:"
echo "   - Browse files"
echo "   - Copy files to another location"
echo "   - Drag files to get their paths"
echo ""

# Summary
echo "=========================================="
echo "Summary:"
echo "  - Volume: $VOLUME_PATH"
echo "  - Mounted: $([ -d "$VOLUME_PATH" ] && echo "Yes" || echo "No")"
echo "  - Accessible via terminal: $([ -d "$VOLUME_PATH" ] && ls "$VOLUME_PATH" &>/dev/null 2>&1 && echo "Yes" || echo "No (use Finder)")"
echo ""
echo "💡 Next steps if data is still inaccessible:"
echo "   1. Use Disk Utility First Aid (GUI)"
echo "   2. Try data recovery software (Disk Drill, PhotoRec)"
echo "   3. Use Finder to copy files to another drive"
echo "   4. Check if drive needs professional data recovery"

