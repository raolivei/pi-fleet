#!/bin/bash
set -e

# Diagnostic script for NVMe boot issues
# Run this on the Raspberry Pi to diagnose boot problems

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== NVMe Boot Diagnostic Tool ===${NC}"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠️  This script requires sudo privileges${NC}"
    echo "Please run with: sudo $0"
    exit 1
fi

NVME_DEVICE="/dev/nvme0n1"
SD_CARD="/dev/mmcblk0"
ISSUES_FOUND=0

# Function to report issue
report_issue() {
    echo -e "${RED}❌ $1${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
}

# Function to report success
report_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to report info
report_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo -e "${YELLOW}[1/8] Checking NVMe device detection...${NC}"
if [ -b "$NVME_DEVICE" ]; then
    report_success "NVMe device detected at $NVME_DEVICE"
    NVME_SIZE=$(blockdev --getsize64 "$NVME_DEVICE")
    echo "  Size: $(numfmt --to=iec-i --suffix=B $NVME_SIZE)"
else
    report_issue "NVMe device NOT found at $NVME_DEVICE"
    echo "  Check physical connection and NVMe adapter"
    exit 1
fi
echo ""

echo -e "${YELLOW}[2/8] Checking partition table...${NC}"
if sudo parted -s "$NVME_DEVICE" print > /dev/null 2>&1; then
    PARTITION_TABLE=$(sudo parted -s "$NVME_DEVICE" print | grep "Partition Table" | awk '{print $3}')
    if [ "$PARTITION_TABLE" = "gpt" ]; then
        report_success "GPT partition table found"
    else
        report_issue "Partition table is '$PARTITION_TABLE', expected 'gpt'"
    fi
else
    report_issue "Cannot read partition table"
fi
echo ""

echo -e "${YELLOW}[3/8] Checking partitions...${NC}"
PARTITIONS=$(lsblk -n -o NAME "$NVME_DEVICE" | grep -v "^nvme0n1$" | wc -l)
if [ "$PARTITIONS" -ge 2 ]; then
    report_success "Found $PARTITIONS partitions (expected at least 2)"
    lsblk "$NVME_DEVICE"
    
    # Check for boot partition
    if [ -b "${NVME_DEVICE}p1" ]; then
        report_success "Boot partition found: ${NVME_DEVICE}p1"
    else
        report_issue "Boot partition NOT found: ${NVME_DEVICE}p1"
    fi
    
    # Check for root partition
    if [ -b "${NVME_DEVICE}p2" ]; then
        report_success "Root partition found: ${NVME_DEVICE}p2"
    else
        report_issue "Root partition NOT found: ${NVME_DEVICE}p2"
    fi
else
    report_issue "Only $PARTITIONS partition(s) found, expected at least 2 (boot + root)"
fi
echo ""

echo -e "${YELLOW}[4/8] Checking boot partition filesystem...${NC}"
if [ -b "${NVME_DEVICE}p1" ]; then
    FS_TYPE=$(sudo blkid -s TYPE -o value "${NVME_DEVICE}p1" 2>/dev/null || echo "unknown")
    if [ "$FS_TYPE" = "vfat" ] || [ "$FS_TYPE" = "msdos" ]; then
        report_success "Boot partition is FAT32 ($FS_TYPE)"
    else
        report_issue "Boot partition filesystem is '$FS_TYPE', expected 'vfat' or 'msdos'"
    fi
else
    report_issue "Cannot check boot partition (device not found)"
fi
echo ""

echo -e "${YELLOW}[5/8] Checking root partition filesystem...${NC}"
if [ -b "${NVME_DEVICE}p2" ]; then
    FS_TYPE=$(sudo blkid -s TYPE -o value "${NVME_DEVICE}p2" 2>/dev/null || echo "unknown")
    if [ "$FS_TYPE" = "ext4" ]; then
        report_success "Root partition is ext4"
    else
        report_issue "Root partition filesystem is '$FS_TYPE', expected 'ext4'"
    fi
else
    report_issue "Cannot check root partition (device not found)"
fi
echo ""

echo -e "${YELLOW}[6/8] Checking boot partition contents...${NC}"
if [ -b "${NVME_DEVICE}p1" ]; then
    # Create mount point
    MOUNT_POINT="/tmp/nvme-boot-check-$$"
    mkdir -p "$MOUNT_POINT"
    
    # Try to mount
    if sudo mount "${NVME_DEVICE}p1" "$MOUNT_POINT" 2>/dev/null; then
        report_success "Boot partition mounted successfully"
        
        # Check for critical files
        if [ -f "$MOUNT_POINT/cmdline.txt" ]; then
            report_success "cmdline.txt found"
            
            # Check cmdline.txt content
            if grep -q "root=/dev/nvme0n1p2" "$MOUNT_POINT/cmdline.txt"; then
                report_success "cmdline.txt points to NVMe root partition"
            elif grep -q "root=/dev/mmcblk0p2" "$MOUNT_POINT/cmdline.txt"; then
                report_issue "cmdline.txt points to SD card (mmcblk0p2) instead of NVMe"
                echo "  Current: $(grep -o 'root=[^ ]*' "$MOUNT_POINT/cmdline.txt" | head -1)"
            else
                report_info "cmdline.txt root parameter: $(grep -o 'root=[^ ]*' "$MOUNT_POINT/cmdline.txt" | head -1 || echo 'not found')"
            fi
        else
            report_issue "cmdline.txt NOT found in boot partition"
        fi
        
        if [ -f "$MOUNT_POINT/config.txt" ]; then
            report_success "config.txt found"
        else
            report_info "config.txt not found (may be optional)"
        fi
        
        # Check for firmware files
        FIRMWARE_COUNT=$(find "$MOUNT_POINT" -name "*.elf" -o -name "*.bin" 2>/dev/null | wc -l)
        if [ "$FIRMWARE_COUNT" -gt 0 ]; then
            report_success "Found $FIRMWARE_COUNT firmware file(s)"
        else
            report_issue "No firmware files found in boot partition"
        fi
        
        # Unmount
        sudo umount "$MOUNT_POINT"
        rmdir "$MOUNT_POINT"
    else
        report_issue "Cannot mount boot partition (may be corrupted)"
    fi
else
    report_issue "Cannot check boot partition contents (device not found)"
fi
echo ""

echo -e "${YELLOW}[7/8] Checking root partition fstab...${NC}"
if [ -b "${NVME_DEVICE}p2" ]; then
    # Create mount point
    MOUNT_POINT="/tmp/nvme-root-check-$$"
    mkdir -p "$MOUNT_POINT"
    
    # Try to mount
    if sudo mount "${NVME_DEVICE}p2" "$MOUNT_POINT" 2>/dev/null; then
        report_success "Root partition mounted successfully"
        
        if [ -f "$MOUNT_POINT/etc/fstab" ]; then
            report_success "fstab found"
            
            # Check for SD card references
            if grep -q "/dev/mmcblk0" "$MOUNT_POINT/etc/fstab"; then
                report_issue "fstab contains SD card references (mmcblk0)"
                echo "  Found:"
                grep "/dev/mmcblk0" "$MOUNT_POINT/etc/fstab" | sed 's/^/    /'
            else
                report_success "fstab does not reference SD card"
            fi
            
            # Check for NVMe references
            if grep -q "/dev/nvme0n1" "$MOUNT_POINT/etc/fstab"; then
                report_success "fstab references NVMe partitions"
            else
                report_info "fstab does not explicitly reference NVMe (may use UUIDs)"
            fi
        else
            report_issue "fstab NOT found in root partition"
        fi
        
        # Unmount
        sudo umount "$MOUNT_POINT"
        rmdir "$MOUNT_POINT"
    else
        report_issue "Cannot mount root partition (may be corrupted)"
    fi
else
    report_issue "Cannot check root partition (device not found)"
fi
echo ""

echo -e "${YELLOW}[8/8] Checking current boot device...${NC}"
CURRENT_ROOT=$(df -h / | tail -1 | awk '{print $1}')
if echo "$CURRENT_ROOT" | grep -q "nvme0n1p2"; then
    report_success "Currently booted from NVMe: $CURRENT_ROOT"
elif echo "$CURRENT_ROOT" | grep -q "mmcblk0p2"; then
    report_info "Currently booted from SD card: $CURRENT_ROOT"
    echo "  This is expected if you booted with SD card to run diagnostics"
else
    report_info "Current root device: $CURRENT_ROOT"
fi
echo ""

# Summary
echo -e "${BLUE}=== Diagnostic Summary ===${NC}"
if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo -e "${GREEN}✓ No issues found! NVMe boot configuration looks correct.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Reboot and remove SD card to test NVMe boot"
    echo "  2. If boot fails, check logs: sudo journalctl -b -1"
else
    echo -e "${RED}❌ Found $ISSUES_FOUND issue(s)${NC}"
    echo ""
    echo "Recommended actions:"
    echo "  1. Review the issues above"
    echo "  2. See troubleshooting guide: docs/NVME_BOOT_TROUBLESHOOTING.md"
    echo "  3. Run setup script if needed: ./scripts/storage/setup-nvme-boot.sh"
fi
echo ""

