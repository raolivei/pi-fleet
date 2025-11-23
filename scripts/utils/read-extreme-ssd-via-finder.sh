#!/bin/bash
# Read Extreme SSD directory structure via Finder/AppleScript
# This bypasses terminal permission restrictions

VOLUME_PATH="/Volumes/Extreme SSD"

echo "🔍 Reading Extreme SSD directory structure via Finder..."
echo ""

if [ ! -d "$VOLUME_PATH" ]; then
    echo "❌ Volume not mounted: $VOLUME_PATH"
    exit 1
fi

# Open in Finder first
open "$VOLUME_PATH"
sleep 2

# Try to get directory listing via AppleScript
echo "Attempting to read directory structure..."
echo ""

osascript <<'EOF' 2>&1
tell application "Finder"
    try
        -- Try to access the volume
        set volPath to POSIX file "/Volumes/Extreme SSD"
        
        -- Try different methods to access
        try
            set volFolder to volPath as alias
            set fileList to name of every item of volFolder
            return "Files found: " & (count of fileList) & " items\n" & (fileList as string)
        on error
            -- Try using disk name
            set diskList to name of every disk
            repeat with diskName in diskList
                if diskName contains "Extreme" then
                    set fileList to name of every item of disk diskName
                    return "Files found on " & diskName & ": " & (count of fileList) & " items\n" & (fileList as string)
                end if
            end repeat
            return "Could not access volume via Finder"
        end try
    on error errMsg
        return "Error: " & errMsg
    end try
end tell
EOF

echo ""
echo "💡 If the above didn't work, the volume is open in Finder."
echo "   You can manually browse and see the files there."
echo ""
echo "💡 To get file paths from Finder:"
echo "   1. Select a file in Finder"
echo "   2. Press Cmd+Option+C to copy the file path"
echo "   3. Or drag the file to terminal to see its path"

