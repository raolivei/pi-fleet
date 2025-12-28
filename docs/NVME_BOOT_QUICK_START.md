# Quick Start: Boot from NVMe

## Current Status

✅ Script is ready on node-0: `~/setup-nvme-boot.sh`

## What the Script Does

1. **Stops K3s** (temporarily)
2. **Unmounts** current NVMe mount (`/mnt/nvme`)
3. **Repartitions NVMe** (boot + root partitions)
4. **Clones OS** from SD card to NVMe
5. **Configures boot** to use NVMe
6. **Restarts K3s**

## ⚠️ Important Notes

- **This will erase all data on NVMe** (currently mounted at `/mnt/nvme`)
- **Backup any important data** from `/mnt/nvme` first if needed
- **SD card remains as backup** - if NVMe boot fails, Pi will boot from SD card
- **Process takes 10-30 minutes** (depending on SD card speed)

## Run the Setup

```bash
# SSH to node-0 (control plane)
# Use SSH key authentication (recommended):
ssh raolivei@192.168.2.86
# Or use hostname if DNS is configured:
# ssh raolivei@node-0.eldertree.local

# If password authentication is required:
# sshpass -p 'YOUR_PASSWORD' ssh raolivei@192.168.2.86

# Run the script
~/setup-nvme-boot.sh
```

The script will:
- Ask for confirmation before proceeding
- Show progress during cloning
- Configure everything automatically
- Prompt you to reboot at the end

## After Reboot

After rebooting, verify you're booting from NVMe:

```bash
# Check root filesystem
df -h /
# Should show /dev/nvme0n1p2

# Check boot partition
mount | grep "/boot/firmware"
# Should show /dev/nvme0n1p1
```

## If Something Goes Wrong

1. **Remove NVMe** (or it will try to boot from it)
2. **Boot from SD card** (automatic fallback)
3. **Check logs**: `sudo journalctl -b -1` (previous boot)
4. **Re-run script** if needed

## Benefits

- ✅ **2-3x faster boot times**
- ✅ **Much faster I/O** for K3s and databases
- ✅ **Reduced SD card wear**
- ✅ **SD card as backup** boot option

