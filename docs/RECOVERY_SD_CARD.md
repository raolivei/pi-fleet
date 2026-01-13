<!-- MIGRATED TO RUNBOOK -->
> **📚 This document has been migrated to the Eldertree Runbook**
>
> For the latest version, see: [EMERG-004](https://docs.eldertree.xyz/runbook/issues/boot/EMERG-004)
>
> The runbook provides searchable troubleshooting guides with improved formatting.

---


# Universal Recovery SD Card

A universal recovery SD card that can boot any Raspberry Pi in the fleet when the primary NVMe boot fails.

## Purpose

When a Pi's NVMe boot configuration gets corrupted (like `cmdline.txt` issues), you can use this recovery SD card to:
- Boot the Pi from SD card
- Access the NVMe drive to fix boot issues
- Run recovery scripts
- Restore normal NVMe boot

## Creating the Recovery SD Card

### Prerequisites

1. **Raspberry Pi OS Image**: Download from [raspberrypi.com](https://www.raspberrypi.com/software/operating-systems/)
   - Recommended: Raspberry Pi OS Lite (64-bit)
   - Save to `~/Downloads/raspios.img` or specify path

2. **SD Card**: At least 8GB (16GB+ recommended)

### macOS

```bash
cd pi-fleet/scripts/storage
./create-recovery-sd.sh /dev/diskX
```

Find the SD card device:
```bash
diskutil list
# Look for external disk, e.g., /dev/disk2
```

### Linux

```bash
cd pi-fleet/scripts/storage
./create-recovery-sd.sh /dev/sdX
```

Find the SD card device:
```bash
lsblk
# or
fdisk -l
```

## Recovery SD Card Configuration

The recovery SD card is configured with:

- **Hostname**: `node-x` (generic, works for any node)
- **Boot source**: SD card (`/dev/mmcblk0p2`)
- **SSH**: Enabled by default
- **WiFi**: Config file created (add credentials manually)
- **User**: `pi` (default password: `raspberry`)

## Boot Priority

**Important**: Raspberry Pi boot firmware checks devices in this order:

1. **SD Card** (checked first) - If a bootable SD card is present, it will boot from SD
2. **USB/NVMe** (fallback) - Only used if SD card is not present or not bootable

This means:
- ✅ **Recovery SD card will boot in preference** when inserted, even if NVMe is present
- ✅ **No configuration needed** - this is the default Raspberry Pi behavior
- ✅ **Safe to leave SD card inserted** - it will only boot from SD if the SD card is bootable

**Note**: The fix we applied to `cmdline.txt` only affects the NVMe boot configuration. It does not change boot priority. The firmware's boot order (SD first, then NVMe) is hardcoded and cannot be changed.

## Using the Recovery SD Card

### Step 1: Boot from SD Card

1. **Insert the recovery SD card** into the Pi (can be inserted while Pi is running or powered off)
2. **Power on the Pi** (or reboot if already running)
3. **Wait for boot** (may take 1-2 minutes)
4. **Verify boot from SD**: The Pi will automatically boot from SD card in preference to NVMe

**Boot Priority**: The Raspberry Pi firmware checks SD card first, so the recovery SD card will always boot when inserted, even if NVMe is present and configured.

### Step 2: Connect via SSH

```bash
# Default credentials
ssh pi@node-x.local
# or
ssh pi@<pi-ip-address>
# Password: raspberry
```

**Note**: If you don't know the IP, check your router's DHCP client list or use:
```bash
# On your local machine
nmap -sn 192.168.2.0/24 | grep -B 2 "node-x"
```

### Step 3: Fix NVMe Boot

Once connected, run the recovery script:

```bash
# Clone pi-fleet repo if not already present
git clone <your-repo-url> /tmp/pi-fleet
cd /tmp/pi-fleet/scripts/storage

# Run recovery script
sudo ./fix-cmdline-recovery.sh
```

The script will:
- Mount the NVMe boot partition
- Fix `cmdline.txt` (restore `root=` parameter)
- Add cgroup parameter if missing
- Verify the fix

### Step 4: Reboot to NVMe

After fixing, reboot:

```bash
sudo reboot
```

The Pi should now boot from NVMe normally.

## Recovery Scripts

### fix-cmdline-recovery.sh

Fixes corrupted `cmdline.txt` on NVMe boot partition:
- Restores missing `root=` parameter
- Adds cgroup parameter if missing
- Validates the fix

**Usage**:
```bash
sudo ./fix-cmdline-recovery.sh
```

### switch-boot-to-sd.sh

Switches boot configuration to SD card (useful for maintenance):
```bash
sudo ./switch-boot-to-sd.sh
```

## Troubleshooting

### SD Card Won't Boot

1. **Check SD card**: Ensure it's properly inserted and making good contact
2. **Check image**: Verify the image was written correctly (try rewriting)
3. **Check boot partition**: Ensure boot partition is FAT32 and contains `cmdline.txt`
4. **Remove NVMe temporarily**: If SD card still won't boot, temporarily remove NVMe to isolate the issue

### Can't SSH to Recovery SD

1. **Check network**: Ensure Pi is on same network
2. **Check SSH**: Verify `ssh` file exists in boot partition
3. **Check firewall**: Router may be blocking connections
4. **Use serial console**: Connect via USB-to-serial adapter if available

### Recovery Script Fails

1. **Check NVMe access**: Ensure NVMe is properly connected
2. **Check permissions**: Script needs sudo/root access
3. **Manual fix**: See manual recovery steps below

## Manual Recovery

If automated scripts fail, you can manually fix `cmdline.txt`:

```bash
# Mount NVMe boot partition
sudo mkdir -p /mnt/nvme-boot
sudo mount /dev/nvme0n1p1 /mnt/nvme-boot

# Backup
sudo cp /mnt/nvme-boot/cmdline.txt /mnt/nvme-boot/cmdline.txt.bak

# Edit cmdline.txt
sudo nano /mnt/nvme-boot/cmdline.txt
```

Ensure it contains:
```
console=serial0,115200 console=tty1 root=/dev/nvme0n1p2 rootfstype=ext4 fsck.repair=yes rootwait rootdelay=5 quiet systemd.unified_cgroup_hierarchy=0
```

Key parameters:
- `root=/dev/nvme0n1p2` - Root filesystem on NVMe
- `rootwait` - Wait for root device
- `rootdelay=5` - Delay for NVMe initialization
- `systemd.unified_cgroup_hierarchy=0` - Required for k3s

Save and reboot:
```bash
sync
sudo umount /mnt/nvme-boot
sudo reboot
```

## Best Practices

1. **Keep recovery SD card updated**: Recreate periodically with latest Raspberry Pi OS
2. **Test recovery process**: Periodically test that recovery SD card works
3. **Document node-specific issues**: Note any node-specific recovery steps
4. **Backup before changes**: Always backup `cmdline.txt` before modifications
5. **Use Ansible safeguards**: The improved Ansible playbooks now include automatic backups

## Related Documentation

- [NVMe Migration Guide](MIGRATION_NVME_HAT_QUICK_START.md)
- [Emergency Deployment](EMERGENCY_DEPLOYMENT.md)
- [Ansible Playbooks](../ansible/README.md)

