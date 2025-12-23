# NVMe HAT Migration - Quick Start Guide

## Current Status

✅ **node-0**: Pre-migration backup completed
- Backup location: `/mnt/sd-backup/nvme-migration-backup-*`
- K3s data and configs backed up to SD card

⚠️ **node-1**: Pre-migration backup needed (if not done yet)

## Migration Order

**Recommended**: Migrate node-1 (worker) first, then node-0 (control plane) to maintain cluster availability.

**Alternative**: If node-1 is already down/NotReady, you can migrate node-0 first.

## After Hardware Replacement

### Step 1: Boot from SD Card

After replacing the HAT and NVMe hardware:
1. Ensure 64GB SD card is inserted
2. Power on the node
3. System should boot from SD card automatically

### Step 2: Verify Boot from SD Card

```bash
ssh node-0  # or ssh to the node
df -h /  # Should show /dev/mmcblk0p2 (SD card)
lsblk | grep nvme  # Should show new 128GB NVMe
```

### Step 3: Run Migration Script

The migration scripts should already be in your home directory. If not, copy them:

```bash
# If scripts are missing, copy from pi-fleet repo
cd ~
# Or copy from another location
```

Then run:

```bash
sudo ./migrate-nvme-hat.sh node-0
# or
sudo ./migrate-nvme-hat.sh node-1
```

The script will:
1. Detect new 128GB NVMe
2. Create partitions (512MB boot + root)
3. Clone OS from SD card to new NVMe
4. Update boot configuration
5. Preserve K3s data from backup

### Step 4: Reboot

```bash
sudo reboot
```

### Step 5: Verify Migration

After reboot:

```bash
ssh node-0  # or node-1
./verify-nvme-migration.sh node-0  # or node-1
```

Check:
- `df -h /` should show `/dev/nvme0n1p2`
- `mount | grep boot` should show `/dev/nvme0n1p1`
- K3s should be running

### Step 6: Restore K3s Data (if needed)

If K3s data wasn't automatically preserved:

```bash
# Find backup location
ls -d /mnt/sd-backup/nvme-migration-backup-*

# Restore K3s data
sudo systemctl stop k3s  # or k3s-agent
sudo cp -r /mnt/sd-backup/nvme-migration-backup-*/k3s/* /var/lib/rancher/k3s/
sudo systemctl start k3s  # or k3s-agent
```

## Troubleshooting

### New NVMe Not Detected

```bash
lsblk | grep nvme
# If not showing, check:
# 1. HAT is properly connected
# 2. NVMe is properly seated
# 3. Power cycle the Pi
```

### Boot Fails After Migration

1. Remove new NVMe
2. Boot from SD card
3. Check logs: `sudo journalctl -b -1`
4. Re-run migration script

### K3s Not Starting

```bash
sudo systemctl status k3s  # or k3s-agent
sudo journalctl -u k3s -n 50  # or k3s-agent
# Check if data directory exists:
ls -la /var/lib/rancher/k3s
```

## Files Reference

- Migration script: `~/migrate-nvme-hat.sh`
- Verification script: `~/verify-nvme-migration.sh`
- Backup script: `~/pre-migration-backup.sh` (already run)

## Next Node

After successfully migrating one node:
1. Repeat hardware replacement on the other node
2. Follow same steps (boot from SD, run migration script, reboot, verify)

## Secure Erase Old Drives

After migration is complete and verified on both nodes, you can securely erase the old 256GB drives before returning them:

```bash
# Copy erase script if needed
scp pi-fleet/scripts/storage/secure-erase-old-nvme.sh node-0:~/

# SSH to node
ssh node-0

# Run secure erase (replace device path if needed)
sudo ./secure-erase-old-nvme.sh /dev/nvme0n1
```

**Note**: The old drive may not be accessible after hardware replacement. You can:
- Erase it before removing (if still connected)
- Connect via USB adapter to erase
- See [Secure Erase Guide](SECURE_ERASE_OLD_DRIVES.md) for details

**Warning**: This permanently destroys all data. Only run after migration is verified complete!

