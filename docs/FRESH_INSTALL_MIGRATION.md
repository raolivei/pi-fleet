# Fresh Install and Migration to New NVMe

## Overview

Starting fresh with new HAT and 128GB NVMe drives. We'll:

1. Install Raspberry Pi OS on SD card
2. Boot from SD card
3. Clone OS to new NVMe
4. Configure boot from NVMe

## Step 1: Install Raspberry Pi OS on SD Card

### Option A: Using Raspberry Pi Imager (Recommended)

1. **Download Raspberry Pi Imager**:

   - Visit: https://www.raspberrypi.com/software/
   - Download for macOS

2. **Insert SD card** into your Mac

3. **Open Raspberry Pi Imager**:

   - Click "Choose OS" → Select "Raspberry Pi OS (other)" → "Raspberry Pi OS (64-bit)"
   - Click "Choose Storage" → Select your SD card
   - Click the gear icon (⚙️) to configure:
     - **Enable SSH**: ✅ (with password authentication or public key)
     - **Set username**: `raolivei`
     - **Set password**: (your password)
     - **Configure wireless LAN**: (optional, or use ethernet)
     - **Set locale settings**: (timezone, keyboard, etc.)

4. **Write to SD card**:
   - Click "Write" and wait for completion

### Option B: Manual Installation

If you prefer manual installation:

```bash
# Download Raspberry Pi OS image
# Visit: https://www.raspberrypi.com/software/operating-systems/

# Find SD card device (BE CAREFUL - verify this is your SD card!)
diskutil list

# Unmount SD card
diskutil unmountDisk /dev/diskX  # Replace X with your SD card number

# Write image (this will erase everything on the SD card!)
sudo dd if=/path/to/raspios.img of=/dev/rdiskX bs=1m status=progress

# Eject
diskutil eject /dev/diskX
```

## Step 2: Boot from SD Card

1. **Insert SD card** into Raspberry Pi
2. **Power on** the node
3. **Wait for boot** (1-2 minutes)
4. **SSH to node**:
   ```bash
   ssh raolivei@node-1.eldertree.local
   # or
   ssh raolivei@192.168.2.86
   ```

## Step 3: Verify Boot from SD Card

```bash
# Check root filesystem
df -h /  # Should show /dev/mmcblk0p2

# Check new NVMe is detected
lsblk | grep nvme
# Should show /dev/nvme0n1 (new 128GB drive)
```

## Step 4: Copy Migration Scripts

```bash
# Copy scripts to node
scp pi-fleet/scripts/storage/migrate-nvme-hat.sh node-1:~/
scp pi-fleet/scripts/storage/verify-nvme-migration.sh node-1:~/

# Or clone pi-fleet repo on the node
ssh node-1
git clone <pi-fleet-repo-url>
cd pi-fleet/scripts/storage
chmod +x *.sh
```

## Step 5: Run Migration

```bash
# SSH to node
ssh node-1

# Run migration script
sudo ./migrate-nvme-hat.sh node-1
```

The script will:

1. Detect new 128GB NVMe
2. Create partitions (512MB boot + root)
3. Clone OS from SD card to new NVMe
4. Update boot configuration
5. Configure boot from NVMe

## Step 6: Reboot and Verify

```bash
# Reboot
sudo reboot

# After reboot, verify
ssh node-1
df -h /  # Should show /dev/nvme0n1p2
./verify-nvme-migration.sh node-1
```

## Step 7: Install K3s (if needed)

After migration, if you need to set up K3s:

```bash
# For control plane (node-1)
curl -sfL https://get.k3s.io | sh -

# For worker (node-1)
# Get token from node-1:
ssh node-1 "sudo cat /var/lib/rancher/k3s/server/node-token"

# On node-1:
curl -sfL https://get.k3s.io | K3S_URL=https://node-1.eldertree.local:6443 K3S_TOKEN=<token> sh -
```

## Troubleshooting

### SD Card Not Booting

- Verify image was written correctly
- Check SD card is properly inserted
- Try a different SD card
- Check boot configuration in `/boot/firmware/config.txt`

### New NVMe Not Detected

- Verify HAT is properly connected
- Check NVMe is properly seated
- Power cycle the Pi
- Check: `lsblk | grep nvme`

### Migration Fails

- Ensure you're booting from SD card (not NVMe)
- Check SD card has enough space
- Verify new NVMe is ~128GB
- Check logs: `/tmp/migration-*.log`

## Next Steps After Migration

1. ✅ Verify boot from new NVMe
2. ✅ Install K3s (if needed)
3. ✅ Restore any backups (if you have them)
4. ✅ Configure cluster
5. ✅ Deploy workloads








