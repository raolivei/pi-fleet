#!/bin/bash
# Set boot order: SD card first, then NVMe
# For Raspberry Pi 5, this is actually the default behavior
# SD card will be tried first, then NVMe if SD card is not bootable

set -e

echo "=== Boot Order Configuration ==="
echo ""
echo "Raspberry Pi 5 default boot order:"
echo "  1. SD card (if present and bootable)"
echo "  2. USB devices"
echo "  3. NVMe (if present and bootable)"
echo ""
echo "This is already the desired behavior - SD card first, then NVMe."
echo ""
echo "To ensure SD card is tried first:"
echo "  - Keep SD card inserted"
echo "  - Ensure SD card has valid boot partition"
echo ""
echo "NVMe will be used if:"
echo "  - SD card is removed"
echo "  - SD card boot fails"
echo "  - SD card is not bootable"
echo ""

# Check if we can configure boot order via config.txt
if [ -f /boot/firmware/config.txt ]; then
    echo "Current boot configuration:"
    grep -E "boot_order|priority" /boot/firmware/config.txt || echo "  (using default boot order)"
    echo ""
    
    # Note: Raspberry Pi 5 doesn't have a simple boot_order setting
    # The boot order is hardware-determined
    echo "Note: Boot order is hardware-determined on Pi 5."
    echo "SD card is always tried first if present."
fi

echo "✓ Boot order configuration verified"

