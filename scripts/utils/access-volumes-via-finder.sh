#!/bin/bash
# Helper script to access Time Machine and Extreme SSD volumes via Finder
# Since terminal access is restricted, this uses Finder for file operations

set -e

VOLUME_TIME_MACHINE="/Volumes/Time Machine"
VOLUME_EXTREME_SSD="/Volumes/Extreme SSD"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "🔍 Volume Access Helper (via Finder)"
echo "======================================"
echo ""

# Function to open volume in Finder
open_volume() {
    local volume_path="$1"
    local volume_name="$2"
    
    if [ -d "$volume_path" ]; then
        echo "📂 Opening $volume_name..."
        open "$volume_path" 2>/dev/null && echo "✅ Opened successfully"
        return 0
    else
        echo "❌ Volume not found: $volume_path"
        return 1
    fi
}

# Function to list files using AppleScript (via Finder)
list_files_via_finder() {
    local volume_path="$1"
    local volume_name="$2"
    
    echo "📋 Listing files in $volume_name (via Finder)..."
    
    osascript <<EOF 2>/dev/null || echo "⚠️  Could not list files via AppleScript"
tell application "Finder"
    set volFolder to POSIX file "$volume_path" as alias
    set fileList to name of every item of volFolder
    return fileList
end tell
EOF
}

# Function to copy file using Finder
copy_file_via_finder() {
    local source_path="$1"
    local dest_path="$2"
    local item_name="$3"
    
    echo "📋 Copying $item_name..."
    
    osascript <<EOF 2>/dev/null || return 1
tell application "Finder"
    set sourceItem to POSIX file "$source_path" as alias
    set destFolder to POSIX file "$dest_path" as alias
    duplicate sourceItem to destFolder
end tell
EOF
}

# Function to get file path from user selection
select_file_from_finder() {
    local volume_path="$1"
    local volume_name="$2"
    
    echo "📂 Please select a file from $volume_name in Finder..."
    echo "   (This will open Finder - select a file and we'll get its path)"
    
    open "$volume_path"
    
    osascript <<EOF 2>/dev/null || echo ""
tell application "Finder"
    activate
    set theFile to choose file with prompt "Select a file from $volume_name:"
    return POSIX path of theFile
end tell
EOF
}

# Main menu
show_menu() {
    echo ""
    echo "Options:"
    echo "  1) Open Time Machine volume in Finder"
    echo "  2) Open Extreme SSD volume in Finder"
    echo "  3) Open both volumes in Finder"
    echo "  4) List files in Time Machine (via Finder)"
    echo "  5) List files in Extreme SSD (via Finder)"
    echo "  6) Copy file from volume to project"
    echo "  7) Exit"
    echo ""
    read -p "Select option (1-7): " choice
    
    case $choice in
        1)
            open_volume "$VOLUME_TIME_MACHINE" "Time Machine"
            ;;
        2)
            open_volume "$VOLUME_EXTREME_SSD" "Extreme SSD"
            ;;
        3)
            open_volume "$VOLUME_TIME_MACHINE" "Time Machine"
            open_volume "$VOLUME_EXTREME_SSD" "Extreme SSD"
            ;;
        4)
            list_files_via_finder "$VOLUME_TIME_MACHINE" "Time Machine"
            ;;
        5)
            list_files_via_finder "$VOLUME_EXTREME_SSD" "Extreme SSD"
            ;;
        6)
            echo ""
            echo "Which volume?"
            echo "  1) Time Machine"
            echo "  2) Extreme SSD"
            read -p "Select (1-2): " vol_choice
            
            if [ "$vol_choice" = "1" ]; then
                VOLUME="$VOLUME_TIME_MACHINE"
                VOLUME_NAME="Time Machine"
            elif [ "$vol_choice" = "2" ]; then
                VOLUME="$VOLUME_EXTREME_SSD"
                VOLUME_NAME="Extreme SSD"
            else
                echo "❌ Invalid choice"
                return
            fi
            
            FILE_PATH=$(select_file_from_finder "$VOLUME" "$VOLUME_NAME")
            
            if [ -n "$FILE_PATH" ]; then
                read -p "Copy to project directory? (y/n): " confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    FILE_NAME=$(basename "$FILE_PATH")
                    DEST="$PROJECT_ROOT"
                    
                    if copy_file_via_finder "$FILE_PATH" "$DEST" "$FILE_NAME"; then
                        echo "✅ Copied $FILE_NAME to $DEST"
                    else
                        echo "❌ Failed to copy. Try dragging manually from Finder."
                    fi
                fi
            fi
            ;;
        7)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid option"
            ;;
    esac
}

# Check if volumes are mounted
echo "Checking volumes..."
TIME_MACHINE_MOUNTED=false
EXTREME_SSD_MOUNTED=false

if [ -d "$VOLUME_TIME_MACHINE" ]; then
    TIME_MACHINE_MOUNTED=true
    echo "✅ Time Machine: Mounted"
else
    echo "❌ Time Machine: Not mounted"
fi

if [ -d "$VOLUME_EXTREME_SSD" ]; then
    EXTREME_SSD_MOUNTED=true
    echo "✅ Extreme SSD: Mounted"
else
    echo "❌ Extreme SSD: Not mounted"
fi

echo ""

# If running interactively, show menu
if [ -t 0 ]; then
    while true; do
        show_menu
    done
else
    # Non-interactive: just open both volumes
    echo "Opening volumes in Finder..."
    [ "$TIME_MACHINE_MOUNTED" = true ] && open_volume "$VOLUME_TIME_MACHINE" "Time Machine"
    [ "$EXTREME_SSD_MOUNTED" = true ] && open_volume "$VOLUME_EXTREME_SSD" "Extreme SSD"
fi




