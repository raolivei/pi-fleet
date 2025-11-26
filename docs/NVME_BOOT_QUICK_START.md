# Quick Start: Boot from NVMe

## Current Status

✅ Ansible playbook is ready: `ansible/playbooks/setup-nvme-boot.yml`

## What the Playbook Does

1. **Checks prerequisites** (Pi 5, NVMe detected)
2. **Stops K3s** (temporarily, if running)
3. **Unmounts** current NVMe mounts
4. **Creates partitions** on NVMe (boot + root)
5. **Clones OS** from SD card to NVMe
6. **Resizes filesystem** to match partition
7. **Configures boot** (fstab, cmdline.txt)
8. **Restarts K3s** (if it was running)

## ⚠️ Important Notes

- **This will erase all data on NVMe**
- **Backup any important data** from NVMe first if needed
- **SD card remains as backup** - if NVMe boot fails, Pi will boot from SD card
- **Process takes 10-30 minutes** (depending on SD card speed)
- **Idempotent** - safe to run multiple times (skips if already booting from NVMe)

## Run the Setup

From your Mac:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook playbooks/setup-nvme-boot.yml \
  -e setup_nvme_boot=true \
  -e clone_from_sd=true \
  --ask-become-pass
```

Or use the convenience script:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/setup/setup-nvme-boot.sh
```

The playbook will:

- Check prerequisites automatically
- Show progress during cloning
- Configure everything automatically
- Display completion message

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
4. **Re-run playbook** if needed

## Benefits

- ✅ **2-3x faster boot times**
- ✅ **Much faster I/O** for K3s and databases
- ✅ **Reduced SD card wear**
- ✅ **SD card as backup** boot option
