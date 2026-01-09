# Recovery via SD Card Backup

## Situation

All nodes are stuck during boot. We'll recover using SD card backup, one node at a time.

**Important**: 
- The SD card has generic hostname `node-x`. We'll identify nodes by their IP address.
- **⚠️ CRITICAL**: The recovery process fixes the **NVMe drive**, not the SD card!
  - SD card is used to boot the node temporarily
  - All fixes are applied to NVMe partitions (`/mnt/nvme-root` and `/mnt/nvme-boot`)
  - After fixes, you remove SD card and boot from NVMe

## Recovery Process (one node at a time)

### Step 1: Prepare SD Card Backup

1. **Insert the SD card backup** into the node you're recovering first (start with node-1)
2. **Remove the NVMe** temporarily (to avoid conflicts)
3. **Power on the node** - it should boot from SD card with hostname `node-x`

### Step 2: Verify Node Booted

```bash
# Wait 1-2 minutes for the node to boot completely
# Then verify by IP (since hostname is generic):
ping -c 1 192.168.2.101  # node-1
# or
ping -c 1 192.168.2.102  # node-2
# or
ping -c 1 192.168.2.103  # node-3
```

### Step 3: Apply Boot Fixes to NVMe (by IP)

**⚠️ IMPORTANT: The fixes are applied to the NVMe drive, NOT the SD card!**

Since the SD card has generic hostname `node-x`, use the IP-based recovery script:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# For node-1 (192.168.2.101):
./scripts/recover-node-by-ip.sh 192.168.2.101

# For node-2 (192.168.2.102):
./scripts/recover-node-by-ip.sh 192.168.2.102

# For node-3 (192.168.2.103):
./scripts/recover-node-by-ip.sh 192.168.2.103
```

**What the script does:**
- Identifies which node it is based on IP
- **Mounts NVMe partitions** (`/mnt/nvme-root` and `/mnt/nvme-boot`)
- **Applies all boot reliability fixes to NVMe** (not SD card):
  - Removes unused backup mount from NVMe fstab
  - Adds nofail to optional mounts in NVMe fstab
  - Disables PAM faillock on NVMe
  - Unlocks root account on NVMe
  - Fixes NVMe cmdline.txt
- Verifies the fixes were applied to NVMe

**Why NVMe and not SD card?**
- The SD card is already fixed (it's what you're booting from)
- The goal is to fix the NVMe so the node can boot from it again
- After fixes, you'll remove the SD card and boot from NVMe

### Step 4: Verify Fixes on NVMe

```bash
# SSH to the node by IP
ssh raolivei@192.168.2.101  # node-1

# Check NVMe fstab has nofail (not SD card fstab!)
sudo grep nofail /mnt/nvme-root/etc/fstab

# Check backup mount is removed from NVMe
sudo grep '/dev/sdb1' /mnt/nvme-root/etc/fstab || echo "✅ Backup mount removed"

# Check root is unlocked on NVMe
sudo chroot /mnt/nvme-root passwd -S root

# Check NVMe cmdline.txt
sudo cat /mnt/nvme-boot/cmdline.txt
```

**Remember:** You're checking `/mnt/nvme-root/etc/fstab`, not `/etc/fstab` (which is the SD card).

### Step 5: Configure Hostname (Optional)

After recovery, you may want to set the correct hostname:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible

# For node-1:
ansible-playbook playbooks/setup-system.yml --limit node-1 -e hostname=node-1.eldertree.local

# For node-2:
ansible-playbook playbooks/setup-system.yml --limit node-2 -e hostname=node-2.eldertree.local

# For node-3:
ansible-playbook playbooks/setup-system.yml --limit node-3 -e hostname=node-3.eldertree.local
```

### Step 6: Test Reboot from NVMe

**⚠️ IMPORTANT: Before rebooting, remove the SD card!**

```bash
# 1. Unmount NVMe (optional, can leave mounted)
ssh raolivei@192.168.2.101 "sudo umount /mnt/nvme-root /mnt/nvme-boot"  # node-1

# 2. Remove SD card from the node (physically)

# 3. Ensure NVMe is connected

# 4. Reboot the node
ssh raolivei@192.168.2.101 "sudo reboot"  # node-1

# 5. Wait 2 minutes, then verify it booted from NVMe
ping -c 1 192.168.2.101
ssh raolivei@192.168.2.101 "hostname"  # Should be node-1.eldertree.local (not node-x)
ssh raolivei@192.168.2.101 "df -h / | grep nvme"  # Should show NVMe as root
```

**If it boots successfully from NVMe:**
- ✅ Node is recovered!
- The fixes worked
- You can proceed to the next node

**If it doesn't boot:**
- Check boot order (NVMe should be first)
- Verify NVMe is connected
- Check boot logs: `journalctl -b` (if you can access console)

### Step 7: Repeat for Next Node

1. **Power off current node**
2. **Remove SD card** and insert into next node
3. **Repeat steps 1-6** for node-1, then node-2

## Recommended Recovery Order

1. **node-1 first** (192.168.2.101) - Control plane, most critical
2. **node-2 next** (192.168.2.102) - Worker
3. **node-3 last** (192.168.2.103) - Worker

## Node IP Mapping

| Node   | IP Address (wlan0) | IP Address (eth0) | Role          |
|--------|-------------------|-------------------|---------------|
| node-1 | 192.168.2.101     | 10.0.0.1          | Control plane |
| node-2 | 192.168.2.102     | 10.0.0.2          | Worker        |
| node-3 | 192.168.2.103     | 10.0.0.3          | Worker        |

## Recovery Checklist per Node

For each node:

- [ ] SD card inserted, NVMe **connected** (but node booting from SD)
- [ ] Node booted from SD card (hostname will be `node-x`)
- [ ] Node accessible by IP (ping works)
- [ ] SSH working
- [ ] **NVMe partitions mounted** (`/mnt/nvme-root` and `/mnt/nvme-boot`)
- [ ] Boot reliability fix applied to **NVMe** using IP (not SD card!)
- [ ] **NVMe fstab verified** (has nofail, backup mount removed)
- [ ] Root unlocked on **NVMe**
- [ ] **NVMe cmdline.txt verified**
- [ ] SD card removed
- [ ] Node rebooted and booted correctly **from NVMe**
- [ ] Hostname configured (optional)

## Quick Commands

### Check if node is accessible by IP

```bash
ping -c 1 192.168.2.101  # node-1
ping -c 1 192.168.2.102  # node-2
ping -c 1 192.168.2.103  # node-3
```

### Apply fix to NVMe for specific node by IP

**⚠️ Remember: This fixes the NVMe drive, not the SD card!**

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
./scripts/recover-node-by-ip.sh 192.168.2.101  # node-1
```

The script will:
- Mount NVMe partitions (`/mnt/nvme-root` and `/mnt/nvme-boot`)
- Apply fixes to NVMe fstab, PAM, root account, and cmdline.txt
- Verify all fixes were applied to NVMe

### Check cluster (when node-1 comes back)

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
kubectl get pods -A
```

## Common Problems

### Node doesn't boot from SD card

- Verify SD card is formatted correctly
- Try another SD card
- Verify boot order is correct (SD before NVMe)

### Can't identify which node it is

- Use the IP address to identify:
  - 192.168.2.101 = node-1
  - 192.168.2.102 = node-2
  - 192.168.2.103 = node-3
- The recovery script identifies automatically by IP

### Fix doesn't work

- Check logs: `ssh raolivei@<IP> 'sudo journalctl -b'`
- Check fstab manually: `ssh raolivei@<IP> 'cat /etc/fstab'`
- Try applying fix manually (see section below)

## Manual Fix (if script doesn't work)

If the script doesn't work, do it manually on the node. **Remember: fix NVMe, not SD card!**

```bash
# SSH to node by IP (node is booted from SD card)
ssh raolivei@192.168.2.101  # node-1

# 1. Mount NVMe partitions
sudo mkdir -p /mnt/nvme-root /mnt/nvme-boot
sudo mount /dev/nvme0n1p2 /mnt/nvme-root
sudo mount /dev/nvme0n1p1 /mnt/nvme-boot

# 2. Fix NVMe fstab (NOT /etc/fstab which is SD card!)
sudo cp /mnt/nvme-root/etc/fstab /mnt/nvme-root/etc/fstab.bak
# Remove backup mount
sudo sed -i '/\/dev\/sdb1.*\/mnt\/backup/d' /mnt/nvme-root/etc/fstab
# Add nofail to optional mounts
sudo sed -i 's|\(/dev/nvme[^\s]*\s\+[^\s]*\s\+ext4\s\+defaults\)\([^,]*\)|\1,nofail\2|g' /mnt/nvme-root/etc/fstab
sudo sed -i 's|\(/dev/nvme[^\s]*\s\+[^\s]*\s\+vfat\s\+defaults\)\([^,]*\)|\1,nofail\2|g' /mnt/nvme-root/etc/fstab

# 3. Verify NVMe fstab
sudo chroot /mnt/nvme-root mount -a --fake

# 4. Disable PAM faillock on NVMe
sudo sed -i 's/^auth.*pam_faillock/# &/' /mnt/nvme-root/etc/pam.d/common-auth

# 5. Unlock root on NVMe
sudo chroot /mnt/nvme-root passwd -u root
sudo chroot /mnt/nvme-root faillock --user root --reset

# 6. Fix NVMe cmdline.txt
sudo cp /mnt/nvme-boot/cmdline.txt /mnt/nvme-boot/cmdline.txt.bak
sudo sed -i 's|root=[^ ]*|root=/dev/nvme0n1p2|g' /mnt/nvme-boot/cmdline.txt

# 7. Remove SD card, then reboot
sudo reboot
```

## After Complete Recovery

When all 3 nodes are recovered:

1. **Verify cluster**:
   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   kubectl get nodes
   ```

2. **Apply preventive fixes**:
   ```bash
   cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible
   ansible-playbook playbooks/fix-boot-reliability.yml
   ```

3. **Test reboot** (one node at a time):
   ```bash
   ssh raolivei@192.168.2.101 "sudo reboot"  # node-1
   # Wait 2 minutes
   ping -c 1 192.168.2.101
   ```

## Future Prevention

To avoid this again:

1. **Always use `nofail`** on optional mounts
2. **Run `fix-boot-reliability.yml`** after any fstab changes
3. **Test reboots** after important changes
4. **Keep SD card backups** updated
