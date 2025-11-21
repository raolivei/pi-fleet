# Boot Fix Guide - Automatic Boot and Bluetooth

**Note**: This guide is for fixing existing installations. For fresh installs, use the automated setup scripts which configure everything correctly from the start.

This guide helps fix boot issues where the system waits for USB backup drive and enters emergency mode.

## Problem

The system fails to boot because:

- `/dev/sdb1` (USB backup drive) timeout causes boot failure
- System enters emergency mode requiring manual intervention
- Bluetooth may not start, preventing keyboard pairing

## Solution

### Option 1: Remote Fix (Recommended if SSH available)

If you can SSH to the Pi after it boots (even temporarily):

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/scripts
# Note: Fix scripts have been removed. Use Ansible playbook setup-system.yml for fresh installs.
```

This will:

- Fix fstab to add `nofail` option
- Enable and start Bluetooth
- Configure automatic boot

### Option 2: Manual Fix at Console

If you have physical access and can log in (try passwords: `pi` or `Control01!`):

#### Step 1: Fix fstab

```bash
# Edit fstab
sudo nano /etc/fstab

# Find the line with /mnt/backup, it should look like:
# /dev/sdb1 /mnt/backup ext4 defaults 0 2

# Add ',nofail' to the options (4th field):
# /dev/sdb1 /mnt/backup ext4 defaults,nofail 0 2

# Save and exit (Ctrl+X, Y, Enter)
```

#### Step 2: Enable Bluetooth

```bash
# Enable Bluetooth service
sudo systemctl enable bluetooth

# Start Bluetooth service
sudo systemctl start bluetooth

# Check status
sudo systemctl status bluetooth
```

#### Step 3: Boot to Default Mode

```bash
# Exit emergency mode and boot normally
sudo systemctl default

# Or reboot
sudo reboot
```

### Option 3: Emergency Console Fix

If you're stuck at the emergency console:

1. **Try passwords**: `pi` or `Control01!`
2. **If root is locked**, you may need to boot from recovery media or:

   ```bash
   # Try to unlock root (if you have sudo access)
   sudo passwd -u root
   ```

3. **Once logged in**, follow Option 2 above

## What the Fix Does

### fstab Changes

The fix adds the `nofail` mount option to `/etc/fstab`:

**Before:**

```
/dev/sdb1 /mnt/backup ext4 defaults 0 2
```

**After:**

```
/dev/sdb1 /mnt/backup ext4 defaults,nofail 0 2
```

The `nofail` option tells systemd to continue booting even if the USB drive isn't available. The drive will still mount automatically when it's plugged in.

### Bluetooth Configuration

- Enables `bluetooth.service` to start on boot
- Starts the service immediately
- Allows Bluetooth keyboard pairing

## Verification

After rebooting, verify everything works:

```bash
# Check if system booted normally (not emergency mode)
systemctl is-system-running

# Check if backup mount is configured (may show as inactive if USB not plugged in)
systemctl status mnt-backup.mount

# Check Bluetooth status
systemctl status bluetooth
bluetoothctl show

# Check if USB drive mounts when plugged in
lsblk | grep sdb
sudo mount /dev/sdb1 /mnt/backup
df -h /mnt/backup
```

## Troubleshooting

### Root Account Locked

If you see "Cannot open access to console, the root account is locked":

1. Boot from recovery media or use a different method to access the system
2. Or if you can SSH as another user:
   ```bash
   sudo passwd -u root
   sudo passwd root  # Set a password
   ```

### Bluetooth Not Working

If Bluetooth still doesn't work:

```bash
# Check if Bluetooth hardware is detected
hciconfig

# Install Bluetooth packages if missing
sudo apt-get update
sudo apt-get install -y bluez bluez-tools

# Check kernel modules
lsmod | grep bluetooth

# Restart Bluetooth service
sudo systemctl restart bluetooth
```

### USB Drive Still Not Mounting

If the USB drive doesn't mount when plugged in:

```bash
# Check if device is detected
lsblk | grep sdb

# Check filesystem
sudo fsck /dev/sdb1

# Try manual mount
sudo mount /dev/sdb1 /mnt/backup

# Check mount options
mount | grep backup
```

## Prevention

To prevent this issue in the future:

1. **Always use `nofail` option** for non-critical mounts in `/etc/fstab`
2. **Test boot** after adding new mounts
3. **Keep USB drive connected** if it's critical for boot
4. **Use UUID instead of device name** for more reliable mounting:

   ```bash
   # Get UUID
   sudo blkid /dev/sdb1

   # Use UUID in fstab:
   # UUID=xxxx-xxxx /mnt/backup ext4 defaults,nofail 0 2
   ```

## Related Documentation

- [Backup Strategy](./BACKUP_STRATEGY.md) - Backup system documentation
- [Troubleshooting USB Drive Not Mounted](./BACKUP_STRATEGY.md#usb-drive-not-mounted)
