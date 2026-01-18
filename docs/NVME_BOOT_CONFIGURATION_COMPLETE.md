# NVMe Boot Configuration Complete

## Status: ✅ Both Nodes Configured

Both **node-1** and **node-1** have been configured to boot from NVMe while preserving all existing data, including Kubernetes (K3s) data.

## Configuration Summary

### ✅ node-1 (192.168.2.86)
- **Boot configuration**: Updated to use `/dev/nvme0n1p2`
- **K3s data**: Preserved at `/var/lib/rancher/k3s`
- **Status**: Ready to boot from NVMe

### ✅ node-1 (192.168.2.85)
- **Boot configuration**: Updated to use `/dev/nvme0n1p2`
- **K3s data**: Preserved at `/var/lib/rancher/k3s`
- **Status**: Ready to boot from NVMe

## What Was Done

1. **Boot Configuration Updated**
   - `cmdline.txt` on NVMe boot partition now points to NVMe root
   - `fstab` on NVMe root partition updated with correct device references

2. **Data Preservation**
   - All K3s data preserved (no data erased)
   - Existing filesystem structure maintained
   - Only configuration files were updated

3. **Boot Order**
   - SD card remains as backup boot option
   - Raspberry Pi 5 default: SD card first, then NVMe

## Next Steps

### Reboot Both Nodes

**node-1:**
```bash
ssh raolivei@node-1.local
sudo reboot
```

**node-1:**
```bash
ssh raolivei@node-1.local
sudo reboot
```

### Verify Boot from NVMe

After reboot, verify on each node:

```bash
# Check root filesystem
df -h /
# Should show: /dev/nvme0n1p2

# Check boot partition
mount | grep "/boot/firmware"
# Should show: /dev/nvme0n1p1

# Verify K3s data
ls -la /var/lib/rancher/k3s
# Should show K3s directories (agent, server, data, storage)

# Check boot device
lsblk
# Root (/) should be on nvme0n1p2
```

## Boot Behavior

### With SD Card Inserted
- Raspberry Pi 5 will try SD card first
- If SD card boot fails or is not bootable, system will boot from NVMe
- SD card acts as safety backup

### With SD Card Removed
- System will boot directly from NVMe

### Fallback
- If NVMe boot fails, system will fall back to SD card (if present)

## Files Modified

### Boot Partition (`/dev/nvme0n1p1`)
- `cmdline.txt` - Updated with `root=/dev/nvme0n1p2`

### Root Partition (`/dev/nvme0n1p2`)
- `/etc/fstab` - Updated device references

### Data Preserved
- `/var/lib/rancher/k3s/` - All K3s data intact
- All other files and directories - Unchanged

## Troubleshooting

### Still Booting from SD Card After Reboot

1. **Check cmdline.txt:**
   ```bash
   sudo mount /dev/nvme0n1p1 /mnt
   cat /mnt/cmdline.txt
   # Should contain: root=/dev/nvme0n1p2
   sudo umount /mnt
   ```

2. **If incorrect, fix it:**
   ```bash
   sudo mount /dev/nvme0n1p1 /mnt
   sudo sed -i 's|root=[^ ]*|root=/dev/nvme0n1p2|g' /mnt/cmdline.txt
   cat /mnt/cmdline.txt  # Verify
   sudo umount /mnt
   sudo reboot
   ```

### K3s Not Starting

1. **Check if K3s data exists:**
   ```bash
   ls -la /var/lib/rancher/k3s
   ```

2. **Check K3s service:**
   ```bash
   sudo systemctl status k3s
   sudo journalctl -u k3s -n 50
   ```

3. **Restart K3s if needed:**
   ```bash
   sudo systemctl restart k3s
   ```

### Boot Fails

1. **Remove NVMe** (or it will try NVMe first)
2. **Boot from SD card** (automatic fallback)
3. **Check logs:**
   ```bash
   sudo journalctl -b -1  # Previous boot
   ```

## Configuration Script

The configuration was done using:
- `configure-nvme-boot-preserve-data.sh`

This script:
- ✅ Preserves all existing data
- ✅ Updates boot configuration
- ✅ Verifies K3s data preservation
- ✅ Does NOT erase any data

## Related Documentation

- [NVMe Boot Setup](NVME_BOOT_SETUP.md) - Original setup guide
- [NVMe Boot Troubleshooting](NVME_BOOT_TROUBLESHOOTING.md) - Troubleshooting guide
- [Node Configuration Summary](NODE_CONFIGURATION_SUMMARY.md) - Complete configuration summary

