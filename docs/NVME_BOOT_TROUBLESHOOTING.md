# NVMe Boot Troubleshooting Guide

## Problem: Node Won't Boot from NVMe After Removing SD Card

If your Raspberry Pi 5 (node-1) won't boot from NVMe after removing the SD card, follow these steps to diagnose and fix the issue.

## Quick Diagnosis

### Step 1: Re-insert SD Card to Boot

**First, put the SD card back in to boot the system:**

```bash
# Once booted, SSH to node-1
ssh raolivei@node-1.local
# Or if that doesn't work:
ssh raolivei@192.168.2.85
```

### Step 2: Check NVMe Detection

```bash
# Check if NVMe is detected
lsblk | grep nvme

# Check NVMe device details
sudo fdisk -l /dev/nvme0n1
```

**Expected output:** You should see `/dev/nvme0n1` with partitions `nvme0n1p1` (boot) and `nvme0n1p2` (root).

### Step 3: Check NVMe Partitions

```bash
# Check if partitions exist
sudo parted /dev/nvme0n1 print

# Check partition table
sudo fdisk -l /dev/nvme0n1
```

**Expected:** GPT partition table with:

- Partition 1: FAT32 boot partition (~512MB)
- Partition 2: ext4 root partition (remaining space)

### Step 4: Check Boot Partition Contents

```bash
# Mount boot partition
sudo mkdir -p /mnt/nvme-boot
sudo mount /dev/nvme0n1p1 /mnt/nvme-boot

# Check boot files
ls -la /mnt/nvme-boot/

# Check cmdline.txt
cat /mnt/nvme-boot/cmdline.txt

# Unmount
sudo umount /mnt/nvme-boot
```

**Expected in cmdline.txt:**

- Should contain `root=/dev/nvme0n1p2` or `root=PARTUUID=...` pointing to NVMe root partition
- Should NOT contain `root=/dev/mmcblk0p2` (SD card)

### Step 5: Check Root Partition

```bash
# Mount root partition
sudo mkdir -p /mnt/nvme-root
sudo mount /dev/nvme0n1p2 /mnt/nvme-root

# Check fstab
cat /mnt/nvme-root/etc/fstab

# Unmount
sudo umount /mnt/nvme-root
```

**Expected in fstab:**

- Boot partition: `/dev/nvme0n1p1` or UUID
- Root partition: `/dev/nvme0n1p2` or UUID
- Should NOT reference `/dev/mmcblk0p1` or `/dev/mmcblk0p2`

## Common Issues and Fixes

### Issue 1: NVMe Not Partitioned for Boot

**Symptoms:**

- `sudo fdisk -l /dev/nvme0n1` shows no partitions or wrong partition table
- NVMe only has a single partition (likely from storage setup, not boot setup)

**Fix:**
Run the NVMe boot setup script:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/storage/setup-nvme-boot.sh
```

**⚠️ Warning:** This will erase all data on NVMe. Backup any important data first.

### Issue 2: Boot Partition Missing Files

**Symptoms:**

- Boot partition exists but is empty or missing critical files
- Missing `cmdline.txt`, `config.txt`, or firmware files

**Fix:**
Re-clone the boot partition:

```bash
# Stop K3s if running
sudo systemctl stop k3s

# Unmount NVMe boot if mounted
sudo umount /mnt/nvme-boot 2>/dev/null || true

# Clone boot partition from SD card
sudo dd if=/dev/mmcblk0p1 of=/dev/nvme0n1p1 bs=4M status=progress conv=fsync
sudo sync

# Mount and update cmdline.txt
sudo mount /dev/nvme0n1p1 /mnt/nvme-boot
sudo sed -i.bak "s|root=/dev/mmcblk0p2|root=/dev/nvme0n1p2|g" /mnt/nvme-boot/cmdline.txt
sudo sed -i.bak "s|root=PARTUUID=[^ ]*|root=/dev/nvme0n1p2|g" /mnt/nvme-boot/cmdline.txt
sudo umount /mnt/nvme-boot

# Restart K3s
sudo systemctl start k3s
```

### Issue 3: cmdline.txt Points to SD Card

**Symptoms:**

- `cmdline.txt` contains `root=/dev/mmcblk0p2` instead of `root=/dev/nvme0n1p2`

**Fix:**

```bash
# Mount boot partition
sudo mount /dev/nvme0n1p1 /mnt/nvme-boot

# Update cmdline.txt
sudo sed -i.bak "s|root=/dev/mmcblk0p2|root=/dev/nvme0n1p2|g" /mnt/nvme-boot/cmdline.txt
sudo sed -i.bak "s|root=PARTUUID=[^ ]*|root=/dev/nvme0n1p2|g" /mnt/nvme-boot/cmdline.txt

# Verify
cat /mnt/nvme-boot/cmdline.txt

# Unmount
sudo umount /mnt/nvme-boot
```

### Issue 4: fstab Points to SD Card

**Symptoms:**

- `/etc/fstab` on NVMe root partition references SD card devices

**Fix:**

```bash
# Mount root partition
sudo mount /dev/nvme0n1p2 /mnt/nvme-root

# Update fstab
sudo sed -i.bak "s|/dev/mmcblk0p1|/dev/nvme0n1p1|g" /mnt/nvme-root/etc/fstab
sudo sed -i.bak "s|/dev/mmcblk0p2|/dev/nvme0n1p2|g" /mnt/nvme-root/etc/fstab

# Verify
cat /mnt/nvme-root/etc/fstab

# Unmount
sudo umount /mnt/nvme-root
```

### Issue 5: NVMe Not Detected During Boot

**Symptoms:**

- NVMe is detected when system is running, but not during boot
- Boot fails with "No bootable device" or similar

**Possible Causes:**

1. **NVMe adapter issue** - Check physical connection
2. **Firmware issue** - Pi 5 firmware may need update
3. **Boot order** - May need to configure boot order explicitly

**Fix:**

```bash
# Check firmware version
vcgencmd bootloader_version

# Update firmware (if needed)
sudo rpi-eeprom-update -a
sudo reboot

# Check boot order configuration
cat /boot/firmware/config.txt | grep -i boot
```

### Issue 6: Root Partition Not Mounting

**Symptoms:**

- Boot starts but fails to mount root filesystem
- Kernel panic or boot loop

**Fix:**
Check if root partition is corrupted:

```bash
# Check filesystem
sudo fsck -n /dev/nvme0n1p2

# If errors found, repair (WARNING: may cause data loss)
sudo fsck -y /dev/nvme0n1p2
```

## Complete Re-setup Procedure

If nothing else works, perform a complete re-setup:

```bash
# 1. Backup any important data from NVMe
# (if it was used for storage)

# 2. Run the setup script
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/storage/setup-nvme-boot.sh

# 3. Reboot
sudo reboot

# 4. After reboot, verify
df -h /
mount | grep "/boot/firmware"
```

## Verification After Fix

After applying fixes, verify the configuration:

```bash
# 1. Check root filesystem
df -h /
# Should show /dev/nvme0n1p2

# 2. Check boot partition
mount | grep "/boot/firmware"
# Should show /dev/nvme0n1p1

# 3. Check device tree
lsblk
# Root (/) should be on nvme0n1p2

# 4. Check boot config
cat /boot/firmware/cmdline.txt
# Should contain root=/dev/nvme0n1p2

# 5. Check fstab
cat /etc/fstab
# Should reference nvme0n1p1 and nvme0n1p2
```

## Testing Boot from NVMe

Once fixed, test booting from NVMe:

1. **With SD card still in:**

   ```bash
   sudo reboot
   ```

   After boot, verify you're on NVMe (not SD card)

2. **Remove SD card and reboot:**

   ```bash
   # Power off
   sudo poweroff
   # Remove SD card
   # Power on
   ```

   System should boot from NVMe

3. **If boot fails without SD card:**
   - Re-insert SD card
   - Boot and re-run setup script
   - Check logs: `sudo journalctl -b -1` (previous boot)

## Prevention

To prevent this issue in the future:

1. **Always verify boot configuration** after setup:

   ```bash
   cat /boot/firmware/cmdline.txt
   cat /etc/fstab
   ```

2. **Test boot without SD card** before relying on it

3. **Keep SD card as backup** - Don't remove it until you've verified NVMe boot works

4. **Document the setup** - Note which nodes are configured for NVMe boot

## Related Documentation

- [NVMe Boot Setup](NVME_BOOT_SETUP.md) - Complete setup guide
- [NVMe Boot Quick Start](NVME_BOOT_QUICK_START.md) - Quick reference
- [Boot Fix Guide](BOOT_FIX.md) - General boot troubleshooting
