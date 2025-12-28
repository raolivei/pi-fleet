# Emergency Mode Recovery - Root Locked

## Problem

System boots into emergency mode with message:
```
cannot open access to console, the root account is locked, see sulogin(8) man page for more details
```

This happens even when booting from SD card only (not just when switching boot devices).

## Root Cause

Emergency mode is triggered by:
1. **Failed mount in `/etc/fstab`** - A device that's supposed to mount doesn't exist or fails
2. **Root account is locked** - Prevents console access in emergency mode

Common causes:
- Backup drive (`/dev/sdb1`) not connected but in fstab without `nofail`
- NVMe mount entries in fstab when NVMe isn't present
- Filesystem check failures
- Network mount timeouts

## Solution: Boot to Recovery/Initramfs

Since you can't access the console (root locked), you need to access the system before it fully boots.

### Option 1: Initramfs Shell (Recommended)

1. **Interrupt boot process** - Hold `Shift` or press `Esc` during boot (before systemd starts)
2. **Access initramfs shell** - You should see a prompt or can press `Ctrl+Alt+F2` for console
3. **Remount root filesystem as read-write**:
   ```bash
   mount -o remount,rw /
   ```
4. **Unlock root account**:
   ```bash
   passwd -u root
   # Use a secure password (refer to your PI_PASSWORD environment variable)
   echo "root:your_secure_password" | chpasswd
   ```
5. **Fix fstab** - Remove or comment out problematic mount entries:
   ```bash
   nano /etc/fstab
   # Comment out lines for devices that don't exist:
   # /dev/sdb1 /mnt/backup ext4 defaults 0 2
   # /dev/nvme0n1p1 /mnt/nvme ext4 defaults 0 2
   ```
6. **Reboot**:
   ```bash
   reboot
   ```

### Option 2: Recovery Mode (If Available)

1. **Boot to GRUB menu** - Hold `Shift` during boot
2. **Select recovery mode** or **Advanced options**
3. **Select root shell** or **Drop to root shell**
4. **Follow steps 3-6 from Option 1**

### Option 3: Boot from Different Media

If you have another SD card with a working OS:
1. Boot from working SD card
2. Mount the problematic SD card's root partition
3. Fix fstab and unlock root on the mounted filesystem

## Quick Fix Script (If You Can Access)

Once you can access the system (via initramfs or recovery):

```bash
# Unlock root
passwd -u root
# Use your secure password
echo "root:$PI_PASSWORD" | chpasswd

# Check fstab for problematic mounts
cat /etc/fstab

# Add nofail to backup/NVMe mounts
sed -i 's|/dev/sdb1.*defaults|/dev/sdb1 /mnt/backup ext4 defaults,nofail|g' /etc/fstab
sed -i 's|/dev/nvme.*defaults|/dev/nvme0n1p1 /mnt/nvme ext4 defaults,nofail|g' /etc/fstab

# Or comment out if device doesn't exist
# sed -i 's|^/dev/sdb1|#/dev/sdb1|g' /etc/fstab

# Reboot
reboot
```

## Prevention

### 1. Always Use `nofail` for Optional Mounts

In `/etc/fstab`, optional mounts (backup drives, NVMe storage) should have `nofail`:

```
/dev/sdb1 /mnt/backup ext4 defaults,nofail 0 2
/dev/nvme0n1p1 /mnt/nvme ext4 defaults,nofail 0 2
```

The `nofail` option tells systemd to continue booting even if the mount fails.

### 2. Use Ansible Playbook

The `setup-system.yml` playbook automatically adds `nofail` to backup mounts:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml --limit node-0
```

### 3. Unlock Root After Setup

Run the root unlock playbook after any system changes (requires `PI_PASSWORD` environment variable):

```bash
ansible-playbook -i inventory/hosts.yml playbooks/fix-root-lock.yml --limit node-0
```

## Common fstab Issues

### Backup Drive Not Connected

**Problem**: `/dev/sdb1` in fstab but USB drive not plugged in

**Fix**: Add `nofail`:
```
/dev/sdb1 /mnt/backup ext4 defaults,nofail 0 2
```

### NVMe Mount When NVMe Not Present

**Problem**: NVMe mount in fstab but NVMe removed or not booted from

**Fix**: Add `nofail` or comment out:
```
# /dev/nvme0n1p1 /mnt/nvme ext4 defaults,nofail 0 2
```

### Network Mount Timeout

**Problem**: NFS/CIFS mount times out

**Fix**: Add `nofail,_netdev`:
```
server:/share /mnt/share nfs defaults,nofail,_netdev 0 0
```

## Verification

After fixing, verify system boots normally:

```bash
# Check system status
systemctl is-system-running
# Should show: running or degraded (not emergency)

# Check mount status
systemctl status mnt-backup.mount
systemctl status mnt-nvme.mount
# Should show: inactive (if device not present) or active (if mounted)

# Check root account
passwd -S root
# Should show: P (password set) not L (locked)
```

## Next Steps

After recovering:
1. ✅ Fix fstab (add `nofail` to optional mounts)
2. ✅ Unlock root account
3. ✅ Run `setup-system.yml` to prevent future issues
4. ✅ Verify system boots normally
