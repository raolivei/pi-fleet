#!/bin/bash
# Script to list files in volumes using available methods
# Since direct ls/find don't work, this tries multiple approaches

VOLUME_PATH="$1"

if [ -z "$VOLUME_PATH" ]; then
    echo "Usage: $0 <volume_path>"
    echo "Example: $0 \"/Volumes/Time Machine\""
    exit 1
fi

if [ ! -d "$VOLUME_PATH" ]; then
    echo "❌ Volume not found: $VOLUME_PATH"
    exit 1
fi

echo "🔍 Attempting to list files in: $VOLUME_PATH"
echo ""

# Method 1: Try Python
echo "Method 1: Python os.listdir()"
cd "$VOLUME_PATH" 2>/dev/null && python3 -c "import os; files = os.listdir('.'); print('\n'.join(files))" 2>&1 | head -20
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ Python method worked!"
    exit 0
fi
echo ""

# Method 2: Try Ruby
echo "Method 2: Ruby Dir.entries()"
cd "$VOLUME_PATH" 2>/dev/null && ruby -e "puts Dir.entries('.').reject { |e| e.start_with?('.') && e != '.' && e != '..' }" 2>&1 | head -20
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ Ruby method worked!"
    exit 0
fi
echo ""

# Method 3: Use Finder via AppleScript (interactive)
echo "Method 3: Opening in Finder (interactive selection)"
open "$VOLUME_PATH"
echo "✅ Opened in Finder - please browse files manually"
echo ""
echo "💡 Alternative: Use Finder to select files, then:"
echo "   - Drag files to terminal to get paths"
echo "   - Use Cmd+Option+C in Finder to copy file paths"
echo ""

# Method 4: Try stat on known common directories
echo "Method 4: Checking for common directories..."
cd "$VOLUME_PATH" 2>/dev/null
for dir in Backups.backupdb "Time Machine Backups" .Spotlight-V100 .fseventsd .Trashes; do
    if [ -d "$dir" ] 2>/dev/null; then
        echo "   Found directory: $dir"
    fi
done

echo ""
echo "⚠️  Direct file listing is restricted due to macOS security"
echo "💡 Use Finder to browse files: open \"$VOLUME_PATH\""




