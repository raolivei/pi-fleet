#!/bin/bash
# Script to run on node-1 to setup NVMe boot
# This checks the current state and sets up NVMe boot if needed

set -e

echo "=== NVMe Boot Setup for node-1 ==="
echo ""

# Check current boot device
CURRENT_ROOT=$(df -h / | tail -1 | awk '{print $1}')
echo "Currently booting from: $CURRENT_ROOT"

if echo "$CURRENT_ROOT" | grep -q "nvme"; then
    echo "✓ Already booting from NVMe!"
    exit 0
fi

echo "Currently booting from SD card. Setting up NVMe boot..."
echo ""

# Check if NVMe has partitions
if [ ! -b /dev/nvme0n1p1 ] || [ ! -b /dev/nvme0n1p2 ]; then
    echo "ERROR: NVMe does not have boot and root partitions"
    echo "Run: cd ~/WORKSPACE/raolivei/pi-fleet/scripts/storage && sudo ./setup-nvme-boot.sh"
    exit 1
fi

# Check if setup script exists
if [ ! -f ~/WORKSPACE/raolivei/pi-fleet/scripts/storage/setup-nvme-boot.sh ]; then
    echo "ERROR: setup-nvme-boot.sh not found"
    echo "Please ensure the pi-fleet repository is cloned on node-1"
    exit 1
fi

echo "Running NVMe boot setup..."
echo "This will:"
echo "  1. Clone OS from SD card to NVMe"
echo "  2. Configure boot to use NVMe"
echo "  3. Keep SD card as backup"
echo ""
echo "⚠️  This will take 10-30 minutes"
echo ""

cd ~/WORKSPACE/raolivei/pi-fleet/scripts/storage
sudo ./setup-nvme-boot.sh

echo ""
echo "✓ Setup complete! Reboot to boot from NVMe:"
echo "  sudo reboot"

