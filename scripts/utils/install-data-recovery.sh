#!/bin/bash
# Install data recovery tools

echo "📦 Installing Data Recovery Tools"
echo "=================================="
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found"
    echo "   Install Homebrew first: https://brew.sh"
    exit 1
fi

echo "Installing TestDisk (includes PhotoRec)..."
brew install testdisk

echo ""
echo "✅ Installation complete!"
echo ""
echo "Tools installed:"
echo "  - PhotoRec: File recovery by file type"
echo "  - TestDisk: Partition recovery"
echo ""
echo "Usage:"
echo "  photorec /log ~/recovered-files/photorec.log /dev/disk5"
echo ""
echo "PhotoRec will:"
echo "  - Scan the entire disk"
echo "  - Recover files by type (photos, documents, videos, etc.)"
echo "  - Save to a folder you specify"
echo "  - Work even with corrupted filesystems"

