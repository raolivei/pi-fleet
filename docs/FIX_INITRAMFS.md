# Fix Initramfs Boot Issue

## Problem

System is stuck in initramfs (BusyBox shell) - cannot mount root filesystem.

## Identify Which Node

In the initramfs console, run:

```bash
# Check network interfaces to identify node
ip addr show | grep -E "inet.*192.168.2|inet.*10.0.0"

# Or check MAC address
cat /sys/class/net/eth0/address
cat /sys/class/net/wlan0/address
```

**Node identification:**
- `192.168.2.86` or `10.0.0.1` = **node-0**
- `192.168.2.85` or `10.0.0.2` = **node-1**
- `192.168.2.84` or `10.0.0.3` = **node-2** (already recovered)

## Fix in Initramfs

### Step 1: Mount root filesystem manually

```bash
# Find the root device
lsblk

# Mount root (usually /dev/mmcblk0p2 for SD card)
mkdir /mnt
mount /dev/mmcblk0p2 /mnt

# If that doesn't work, try:
# mount /dev/sda2 /mnt
# mount /dev/nvme0n1p2 /mnt
```

### Step 2: Fix fstab

```bash
# Edit fstab
nano /mnt/etc/fstab

# Add nofail to optional mounts:
# Change lines like:
# /dev/sdb1 /mnt/backup ext4 defaults 0 2
# To:
# /dev/sdb1 /mnt/backup ext4 defaults,nofail 0 2

# Do the same for:
# - /dev/nvme* mounts
# - /dev/mmcblk* mounts (except root)
# - Any /mnt/* mounts
```

### Step 3: Exit and continue boot

```bash
# Exit initramfs and continue boot
exit
```

## Alternative: Boot from SD Card Properly

If initramfs keeps appearing, the SD card fstab might be corrupted. Better approach:

1. **Boot from SD card** (current situation)
2. **Once booted, mount NVMe and fix NVMe fstab** (as we did for node-2)
3. **Reboot from NVMe**

## Quick Fix Commands (if you can mount root)

```bash
# In initramfs, after mounting root to /mnt:
sed -i 's|\(/mnt/backup.*defaults\)|\1,nofail|g' /mnt/etc/fstab
sed -i 's|\(/dev/nvme.*defaults\)|\1,nofail|g' /mnt/etc/fstab
sed -i 's|\(/dev/sdb.*defaults\)|\1,nofail|g' /mnt/etc/fstab
sed -i 's|\(/dev/mmcblk.*defaults\)|\1,nofail|g' /mnt/etc/fstab
```

Then `exit` to continue boot.

