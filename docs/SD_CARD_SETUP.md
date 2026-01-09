# SD Card Recovery OS Setup

## Purpose

The SD card serves as a recovery boot option when NVMe boot fails. It should be:
- **Minimal** - Just enough to boot and recover
- **Generic** - Works for any node (hostname: `node-x`)
- **Secure** - Different password to avoid running commands on wrong OS
- **Pre-configured** - Boot reliability fixes already applied

## Step 1: Create SD Card with Raspberry Pi Imager

### Settings

1. **OS**: Debian 12 Bookworm (64-bit)
2. **Hostname**: `node-x` (generic, works for any node)
3. **User**: `raolivei`
4. **Password**: `Control01!` (different from main password to avoid mistakes)
5. **SSH**: Enable (password authentication enabled)
6. **WiFi**: Configure with your network (or use ethernet)

### Why Different Password?

The password `Control01!` is intentionally different from the main cluster password to:
- **Prevent mistakes** - You'll notice if you're on the wrong OS
- **Safety** - Won't accidentally run commands on production nodes
- **Recovery context** - Clear indication you're in recovery mode

## Step 2: Boot from SD Card

1. **Insert SD card** into any node (e.g., node-2)
2. **Remove NVMe** temporarily (to ensure boot from SD)
3. **Power on** - Wait 1-2 minutes for boot
4. **Verify** - Check IP address:
   ```bash
   ping -c 1 192.168.2.84  # node-2
   # or
   ping -c 1 192.168.2.85  # node-1
   # or
   ping -c 1 192.168.2.86  # node-0
   ```

## Step 3: Apply Boot Reliability Fixes

Once the SD card OS is booted, apply all boot reliability fixes:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# Identify which node it is by IP and apply fixes
./scripts/recover-node-by-ip.sh 192.168.2.84  # node-2 example
```

Or use Ansible directly:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible

# Apply fixes (will identify node by IP)
ansible-playbook playbooks/fix-boot-reliability.yml \
  --limit node-2 \
  -e ansible_user=raolivei \
  -e ansible_password=Control01!
```

## Step 4: Verify SD Card OS

```bash
# SSH to node
ssh raolivei@192.168.2.84  # Use appropriate IP

# Check fixes applied
sudo grep nofail /etc/fstab
sudo passwd -S root  # Should show unlocked
cat /etc/hostname     # Should be "node-x"
```

## Step 5: Test Reboot

```bash
# Reboot from SD card
ssh raolivei@192.168.2.84 "sudo reboot"

# Wait 2 minutes, then verify
ping -c 1 192.168.2.84
ssh raolivei@192.168.2.84 "hostname"  # Should be "node-x"
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
   # On the node booted from SD card
   sudo mkdir -p /mnt/nvme-root
   sudo mount /dev/nvme0n1p2 /mnt/nvme-root
   
   # Apply fixes to NVMe
   cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible
   ansible-playbook playbooks/fix-boot-reliability.yml \
     --limit <node-ip> \
     -e fix_nvme=true
   ```
7. **Reboot** - Remove SD card, reinsert NVMe, boot from NVMe

## Alternative: Fix SD Card While Mounted

If you prefer to fix the SD card while it's mounted on node-2 (without booting from it):

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
./scripts/fix-sd-card-on-node2.sh
```

This script:
- Detects the SD card device
- Mounts it
- Applies all boot reliability fixes
- Unmounts safely

## SD Card Requirements

- **Size**: At least 16GB (32GB recommended)
- **Speed**: Class 10 or better
- **Format**: Will be formatted by Raspberry Pi Imager
- **OS**: Debian 12 Bookworm (64-bit)

## Maintenance

The SD card OS should be:
- **Updated periodically** - Re-image with latest Debian
- **Tested** - Boot from it occasionally to verify it works
- **Backed up** - Keep a copy of the configured SD card image

## Troubleshooting

### SD Card Won't Boot

- Verify SD card is properly inserted
- Check boot order (SD before NVMe)
- Try another SD card
- Verify image was written correctly

### Can't SSH to SD Card OS

- Check IP address (may be different from NVMe)
- Verify SSH is enabled in Raspberry Pi Imager
- Check password: `Control01!`
- Verify network connection

### Fixes Don't Apply

- Check Ansible can connect: `ansible node-2 -m ping`
- Verify password: `Control01!`
- Check SSH access: `ssh raolivei@<IP>`
- Review playbook output for errors


