#!/bin/bash
# Check disk health without making changes

VOLUME_PATH="$1"

if [ -z "$VOLUME_PATH" ]; then
    echo "Usage: $0 <volume_path>"
    echo "Example: $0 \"/Volumes/Extreme SSD\""
    exit 1
fi

if [ ! -d "$VOLUME_PATH" ]; then
    echo "❌ Volume not found: $VOLUME_PATH"
    exit 1
fi

echo "🔍 Disk Health Check: $(basename "$VOLUME_PATH")"
echo "=========================================="
echo ""

# Get disk info
DISK_ID=$(diskutil info "$VOLUME_PATH" | grep "Device Identifier:" | awk '{print $3}')
echo "📀 Disk Information:"
diskutil info "$VOLUME_PATH" | grep -E "Volume Name|File System|Mounted|Owners|Encrypted|Journaled|Case-sensitive|Protocol|SMART" | sed 's/^/   /'
echo ""

# Check if SMART is available
SMART_STATUS=$(diskutil info "$VOLUME_PATH" | grep "SMART Status:" | awk -F': ' '{print $2}')
if [ -n "$SMART_STATUS" ]; then
    echo "💾 SMART Status: $SMART_STATUS"
    if [ "$SMART_STATUS" = "Verified" ]; then
        echo "   ✅ Disk hardware is healthy"
    else
        echo "   ⚠️  Disk hardware may have issues"
    fi
    echo ""
fi

# Check mount status
MOUNTED=$(diskutil info "$VOLUME_PATH" | grep "Mounted:" | awk -F': ' '{print $2}')
if [ "$MOUNTED" = "Yes" ]; then
    echo "📊 Volume Statistics:"
    df -h "$VOLUME_PATH" | tail -1 | awk '{print "   Total: " $2 " | Used: " $3 " | Available: " $4 " | Usage: " $5}'
    echo ""
fi

# Check for common issues
echo "🔍 Checking for common issues..."
echo ""

# Check if volume is case-sensitive (can cause issues)
CASE_SENSITIVE=$(diskutil info "$VOLUME_PATH" | grep "Case-sensitive:" | awk -F': ' '{print $2}')
if [ "$CASE_SENSITIVE" = "Yes" ]; then
    echo "   ⚠️  Volume is case-sensitive (may cause compatibility issues)"
else
    echo "   ✅ Volume is case-insensitive (standard)"
fi

# Check owners
OWNERS=$(diskutil info "$VOLUME_PATH" | grep "Owners:" | awk -F': ' '{print $2}')
if [ "$OWNERS" = "Disabled" ]; then
    echo "   ⚠️  Owners disabled (may cause permission issues)"
else
    echo "   ✅ Owners enabled"
fi

# Check encryption
ENCRYPTED=$(diskutil info "$VOLUME_PATH" | grep "Encrypted:" | awk -F': ' '{print $2}')
if [ "$ENCRYPTED" = "Yes" ]; then
    echo "   ✅ Volume is encrypted"
else
    echo "   ℹ️  Volume is not encrypted"
fi

echo ""
echo "💡 To repair disk (if needed):"
echo "   ./scripts/utils/repair-disk-safe.sh \"$VOLUME_PATH\""
echo ""
echo "💡 Or use Disk Utility GUI:"
echo "   open -a 'Disk Utility'"


