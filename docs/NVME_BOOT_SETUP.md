# Boot from NVMe on Raspberry Pi 5

Complete guide for configuring Raspberry Pi 5 to boot from NVMe SSD instead of SD card.

## Overview

Raspberry Pi 5 natively supports booting from NVMe drives. This guide shows how to:
1. Clone your current OS from SD card to NVMe
2. Configure the Pi to boot from NVMe
3. Keep SD card as backup boot option

## Prerequisites

- ✅ Raspberry Pi 5 (NVMe boot is Pi 5 specific)
- ✅ NVMe SSD installed via M.2 adapter
- ✅ Current OS running from SD card
- ✅ NVMe is at least as large as your SD card partitions

## Current Status

Check your current setup:

```bash
ssh raolivei@eldertree.local
lsblk
```

You should see:
- `/dev/mmcblk0` - SD card (current boot device)
- `/dev/nvme0n1` - NVMe SSD

## Quick Setup (Automated)

Use the automated script to clone OS and configure boot:

```bash
# SSH to eldertree
ssh raolivei@eldertree.local

# Run setup script
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/storage/setup-nvme-boot.sh
```

The script will:
1. ✅ Check prerequisites
2. ✅ Stop K3s (if running)
3. ✅ Create partitions on NVMe (boot + root)
4. ✅ Clone OS from SD card to NVMe
5. ✅ Update boot configuration
6. ✅ Configure fstab for NVMe partitions

**⚠️ WARNING**: This will erase all data on the NVMe device!

## Manual Setup

If you prefer manual setup or need more control:

### Step 1: Stop Services

```bash
# Stop K3s
sudo systemctl stop k3s

# Unmount NVMe if mounted
sudo umount /mnt/nvme 2>/dev/null || true
```

### Step 2: Create Partitions on NVMe

```bash
# Create GPT partition table
sudo parted -s /dev/nvme0n1 mklabel gpt

# Create boot partition (512MB, FAT32)
sudo parted -s /dev/nvme0n1 mkpart primary fat32 1MiB 512MiB
sudo parted -s /dev/nvme0n1 set 1 esp on  # EFI System Partition flag

# Create root partition (remaining space, ext4)
sudo parted -s /dev/nvme0n1 mkpart primary ext4 513MiB 100%

# Format partitions
sudo mkfs.vfat -F 32 -n BOOT /dev/nvme0n1p1
sudo mkfs.ext4 -F -L rootfs /dev/nvme0n1p2
```

### Step 3: Clone OS from SD Card

```bash
# Clone boot partition
sudo dd if=/dev/mmcblk0p1 of=/dev/nvme0n1p1 bs=4M status=progress conv=fsync

# Clone root partition (this takes 10-30 minutes)
sudo dd if=/dev/mmcblk0p2 of=/dev/nvme0n1p2 bs=4M status=progress conv=fsync

# Sync to ensure all data is written
sudo sync
```

### Step 4: Update Boot Configuration

```bash
# Mount NVMe root
sudo mkdir -p /mnt/nvme-root
sudo mount /dev/nvme0n1p2 /mnt/nvme-root

# Mount NVMe boot
sudo mkdir -p /mnt/nvme-boot
sudo mount /dev/nvme0n1p1 /mnt/nvme-boot

# Update fstab
sudo sed -i.bak "s|/dev/mmcblk0p1|/dev/nvme0n1p1|g" /mnt/nvme-root/etc/fstab
sudo sed -i.bak "s|/dev/mmcblk0p2|/dev/nvme0n1p2|g" /mnt/nvme-root/etc/fstab

# Update cmdline.txt
sudo sed -i.bak "s|root=/dev/mmcblk0p2|root=/dev/nvme0n1p2|g" /mnt/nvme-boot/cmdline.txt

# Unmount
sudo umount /mnt/nvme-boot
sudo umount /mnt/nvme-root
```

### Step 5: Reboot

```bash
sudo reboot
```

## Boot Order on Raspberry Pi 5

Raspberry Pi 5 automatically tries to boot from NVMe if present. Boot order:

1. **NVMe** (if present and bootable)
2. **USB** (if present)
3. **SD Card** (fallback)

The SD card remains as a backup boot option. If NVMe boot fails, the Pi will automatically fall back to SD card.

## Verification

After reboot, verify you're booting from NVMe:

```bash
# Check root filesystem device
lsblk
df -h /

# Root should be on /dev/nvme0n1p2
mount | grep " / "

# Check boot partition
mount | grep "/boot/firmware"
# Should show /dev/nvme0n1p1
```

## Troubleshooting

### Pi won't boot from NVMe

1. **Check NVMe is detected**:
   ```bash
   # Boot from SD card, then check:
   lsblk | grep nvme
   ```

2. **Verify partitions exist**:
   ```bash
   sudo fdisk -l /dev/nvme0n1
   ```

3. **Check boot partition has files**:
   ```bash
   sudo mount /dev/nvme0n1p1 /mnt
   ls /mnt
   sudo umount /mnt
   ```

4. **Verify cmdline.txt**:
   ```bash
   sudo mount /dev/nvme0n1p1 /mnt
   cat /mnt/cmdline.txt
   sudo umount /mnt
   ```

### Boot loops or kernel panics

- Boot from SD card (remove NVMe or it will try NVMe first)
- Check logs: `sudo journalctl -b -1` (previous boot)
- Verify fstab: `cat /etc/fstab`
- Re-run setup script if needed

### K3s not starting after boot

- Check if K3s data directory exists: `ls -la /var/lib/rancher/k3s/`
- Check K3s logs: `sudo journalctl -u k3s -n 50`
- Restart K3s: `sudo systemctl restart k3s`

## Performance Benefits

Booting from NVMe provides:

- ✅ **Faster boot times** (2-3x faster than SD card)
- ✅ **Faster application startup** (especially K3s)
- ✅ **Better I/O performance** for databases and stateful workloads
- ✅ **Reduced SD card wear** (SD card becomes backup only)
- ✅ **More reliable** (NVMe SSDs are more durable than SD cards)

## Reverting to SD Card Boot

If you need to revert to SD card boot:

1. **Remove NVMe** (physically or via software)
2. **Reboot** - Pi will automatically boot from SD card
3. **Or configure boot order** (if needed)

The SD card remains fully functional and can boot independently.

## Notes

- **SD Card Backup**: Keep your SD card as a backup. If NVMe fails, you can boot from SD card.
- **Data Safety**: The cloning process creates an exact copy, so all your data, K3s cluster, and configuration are preserved.
- **Performance**: After booting from NVMe, you'll notice significantly faster performance, especially for I/O-intensive workloads.

## Related Documentation

- [NVMe Storage Setup](NVME_STORAGE_SETUP.md) - Using NVMe for K3s data and storage
- [OS Installation Guide](OS_INSTALLATION_STEPS.md) - Fresh OS installation
- [Cluster Setup](../README.md) - Complete cluster setup guide

