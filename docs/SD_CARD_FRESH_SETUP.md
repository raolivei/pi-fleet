# SD Card Fresh Setup - Complete Guide

## Problem

SD card is stuck in busybox/initramfs even after fixes. This indicates:
- Corrupted initramfs
- Fstab issues that can't be fixed
- Filesystem corruption

**Solution**: Format and recreate SD card from scratch.

## Step 1: Format SD Card with Raspberry Pi Imager

### Settings

1. **OS**: Debian 12 Bookworm (64-bit) - Raspberry Pi
2. **Hostname**: `node-x` (generic, works for any node)
3. **User**: `raolivei`
4. **Password**: `Control01!` (different from main password)
5. **SSH**: ✅ Enable (password authentication)
6. **WiFi**: Configure your network (or use ethernet)

### Why Different Password?

`Control01!` is intentionally different to:
- **Prevent mistakes** - You'll notice if you're on wrong OS
- **Safety** - Won't accidentally run commands on production
- **Recovery context** - Clear indication you're in recovery mode

## Step 2: Boot from SD Card

1. **Insert SD card** into any node (e.g., node-3)
2. **Remove NVMe** temporarily (to ensure boot from SD)
3. **Power on** - Wait 2-3 minutes for first boot
4. **Verify** - Check IP address:
   ```bash
   ping -c 1 192.168.2.103  # node-3
   # or
   ping -c 1 192.168.2.102  # node-2
   # or
   ping -c 1 192.168.2.101  # node-1
   ```

## Step 3: Apply Boot Reliability Fixes Automatically

Once SD card OS is booted, run the setup script:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# The script will identify the node by IP and apply all fixes
./scripts/setup-sd-card-os.sh 192.168.2.103  # Use the IP where SD card booted
```

The script will:
- ✅ Verify SSH access
- ✅ Apply boot reliability fixes to SD card
- ✅ Remove unused backup mount
- ✅ Disable PAM faillock
- ✅ Unlock root account
- ✅ Verify configuration

## Step 4: Verify SD Card OS

```bash
# SSH to node
ssh raolivei@192.168.2.103  # Use appropriate IP, password: Control01!

# Check fixes applied
sudo grep nofail /etc/fstab
sudo grep -v '/dev/sdb1' /etc/fstab  # Should not have backup mount
sudo passwd -S root  # Should show unlocked (P or NP)
cat /etc/hostname     # Should be "node-x"
```

## Step 5: Test Reboot

```bash
# Reboot from SD card
ssh raolivei@192.168.2.103 "sudo reboot"

# Wait 2-3 minutes, then verify
ping -c 1 192.168.2.103
ssh raolivei@192.168.2.103 "hostname"  # Should be "node-x"
ssh raolivei@192.168.2.103 "df -h / | grep mmcblk"  # Should show SD card as root
```

## Step 6: SD Card is Ready

The SD card is now ready for recovery use. You can:
- **Keep it as backup** - Use when NVMe boot fails
- **Clone it** - Create copies for other nodes
- **Use for recovery** - Insert into any node, remove NVMe, boot

## Recovery Workflow

When a node fails to boot from NVMe:

1. **Power off** the problematic node
2. **Remove NVMe** (temporarily)
3. **Insert SD card** (the one we just configured)
4. **Power on** - Node boots from SD card
5. **Identify node** by IP address
6. **Mount NVMe** and fix it:
   ```bash
   # Use the recovery script - it will mount NVMe and fix it
   cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
   ./scripts/recover-node-by-ip.sh 192.168.2.101  # node-1 example
   ```
7. **Remove SD card**, ensure NVMe is connected
8. **Reboot** - Node should boot from NVMe

## Troubleshooting

### SD Card Still Stuck in Initramfs

If after fresh format it still gets stuck:

1. **Check SD card health**:
   ```bash
   # On a working node, check SD card
   sudo fsck -f /dev/mmcblk0p2
   ```

2. **Try different SD card** - May be hardware issue

3. **Check boot logs** (if you have console access):
   ```bash
   # In initramfs/busybox
   cat /proc/cmdline
   lsblk
   mount
   ```

4. **Verify fstab manually** (if you can mount):
   ```bash
   # In initramfs, try to mount root manually
   mkdir /mnt
   mount /dev/mmcblk0p2 /mnt
   cat /mnt/etc/fstab
   ```

### SD Card Won't Boot at All

- Verify SD card is properly inserted
- Check boot order (SD before NVMe)
- Try another SD card
- Verify image was written correctly (use Raspberry Pi Imager's verify option)

### Can't SSH to SD Card OS

- Check IP address (may be different from NVMe)
- Verify SSH is enabled in Raspberry Pi Imager
- Check password: `Control01!`
- Verify network connection
- Wait longer for first boot (can take 3-5 minutes)

## Alternative: Fix SD Card While Mounted

If you prefer to fix the SD card while it's mounted on node-2 (without booting from it):

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
./scripts/fix-sd-card-on-node2.sh
```

**Note**: This only works if the SD card filesystem is intact. If it's corrupted, you need to format it.

## SD Card Requirements

- **Size**: At least 16GB (32GB recommended)
- **Speed**: Class 10 or better (UHS-I recommended)
- **Format**: Will be formatted by Raspberry Pi Imager
- **OS**: Debian 12 Bookworm (64-bit)

## Maintenance

The SD card OS should be:
- **Updated periodically** - Re-image with latest Debian
- **Tested** - Boot from it occasionally to verify it works
- **Backed up** - Keep a copy of the configured SD card image

## Quick Reference

### Create Fresh SD Card
1. Use Raspberry Pi Imager
2. Settings: hostname=node-x, user=raolivei, password=Control01!
3. Write to SD card

### Setup SD Card After Imaging
```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
./scripts/setup-sd-card-os.sh <IP_ADDRESS>
```

### Use SD Card for Recovery
1. Insert SD card, remove NVMe
2. Boot node
3. Run: `./scripts/recover-node-by-ip.sh <IP>` (fixes NVMe)
4. Remove SD card, ensure NVMe connected
5. Reboot

