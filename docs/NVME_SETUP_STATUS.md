# NVMe Boot Setup Status - node-1

## Current Status

✅ **SSH Keys**: Configured on both nodes  
✅ **Boot Order**: SD card first, then NVMe (Pi 5 default)  
🔄 **NVMe Boot Setup**: Script ready, needs to be run interactively

## Complete NVMe Boot Setup on node-1

The setup script is ready but needs to be run interactively. Here's how to complete it:

### Option 1: Run Interactively (Recommended)

```bash
ssh raolivei@node-1.local
cd ~
sudo ./setup-nvme-boot.sh
```

When prompted:

- "This will erase all data on NVMe. Continue? (y/N)": Type `y` and press Enter
- "Have you backed up important data? Continue? (y/N)": Type `y` and press Enter

The setup will:

1. Stop K3s (temporarily)
2. Clone OS from SD card to NVMe (10-30 minutes)
3. Configure boot to use NVMe
4. Restart K3s

### Option 2: Run with Auto-Confirmation

```bash
ssh raolivei@node-1.local
cd ~
printf 'y\ny\n' | sudo ./setup-nvme-boot.sh 2>&1 | tee /tmp/nvme-setup.log
```

### Monitor Progress

While setup is running:

```bash
# On another terminal
ssh raolivei@node-1.local
tail -f /tmp/nvme-setup.log
```

### After Setup Completes

1. **Reboot node-1:**

   ```bash
   ssh raolivei@node-1.local
   sudo reboot
   ```

2. **Verify boot from NVMe:**

   ```bash
   ssh raolivei@node-1.local
   df -h /
   # Should show /dev/nvme0n1p2

   mount | grep "/boot/firmware"
   # Should show /dev/nvme0n1p1
   ```

3. **Check boot device:**
   ```bash
   lsblk
   # Root (/) should be on nvme0n1p2
   ```

## Boot Order Behavior

After setup:

- **With SD card inserted**: Pi 5 will try SD card first, but if NVMe is configured and SD boot fails, it will use NVMe
- **SD card removed**: System will boot from NVMe
- **SD card as backup**: If NVMe boot fails, system will fall back to SD card

## Troubleshooting

### Setup Fails or Hangs

1. Check if process is running:

   ```bash
   ssh raolivei@node-1.local
   ps aux | grep setup-nvme
   ```

2. Check logs:

   ```bash
   ssh raolivei@node-1.local
   cat /tmp/nvme-setup.log
   ```

3. If stuck, kill and restart:
   ```bash
   ssh raolivei@node-1.local
   sudo pkill -f setup-nvme-boot
   # Then run setup again
   ```

### After Reboot, Still Booting from SD Card

1. Check NVMe boot partition:

   ```bash
   ssh raolivei@node-1.local
   sudo mount /dev/nvme0n1p1 /mnt
   cat /mnt/cmdline.txt
   # Should contain: root=/dev/nvme0n1p2
   sudo umount /mnt
   ```

2. If cmdline.txt is wrong, fix it:
   ```bash
   sudo mount /dev/nvme0n1p1 /mnt
   sudo sed -i 's|root=/dev/mmcblk0p2|root=/dev/nvme0n1p2|g' /mnt/cmdline.txt
   sudo umount /mnt
   sudo reboot
   ```

## Files

- Setup script: `~/setup-nvme-boot.sh` (on node-1)
- Log file: `/tmp/nvme-setup.log` (created during setup)

## Next Steps After Setup

1. ✅ Verify boot from NVMe
2. ✅ Test that SD card still works as backup (remove NVMe, boot from SD)
3. ✅ Update documentation with final status
