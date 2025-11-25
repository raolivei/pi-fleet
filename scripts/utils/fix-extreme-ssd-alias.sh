#!/bin/bash
# Script to fix broken "Extreme SSD" aliases and ensure the volume is accessible

VOLUME_PATH="/Volumes/Extreme SSD"
VOLUME_NAME="Extreme SSD"

echo "🔧 Fixing Extreme SSD access issues..."
echo ""

# Check if volume is mounted
if [ ! -d "$VOLUME_PATH" ]; then
    echo "❌ Volume not found at $VOLUME_PATH"
    echo "   Please make sure the Extreme SSD is connected and mounted."
    exit 1
fi

echo "✅ Volume is mounted at: $VOLUME_PATH"
echo ""

# Step 1: Open the volume directly in Finder
echo "📂 Opening volume in Finder..."
open "$VOLUME_PATH" 2>&1 && echo "✅ Opened successfully"
echo ""

# Step 2: Restart Finder to refresh
echo "🔄 Restarting Finder..."
killall Finder 2>/dev/null
sleep 2
echo "✅ Finder restarted"
echo ""

# Step 3: Find and report broken aliases
echo "🔍 Searching for broken aliases..."
BROKEN_FOUND=false

# Check common locations
for location in ~/Desktop ~/Documents ~/Downloads; do
    if [ -d "$location" ]; then
        find "$location" -name "*Extreme*" -o -name "*extreme*" 2>/dev/null | while read item; do
            if [ -L "$item" ]; then
                target=$(readlink "$item" 2>/dev/null || echo "")
                if [ -z "$target" ] || [ ! -e "$target" ]; then
                    echo "   Found broken alias: $item"
                    BROKEN_FOUND=true
                fi
            fi
        done
    fi
done

if [ "$BROKEN_FOUND" = false ]; then
    echo "   No broken aliases found in common locations"
fi
echo ""

# Step 4: Create a working alias in home directory
echo "🔗 Creating working alias in home directory..."
rm -f ~/Extreme-SSD
ln -s "$VOLUME_PATH" ~/Extreme-SSD 2>/dev/null && echo "✅ Created: ~/Extreme-SSD"
echo ""

# Step 5: Add to Finder sidebar (if not already there)
echo "📌 To add to Finder sidebar:"
echo "   1. Open Finder"
echo "   2. Press Cmd+Shift+C (Go to Computer)"
echo "   3. Navigate to /Volumes/"
echo "   4. Drag 'Extreme SSD' to the Finder sidebar"
echo ""

# Step 6: Test access
echo "🧪 Testing access..."
if [ -d "$VOLUME_PATH" ]; then
    echo "✅ Volume is accessible"
    echo "   Path: $VOLUME_PATH"
    echo "   Alias: ~/Extreme-SSD"
    echo ""
    echo "💡 You can now access it via:"
    echo "   - Direct path: $VOLUME_PATH"
    echo "   - Alias: ~/Extreme-SSD"
    echo "   - Finder: open \"$VOLUME_PATH\""
else
    echo "❌ Volume is not accessible"
fi







