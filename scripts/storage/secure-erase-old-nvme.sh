#!/bin/bash
# Secure erase old NVMe drives before returning them
# This script securely wipes the old 256GB SSDs
# Usage: ./secure-erase-old-nvme.sh [device]
# Example: ./secure-erase-old-nvme.sh /dev/nvme0n1

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DEVICE="${1:-/dev/nvme0n1}"

echo -e "${BLUE}=== Secure Erase Old NVMe Drive ===${NC}"
echo ""

# Check if device exists
if [ ! -b "$DEVICE" ]; then
    echo -e "${RED}❌ Device not found: $DEVICE${NC}"
    echo "  Available NVMe devices:"
    lsblk | grep nvme || echo "    (none found)"
    exit 1
fi

# Get device info
DEVICE_SIZE=$(blockdev --getsize64 "$DEVICE")
DEVICE_SIZE_GB=$((DEVICE_SIZE / 1024 / 1024 / 1024))
DEVICE_MODEL=$(nvme id-ctrl "$DEVICE" 2>/dev/null | grep -i "mn " | awk -F: '{print $2}' | xargs || echo "unknown")

echo -e "${BLUE}Device Information:${NC}"
echo "  Device: $DEVICE"
echo "  Size: ${DEVICE_SIZE_GB}GB"
echo "  Model: $DEVICE_MODEL"
echo ""

# Safety check - verify this is the old drive (should be ~256GB)
if [ "$DEVICE_SIZE_GB" -lt 200 ] || [ "$DEVICE_SIZE_GB" -gt 300 ]; then
    echo -e "${YELLOW}⚠️  Warning: Device size (${DEVICE_SIZE_GB}GB) doesn't match expected ~256GB${NC}"
    echo "  Old drives should be approximately 256GB"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if device is in use
echo -e "${YELLOW}Checking if device is in use...${NC}"
if mount | grep -q "$DEVICE"; then
    echo -e "${RED}❌ Device is mounted!${NC}"
    echo "  Mounted locations:"
    mount | grep "$DEVICE" | awk '{print "    " $3}'
    echo ""
    echo "Please unmount all partitions on this device first:"
    mount | grep "$DEVICE" | awk '{print "  sudo umount " $3}'
    exit 1
fi

# Check if any partitions are in use
for part in $(lsblk -n -o NAME "$DEVICE" | grep -v "^$(basename $DEVICE)$"); do
    if mount | grep -q "$part"; then
        echo -e "${RED}❌ Partition $part is mounted!${NC}"
        mount | grep "$part" | awk '{print "  Mounted at: " $3}'
        echo "  Please unmount: sudo umount /dev/$part"
        exit 1
    fi
done

echo -e "${GREEN}✓ Device is not in use${NC}"
echo ""

# Final warning
echo -e "${RED}⚠️  WARNING: This will PERMANENTLY ERASE all data on $DEVICE${NC}"
echo "  This action cannot be undone!"
echo "  All partitions and data will be destroyed"
echo ""
read -p "Are you sure you want to securely erase $DEVICE? Type 'ERASE' to confirm: " -r
echo
if [[ ! "$REPLY" == "ERASE" ]]; then
    echo "Aborted."
    exit 1
fi

# Method 1: Try NVMe format with secure erase
echo -e "${YELLOW}[1/3] Attempting NVMe secure erase...${NC}"
if command -v nvme &> /dev/null; then
    # Check if secure erase is supported
    if nvme id-ctrl "$DEVICE" 2>/dev/null | grep -q "Format.*Supported"; then
        echo "  Formatting with secure erase..."
        # Format with crypto erase (fast) or user data erase (slower but more secure)
        echo -e "${YELLOW}  Choose erase method:${NC}"
        echo "  1) Crypto Erase (fast, uses encryption keys)"
        echo "  2) User Data Erase (slower, overwrites data)"
        read -p "  Select [1-2]: " -n 1 -r
        echo
        
        if [[ "$REPLY" == "1" ]]; then
            ERASE_METHOD="crypto"
        else
            ERASE_METHOD="user"
        fi
        
        echo "  Executing secure erase (this may take a while)..."
        if nvme format "$DEVICE" -s "$ERASE_METHOD" -f 2>&1; then
            echo -e "${GREEN}✓ Secure erase completed${NC}"
            ERASE_SUCCESS=true
        else
            echo -e "${YELLOW}⚠️  NVMe secure erase failed, trying alternative method...${NC}"
            ERASE_SUCCESS=false
        fi
    else
        echo -e "${YELLOW}⚠️  Secure erase not supported via NVMe command, trying alternative...${NC}"
        ERASE_SUCCESS=false
    fi
else
    echo -e "${YELLOW}⚠️  nvme-cli not available, trying alternative method...${NC}"
    ERASE_SUCCESS=false
fi

# Method 2: If NVMe secure erase failed, use dd to overwrite
if [ "$ERASE_SUCCESS" != "true" ]; then
    echo -e "${YELLOW}[2/3] Using dd to overwrite device...${NC}"
    echo "  This will write zeros to the entire device"
    echo "  Estimated time: $(($DEVICE_SIZE_GB / 100))-$(($DEVICE_SIZE_GB / 50)) minutes"
    echo ""
    read -p "Continue with dd overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    
    echo "  Writing zeros to $DEVICE..."
    echo "  (This may take a long time - be patient)"
    sudo dd if=/dev/zero of="$DEVICE" bs=1M status=progress conv=fsync 2>&1 || {
        echo -e "${YELLOW}⚠️  dd failed, trying shred...${NC}"
        # Fallback to shred if dd fails
        if command -v shred &> /dev/null; then
            sudo shred -v -n 1 -z "$DEVICE"
        else
            echo -e "${RED}❌ Both dd and shred failed${NC}"
            exit 1
        fi
    }
    
    echo -e "${GREEN}✓ Device overwritten with zeros${NC}"
fi

# Method 3: Final verification - check that device is empty
echo -e "${YELLOW}[3/3] Verifying erase...${NC}"
# Check first few MB to see if they're zeros
FIRST_MB=$(sudo dd if="$DEVICE" bs=1M count=1 2>/dev/null | od -An -tx1 | head -1)
if [[ "$FIRST_MB" == *"00 00 00"* ]] || [[ "$FIRST_MB" == "" ]]; then
    echo -e "${GREEN}✓ Verification: Device appears to be erased${NC}"
else
    echo -e "${YELLOW}⚠️  Verification: Device may still contain data${NC}"
    echo "  First MB content: $FIRST_MB"
fi

# Show final device status
echo ""
echo -e "${GREEN}=== Erase Complete ===${NC}"
echo ""
echo -e "${BLUE}Device status:${NC}"
lsblk "$DEVICE"
echo ""
echo -e "${YELLOW}Note:${NC} Device partitions may still be visible but data is erased"
echo "  You can now safely return this drive"
echo ""

