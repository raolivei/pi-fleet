<!-- MIGRATED TO RUNBOOK -->
> **📚 This document has been migrated to the Eldertree Runbook**
>
> For the latest version, see: [SSH-003](https://docs.eldertree.xyz/runbook/issues/ssh/SSH-003)
>
> The runbook provides searchable troubleshooting guides with improved formatting.

---


# Recover Locked Root Account on node-0

## Problem

After reboot, node-0 shows:
```
cannot open access to console, the root account is locked, see sulogin(8) man page for more details
```

## Prerequisites

- ✅ `PI_PASSWORD` environment variable set: `export PI_PASSWORD='your_password'`

## Solution: Boot from SD Card

The easiest recovery method is to boot from the SD card (which should still have the working OS).

### Step 1: Remove NVMe Temporarily

1. **Power off node-0**
2. **Remove NVMe drive** (to force SD card boot)
3. **Power on node-0**
4. **Wait for boot** (2-3 minutes)

### Step 2: SSH and Fix Root Account

Once node-0 boots from SD card:

```bash
# SSH to node-0 using PI_PASSWORD
sshpass -p "$PI_PASSWORD" ssh raolivei@192.168.2.86

# Unlock root account
sudo passwd -u root

# Set root password using PI_PASSWORD
echo "root:$PI_PASSWORD" | sudo chpasswd

# Verify root is unlocked
sudo passwd -S root
# Should show "P" (password set) not "L" (locked)
```

### Step 3: Reinstall NVMe and Continue

1. **Power off node-0**
2. **Reinstall NVMe drive**
3. **Power on node-0**
4. **Continue with NVMe boot setup**

## Alternative: Physical Console Access

If you have physical access (keyboard/monitor):

1. **Boot to recovery mode** (hold Shift during boot, or select from GRUB menu)
2. **Access root shell**
3. **Unlock root account**:
   ```bash
   passwd -u root
   passwd root  # Set password to your secure password
   ```
4. **Reboot normally**

## Why This Happens

**This issue occurs every time you switch boot devices** (SD card ↔ NVMe). The root account gets locked due to:

- **System security policies** that detect boot device changes
- **PAM (Pluggable Authentication Modules)** security policies
- **Systemd security policies** that lock root on device changes
- **Boot device detection** triggering security measures

This is a known issue when switching between SD card and NVMe boot on Raspberry Pi 5.

## Prevention

### Automated Fix (Recommended)

After switching boot devices, run the Ansible playbook (requires `PI_PASSWORD` environment variable):

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook -i inventory/hosts.yml playbooks/fix-root-lock.yml --limit node-0
```

This will automatically:
- Unlock root account
- Set root password
- Reset any lockout counters

### Manual Fix

After recovery, ensure root account stays unlocked:

```bash
# Check root account status
sudo passwd -S root

# If locked, unlock it
sudo passwd -u root

# Set a password (if needed)
sudo passwd root

# Reset faillock (if applicable)
sudo faillock --user root --reset
```

### Permanent Solution

The `setup-system.yml` playbook has been updated to prevent root lock on boot device changes. Run it after switching boot devices:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml --limit node-0
```

## Next Steps

After recovering:
1. ✅ Verify SSH access works
2. ✅ Continue with NVMe boot setup
3. ✅ Complete node-0 configuration
