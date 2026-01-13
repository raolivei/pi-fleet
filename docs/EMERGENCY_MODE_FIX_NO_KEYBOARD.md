<!-- MIGRATED TO RUNBOOK -->
> **📚 This document has been migrated to the Eldertree Runbook**
>
> For the latest version, see: [EMERG-002](https://docs.eldertree.xyz/runbook/issues/boot/EMERG-002)
>
> The runbook provides searchable troubleshooting guides with improved formatting.

---


# Fix Emergency Mode Without Keyboard

## Quick Solutions

### Option 1: Try SSH (Most Likely to Work)

Even in emergency mode, SSH might still be available. Try:

```bash
# Try SSH to node-1
ssh raolivei@node-1.local
# Or:
ssh raolivei@192.168.2.85

# If that works, run:
sudo systemctl default
# Or:
sudo reboot
```

If SSH works but system is still in emergency mode, you can fix fstab remotely:

```bash
# SSH to node-1
ssh raolivei@node-1.local

# Fix fstab - add nofail to problematic mounts
sudo sed -i.bak 's|/dev/sdb1.*ext4.*defaults|/dev/sdb1 /mnt/backup ext4 defaults,nofail|g' /etc/fstab
sudo sed -i.bak 's|/mnt/backup.*ext4.*defaults[^,]*|/mnt/backup ext4 defaults,nofail|g' /etc/fstab

# Exit emergency mode
sudo systemctl default
```

### Option 2: Fix SD Card from Another System (Recommended)

If SSH doesn't work, mount the SD card on another computer and fix it:

#### On macOS/Linux:

```bash
# 1. Insert SD card into card reader on your computer

# 2. Find the SD card device
diskutil list  # macOS
# or
lsblk  # Linux

# Look for something like /dev/disk2 (macOS) or /dev/sdb (Linux)

# 3. Mount the root partition (partition 2)
# macOS:
sudo mkdir -p /mnt/sd-root
sudo mount -t ext4 /dev/disk2s2 /mnt/sd-root  # Adjust disk number

# Linux:
sudo mkdir -p /mnt/sd-root
sudo mount /dev/sdb2 /mnt/sd-root  # Adjust device name

# 4. Fix fstab
sudo nano /mnt/sd-root/etc/fstab
# Or use sed:
sudo sed -i.bak 's|/dev/sdb1.*ext4.*defaults|/dev/sdb1 /mnt/backup ext4 defaults,nofail|g' /mnt/sd-root/etc/fstab
sudo sed -i.bak 's|/mnt/backup.*ext4.*defaults[^,]*|/mnt/backup ext4 defaults,nofail|g' /mnt/sd-root/etc/fstab

# 5. Verify the change
cat /mnt/sd-root/etc/fstab

# 6. Unmount
sudo umount /mnt/sd-root

# 7. Eject SD card and put it back in node-1
```

#### Quick Fix Script (if you can identify the device):

```bash
# macOS - adjust disk number
SD_DEVICE="/dev/disk2"
sudo mkdir -p /mnt/sd-root
sudo mount -t ext4 ${SD_DEVICE}s2 /mnt/sd-root
sudo sed -i.bak 's|defaults 0 2|defaults,nofail 0 2|g' /mnt/sd-root/etc/fstab
sudo sed -i.bak 's|/dev/sdb1.*ext4.*defaults|/dev/sdb1 /mnt/backup ext4 defaults,nofail|g' /mnt/sd-root/etc/fstab
cat /mnt/sd-root/etc/fstab  # Verify
sudo umount /mnt/sd-root
```

### Option 3: Use Another Pi or Computer with USB Keyboard

If you have access to another Pi or computer:

1. **Remove SD card from node-1**
2. **Insert into another Pi/computer**
3. **Follow Option 2 above** to fix fstab
4. **Put SD card back in node-1**

### Option 4: Enable SSH in Emergency Mode (If Network Works)

If the Pi has network but SSH isn't enabled in emergency mode:

1. **Mount SD card on another system** (Option 2)
2. **Enable SSH for emergency mode:**

```bash
# Mount root partition (see Option 2)
# Then:
sudo mkdir -p /mnt/sd-root/etc/systemd/system/emergency.service.d
echo '[Service]' | sudo tee /mnt/sd-root/etc/systemd/system/emergency.service.d/override.conf
echo 'ExecStart=' | sudo tee -a /mnt/sd-root/etc/systemd/system/emergency.service.d/override.conf
echo 'ExecStart=-/bin/bash' | sudo tee -a /mnt/sd-root/etc/systemd/system/emergency.service.d/override.conf
echo 'StandardInput=tty' | sudo tee -a /mnt/sd-root/etc/systemd/system/emergency.service.d/override.conf
echo 'StandardOutput=tty' | sudo tee -a /mnt/sd-root/etc/systemd/system/emergency.service.d/override.conf
```

## What to Fix in fstab

The issue is likely a mount entry without `nofail`. Look for lines like:

```
/dev/sdb1 /mnt/backup ext4 defaults 0 2
```

Change to:

```
/dev/sdb1 /mnt/backup ext4 defaults,nofail 0 2
```

Or if using UUID:

```
UUID=xxxx-xxxx /mnt/backup ext4 defaults 0 2
```

Change to:

```
UUID=xxxx-xxxx /mnt/backup ext4 defaults,nofail 0 2
```

## Quick Fix Script for SD Card

Save this script and run it after mounting the SD card:

```bash
#!/bin/bash
# fix-sd-card-fstab.sh
# Usage: sudo ./fix-sd-card-fstab.sh /mnt/sd-root

MOUNT_POINT="${1:-/mnt/sd-root}"

if [ ! -f "$MOUNT_POINT/etc/fstab" ]; then
    echo "Error: fstab not found at $MOUNT_POINT/etc/fstab"
    echo "Usage: sudo $0 /path/to/mounted/root"
    exit 1
fi

echo "Backing up fstab..."
cp "$MOUNT_POINT/etc/fstab" "$MOUNT_POINT/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"

echo "Fixing fstab..."
# Add nofail to any mount that doesn't have it (except root and boot)
sed -i.bak \
    -e 's|\(/mnt/backup.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' \
    -e 's|\(/dev/sdb1.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' \
    -e 's|\(UUID=.*/mnt/backup.*ext4.*defaults\)\([^,]*\)|\1,nofail|g' \
    "$MOUNT_POINT/etc/fstab"

echo "Fixed fstab:"
cat "$MOUNT_POINT/etc/fstab"
echo ""
echo "If this looks correct, unmount and test boot."
```

## After Fixing

1. **Put SD card back in node-1**
2. **Power on** - should boot normally
3. **Once booted, fix NVMe boot** (see NVME_BOOT_TROUBLESHOOTING.md)

## Prevention

To prevent this in the future, always use `nofail` for non-critical mounts:

```bash
# When adding mounts to fstab, always include nofail:
/dev/sdb1 /mnt/backup ext4 defaults,nofail 0 2
```

## Related Documentation

- [Boot Fix Guide](BOOT_FIX.md) - General boot troubleshooting
- [NVMe Boot Troubleshooting](NVME_BOOT_TROUBLESHOOTING.md) - NVMe boot issues
