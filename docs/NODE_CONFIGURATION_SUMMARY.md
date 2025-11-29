# Node Configuration Summary

## Completed Tasks

### ✅ 1. SSH Keys Configured

- **node-0** (192.168.2.86): SSH key configured
- **node-1** (192.168.2.85): SSH key configured

You can now SSH to both nodes without password:

```bash
ssh raolivei@node-0.local
ssh raolivei@node-1.local
```

### ✅ 2. Boot Order Configuration

**Raspberry Pi 5 Default Boot Order:**

1. **SD card** (if present and bootable) - **FIRST**
2. USB devices
3. **NVMe** (if present and bootable) - **SECOND**

This is the hardware default behavior - SD card is always tried first, then NVMe if SD card is not available or fails to boot.

**Current Status:**

- **node-0**: Booting from SD card, NVMe available
- **node-1**: Booting from SD card, NVMe available (needs boot setup)

### 🔄 3. NVMe Boot Setup on node-1

**Status**: In progress

**Current State:**

- node-1 is booting from SD card (`/dev/mmcblk0p2`)
- NVMe has partitions (`/dev/nvme0n1p1` boot, `/dev/nvme0n1p2` root)
- NVMe boot partition has `cmdline.txt` but system is not booting from it

**To Complete NVMe Boot Setup:**

Run on node-1:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/scripts/storage
sudo ./setup-nvme-boot.sh
```

Or use the helper script:

```bash
chmod +x ~/setup-node1-nvme-boot.sh
./setup-node1-nvme-boot.sh
```

**What the setup does:**

1. Stops K3s (temporarily)
2. Clones OS from SD card to NVMe
3. Updates boot configuration (`cmdline.txt`, `fstab`)
4. Configures system to boot from NVMe
5. Keeps SD card as backup boot option

**After setup:**

- Reboot: `sudo reboot`
- System will boot from NVMe
- SD card remains as backup (will boot from SD if NVMe fails)

## Boot Order Verification

### How Boot Order Works on Pi 5

The Raspberry Pi 5 firmware automatically tries boot devices in this order:

1. **SD card** - Always tried first if present
2. **USB devices** - Tried if SD card not available
3. **NVMe** - Tried if SD card and USB not available

**This means:**

- If SD card is present and bootable → boots from SD card
- If SD card is removed or not bootable → boots from NVMe
- SD card acts as a safety backup

### To Test Boot Order

1. **Boot from SD card** (current):

   - Keep SD card inserted
   - System boots from SD card

2. **Boot from NVMe** (after setup):

   - After NVMe boot setup, system will boot from NVMe
   - SD card still inserted → Pi tries SD first, but if NVMe is configured and SD boot fails, it will use NVMe
   - Actually, if both are bootable, Pi 5 will prefer SD card

3. **Force NVMe boot**:
   - Remove SD card
   - System will boot from NVMe

## Files Created

- `scripts/utils/configure-nodes-complete.sh` - Main configuration script
- `scripts/utils/setup-node1-nvme-boot.sh` - NVMe boot setup helper
- `scripts/utils/setup-boot-order.sh` - Boot order verification
- `scripts/utils/check-and-setup-nvme-boot.sh` - NVMe boot status check

## Next Steps

1. ✅ SSH keys configured
2. ✅ Boot order verified (SD first, then NVMe)
3. 🔄 Complete NVMe boot setup on node-1
4. ⏳ Verify boot configuration after setup

## Troubleshooting

### SSH Key Issues

```bash
# Test SSH connection
ssh raolivei@node-0.local
ssh raolivei@node-1.local

# If password still required, check authorized_keys
ssh raolivei@node-0.local "cat ~/.ssh/authorized_keys"
```

### Boot Order Issues

- Pi 5 boot order is hardware-determined
- Cannot easily change the order
- SD card is always tried first
- NVMe is used as fallback

### NVMe Boot Issues

See: [NVMe Boot Troubleshooting](NVME_BOOT_TROUBLESHOOTING.md)
