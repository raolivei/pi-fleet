# Secure Erase Old NVMe Drives

## Overview

After successfully migrating to new 128GB NVMe drives, you can securely erase the old 256GB SSDs before returning them.

## Prerequisites

- ✅ Migration to new NVMe completed and verified
- ✅ System is booting from new NVMe
- ✅ Old drive is no longer in use (not mounted)
- ✅ You have physical access to remove the old drive after erasure

## Secure Erase Process

### Step 1: Verify Migration is Complete

```bash
# Verify you're booting from new NVMe
df -h /  # Should show /dev/nvme0n1p2 (new 128GB drive)

# Verify old drive is not in use
lsblk
# Old drive should not be mounted
```

### Step 2: Identify Old Drive

If the old drive is still connected, identify it:

```bash
# List all NVMe devices
lsblk | grep nvme

# Check sizes - old drive should be ~256GB
sudo fdisk -l /dev/nvme0n1  # or nvme1n1 if multiple drives
```

**Note**: After hardware replacement, the old drive may not be connected. You may need to:
- Temporarily connect the old drive via USB adapter, OR
- Erase it before removing it (if still accessible)

### Step 3: Unmount Old Drive (if mounted)

```bash
# Check what's mounted
mount | grep nvme

# Unmount if needed
sudo umount /dev/nvme0n1p1  # boot partition
sudo umount /dev/nvme0n1p2  # root partition
# Or any other mounted partitions
```

### Step 4: Run Secure Erase Script

```bash
# Copy script to node if needed
scp pi-fleet/scripts/storage/secure-erase-old-nvme.sh node-0:~/

# SSH to node
ssh node-0

# Run secure erase
sudo ./secure-erase-old-nvme.sh /dev/nvme0n1
# Replace /dev/nvme0n1 with the actual old drive device
```

The script will:
1. Verify device is not in use
2. Attempt NVMe secure erase (fastest, if supported)
3. Fall back to dd overwrite with zeros (if secure erase not available)
4. Verify the erase was successful

### Step 5: Verify Erasure

```bash
# Check device - should show no partitions or empty
lsblk /dev/nvme0n1

# Try to read first few MB (should be zeros)
sudo dd if=/dev/nvme0n1 bs=1M count=1 | od -An -tx1 | head -1
# Should show mostly zeros
```

## Erase Methods

### Method 1: NVMe Secure Erase (Preferred)

- **Crypto Erase**: Fast, uses encryption keys (if drive supports it)
- **User Data Erase**: Slower, physically overwrites data

### Method 2: DD Overwrite (Fallback)

- Writes zeros to entire device
- Takes longer (estimated: 2-5 minutes per 100GB)
- More thorough but slower

## Safety Notes

⚠️ **WARNING**: This process is **irreversible**. All data will be permanently destroyed.

- ✅ Only run after migration is verified complete
- ✅ Ensure you're erasing the correct device
- ✅ Keep new drive safe and separate from old drive
- ✅ Verify erase before returning drive

## Troubleshooting

### Device is Mounted

```bash
# Find what's using the device
sudo lsof | grep nvme0n1
sudo fuser -m /dev/nvme0n1p1

# Unmount
sudo umount /dev/nvme0n1p1
sudo umount /dev/nvme0n1p2
```

### Multiple NVMe Devices

If you have multiple NVMe devices:

```bash
# List all
lsblk | grep nvme

# Check sizes to identify old vs new
sudo fdisk -l /dev/nvme0n1
sudo fdisk -l /dev/nvme1n1

# Old drive: ~256GB
# New drive: ~128GB
```

### Old Drive Not Accessible

If the old drive was already removed:
- Connect it via USB adapter
- Or erase it on another system
- The script works with any NVMe device path

## After Erasure

1. **Verify erase completed successfully**
2. **Physically remove old drive**
3. **Drive is safe to return** - all data is destroyed
4. **Keep new drive in system** - migration complete

## Related Documentation

- [Migration Quick Start](MIGRATION_NVME_HAT_QUICK_START.md)
- [Migration Verification](verify-nvme-migration.sh)

