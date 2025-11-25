#!/bin/bash
# Quick script to open Time Machine and Extreme SSD volumes in Finder

echo "📂 Opening volumes in Finder..."

if [ -d "/Volumes/Time Machine" ]; then
    open "/Volumes/Time Machine" && echo "✅ Opened Time Machine"
else
    echo "⚠️  Time Machine not mounted"
fi

if [ -d "/Volumes/Extreme SSD" ]; then
    open "/Volumes/Extreme SSD" && echo "✅ Opened Extreme SSD"
else
    echo "⚠️  Extreme SSD not mounted"
fi

echo ""
echo "💡 You can now drag files from Finder to your terminal or workspace"




