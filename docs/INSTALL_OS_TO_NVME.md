# Install OS to NVMe on New Raspberry Pi 5

Complete guide for installing the operating system directly to NVMe on a fresh Raspberry Pi 5.

## Prerequisites

- ✅ Raspberry Pi 5
- ✅ 256GB NVMe drive installed via M.2 adapter
- ✅ SD card with OS (for cloning method) OR Raspberry Pi Imager (for fresh install)
- ✅ SSH access to the Pi

## Current Setup

- **New Pi IP**: 192.168.2.85
- **NVMe**: 256GB attached
- **Goal**: Boot from NVMe instead of SD card

## Method 1: Clone Existing OS (Recommended) - Using Ansible

If the Pi already has an OS installed on the SD card, use the Ansible playbook:

### Step 1: From Your Mac

```bash
cd ~/WORKSPACE/raolivei/pi-fleet

# Run the Ansible playbook
cd ansible
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

1. ✅ Check prerequisites (Pi 5, NVMe detected)
2. ✅ Stop services (k3s, etc.)
3. ✅ Create partitions on NVMe (boot + root)
4. ✅ Clone OS from SD card to NVMe
5. ✅ Resize filesystem to match partition
6. ✅ Update boot configuration (fstab, cmdline.txt)

### Step 3: Reboot

```bash
sudo reboot
```

After reboot, the Pi 5 will automatically boot from NVMe.

## Method 2: Fresh Install Using Raspberry Pi Imager

If you want a fresh OS install directly to NVMe:

### Step 1: Prepare NVMe on Pi

SSH to the Pi and prepare partitions:

```bash
ssh pi@192.168.2.85

# Run script and choose option 2
~/install-os-to-nvme.sh
# Choose option 2 when prompted
```

This creates the partition structure on NVMe.

### Step 2: Flash OS Using Raspberry Pi Imager

1. **Remove NVMe from Pi** and connect to your Mac via USB adapter
2. **Open Raspberry Pi Imager** on your Mac
3. **Choose OS**: Debian Bookworm (64-bit) or Raspberry Pi OS (64-bit)
4. **Choose Storage**: Select the NVMe drive
5. **Configure** (gear icon):
   - ✅ Enable SSH
   - Set username: `pi` or `raolivei`
   - Set password
   - Configure WiFi (optional)
6. **Write** to NVMe

### Step 3: Reconnect and Boot

1. **Reconnect NVMe** to Pi
2. **Remove SD card** (optional, or keep as backup)
3. **Power on Pi** - it will boot from NVMe automatically

## Verification

After booting from NVMe, verify:

```bash
# Check root filesystem
df -h /
# Should show /dev/nvme0n1p2

# Check boot partition
mount | grep "/boot/firmware"
# Should show /dev/nvme0n1p1

# Check device
lsblk
# Root (/) should be on nvme0n1p2
```

## Quick Setup (Ansible)

The quickest way is using Ansible from your Mac:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook playbooks/setup-nvme-boot.yml \
  -e setup_nvme_boot=true \
  -e clone_from_sd=true \
  --ask-become-pass
```

This handles everything automatically and is idempotent (safe to run multiple times).

## Troubleshooting

### Pi won't boot from NVMe

1. **Check NVMe is detected**:

   ```bash
   lsblk | grep nvme
   ```

2. **Verify partitions**:

   ```bash
   sudo fdisk -l /dev/nvme0n1
   ```

3. **Check boot files**:

   ```bash
   sudo mount /dev/nvme0n1p1 /mnt
   ls /mnt
   sudo umount /mnt
   ```

4. **Boot from SD card** and check logs:
   ```bash
   sudo journalctl -b -1
   ```

### SSH Connection Issues

If you can't SSH:

- Check Pi is on network: `ping 192.168.2.85`
- Try default password: `raspberry`
- Check if SSH is enabled (may need to enable via console)

### Script Not Found

If you don't have the script, you can create it manually or use the manual steps from the existing `NVME_BOOT_SETUP.md` guide.

## Next Steps

After successfully booting from NVMe:

1. ✅ Verify boot source
2. ✅ Set up system (hostname, user, network)
3. ✅ Install k3s (if setting up as cluster node)
4. ✅ Configure as worker node (if adding to eldertree cluster)

## Notes

- **Raspberry Pi 5** automatically tries NVMe first if present
- **SD card** remains as backup boot option
- **Performance**: Boot from NVMe is 2-3x faster than SD card
- **Durability**: NVMe SSDs are more reliable than SD cards
