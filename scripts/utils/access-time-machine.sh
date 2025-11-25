#!/bin/bash
# Workaround script to access Time Machine volume when Full Disk Access isn't working
# Uses Finder and other methods that don't require Full Disk Access

VOLUME="/Volumes/Time Machine"
VOLUME_EXTREME="/Volumes/Extreme SSD"

echo "🔍 Accessing Time Machine volume (workaround method)"
echo ""

# Method 1: Open in Finder (always works)
echo "📂 Opening in Finder..."
open "$VOLUME" 2>/dev/null && echo "✅ Opened Time Machine in Finder"
open "$VOLUME_EXTREME" 2>/dev/null && echo "✅ Opened Extreme SSD in Finder"
echo ""

# Method 2: Try to get path via osascript
echo "🔍 Getting volume path via AppleScript..."
VOLUME_PATH=$(osascript -e 'tell application "Finder" to get POSIX path of disk "Time Machine"' 2>/dev/null)
if [ -n "$VOLUME_PATH" ]; then
    echo "✅ Volume path: $VOLUME_PATH"
else
    echo "⚠️  Could not get path via AppleScript"
fi
echo ""

# Method 3: Create symlink in home directory (if we can cd into it)
echo "🔗 Creating symlink in home directory..."
if cd "$VOLUME" 2>/dev/null; then
    ln -sf "$VOLUME" ~/time-machine 2>/dev/null && echo "✅ Created symlink: ~/time-machine"
    cd - >/dev/null
else
    echo "⚠️  Cannot create symlink (cd failed)"
fi
echo ""

# Method 4: Use mdfind (Spotlight) - might work
echo "🔍 Searching with Spotlight (mdfind)..."
mdfind -onlyin "$VOLUME" "kMDItemFSName == '*'" 2>/dev/null | head -5
echo ""

echo "💡 Workarounds:"
echo "   1. Use Finder: open \"$VOLUME\""
echo "   2. Access via symlink: cd ~/time-machine (if created)"
echo "   3. Copy files via Finder drag-and-drop"
echo ""
echo "⚠️  For full terminal access, Full Disk Access must be enabled and Cursor restarted"








