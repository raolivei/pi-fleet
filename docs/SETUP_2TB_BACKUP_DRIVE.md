# Setup 2TB SanDisk Extreme Backup Drive

Guide for setting up the 2TB SanDisk Extreme drive as a backup location before switching boot to NVMe.

## Current Status

The 2TB drive needs to be detected by the system. Here's how to set it up:

## Prerequisites

- ✅ `PI_PASSWORD` environment variable set: `export PI_PASSWORD='your_password'`

## Step 1: Verify Drive is Detected

SSH to eldertree and check if the drive appears:

```bash
# SSH to eldertree using PI_PASSWORD
sshpass -p "$PI_PASSWORD" ssh raolivei@192.168.2.83

# Check all block devices
lsblk

# Check USB devices
lsusb

# Check for new devices
ls -la /dev/sd*
```

The 2TB drive should appear as `/dev/sdb` or `/dev/sdc` (since `/dev/sda` is the 512GB SD card).

## Step 2: If Drive Not Detected

Try these steps:

1. **Unplug and replug** the USB drive
2. **Wait 5-10 seconds** for detection
3. **Try a different USB port** (prefer USB 3.0 if available)
4. **Check dmesg** for detection messages:

   ```bash
   sudo dmesg | tail -20
   ```

5. **Rescan USB devices**:
   ```bash
   echo '- - -' | sudo tee /sys/class/scsi_host/host*/scan
   sleep 2
   lsblk
   ```

## Step 3: Run Setup Script

Once the drive is detected, run the setup script:

```bash
~/setup-backup-drive.sh
```

This script will:

1. ✅ Detect the 2TB drive automatically
2. ✅ Create a partition table (GPT)
3. ✅ Create a single ext4 partition using all space
4. ✅ Format the partition
5. ✅ Mount it at `/mnt/backup`
6. ✅ Add to `/etc/fstab` for automatic mounting on boot
7. ✅ Set proper permissions

## Step 4: Verify Setup

After the script completes:

```bash
# Check mount
df -h /mnt/backup

# Test write
touch /mnt/backup/test && rm /mnt/backup/test && echo "SUCCESS"
```

## Step 5: Backup Everything

Once the drive is set up, you can backup:

### Option 1: Backup NVMe Data Only

```bash
~/backup-nvme.sh
```

This backs up the ~95GB from `/mnt/nvme` to `/mnt/backup`.

### Option 2: Full System Backup (Optional)

If you want to backup the entire system:

```bash
# Backup root filesystem (excluding /mnt, /proc, /sys, etc.)
sudo rsync -avh --progress \
  --exclude='/mnt' \
  --exclude='/proc' \
  --exclude='/sys' \
  --exclude='/dev' \
  --exclude='/tmp' \
  --exclude='/run' \
  --exclude='/boot/firmware' \
  / /mnt/backup/system-backup-$(date +%Y%m%d)/
```

## Troubleshooting

### Drive Not Appearing

- **Check USB connection**: Ensure drive is fully plugged in
- **Check power**: Some external drives need external power
- **Check USB port**: Try USB 3.0 port if available
- **Check dmesg**: `sudo dmesg | grep -i usb | tail -20`

### Permission Denied

```bash
sudo chown -R raolivei:raolivei /mnt/backup
```

### Mount Fails

```bash
# Check if partition exists
sudo fdisk -l /dev/sdb  # or sdc, etc.

# Check filesystem
sudo fsck -n /dev/sdb1  # or sdc1, etc.

# Try manual mount
sudo mount /dev/sdb1 /mnt/backup
```

## After Backup

Once everything is backed up to the 2TB drive:

1. ✅ Verify backups: `ls -lh /mnt/backup/`
2. ✅ Run NVMe boot setup: `~/setup-nvme-boot.sh`
3. ✅ Reboot and verify boot from NVMe
4. ✅ Restore data if needed from `/mnt/backup`

## Storage Summary

- **SD Card (mmcblk0)**: 59.5GB - Current boot device
- **NVMe (nvme0n1)**: 256GB - Will become boot device
- **512GB SD (sda)**: 476GB - Temporary backup location
- **2TB SanDisk Extreme**: ~2TB - Permanent backup location
