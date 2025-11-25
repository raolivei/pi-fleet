#!/bin/bash
# Script to fix broken "Extreme SSD" Finder references

VOLUME_PATH="/Volumes/Extreme SSD"
VOLUME_NAME="Extreme SSD"

echo "🔧 Fixing Extreme SSD Finder access..."
echo ""

# Step 1: Check if volume is mounted
if [ ! -d "$VOLUME_PATH" ]; then
    echo "❌ Volume not found. Trying to mount..."
    
    # Try to find and mount the disk
    DISK_ID=$(diskutil list | grep -i "Extreme SSD" | awk '{print $NF}' | head -1)
    if [ -n "$DISK_ID" ]; then
        echo "📀 Found disk: $DISK_ID"
        diskutil mount "$DISK_ID" 2>&1
        sleep 2
    else
        echo "❌ Could not find Extreme SSD disk"
        echo "   Please make sure the drive is connected"
        exit 1
    fi
fi

if [ ! -d "$VOLUME_PATH" ]; then
    echo "❌ Volume still not accessible"
    exit 1
fi

echo "✅ Volume is mounted at: $VOLUME_PATH"
echo ""

# Step 2: Restart Finder to clear stale references
echo "🔄 Restarting Finder..."
killall Finder 2>/dev/null
sleep 2
echo "✅ Finder restarted"
echo ""

# Step 3: Open volume directly
echo "📂 Opening volume in Finder..."
open "$VOLUME_PATH" 2>&1 && echo "✅ Opened successfully"
echo ""

# Step 4: Instructions for fixing sidebar
echo "📌 If you still see the error in Finder sidebar:"
echo "   1. In Finder, look for 'Extreme SSD' in the sidebar"
echo "   2. Right-click on it and select 'Remove from Sidebar'"
echo "   3. To re-add it:"
echo "      - Press Cmd+Shift+C (Go to Computer)"
echo "      - Navigate to /Volumes/"
echo "      - Drag 'Extreme SSD' to the Finder sidebar"
echo ""

# Step 5: Verify access
echo "🧪 Verifying access..."
if [ -d "$VOLUME_PATH" ]; then
    echo "✅ Volume is accessible"
    echo "   Path: $VOLUME_PATH"
    echo ""
    echo "💡 You can now access it via:"
    echo "   - Direct path: $VOLUME_PATH"
    echo "   - Finder: open \"$VOLUME_PATH\""
    echo "   - Alias: ~/Extreme-SSD (if created)"
else
    echo "❌ Volume is not accessible"
fi




