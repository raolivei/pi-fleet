# Boot Reliability Fix

## Problem

Systems were failing to boot after reboot, getting stuck during the init process. This is typically caused by:

1. **fstab mounts without `nofail`** - System waits indefinitely for optional mounts that aren't available
2. **Systemd mount timeouts** - Default timeouts too short for slow devices
3. **Root account locks** - PAM faillock locking root account after failed boots
4. **Incorrect PARTUUIDs** - fstab references wrong partition UUIDs after device changes

## Solution

The `fix-boot-reliability.yml` playbook fixes all these issues:

### What it does:

1. **Unlocks root account** - Prevents console lockouts
2. **Adds `nofail` to optional mounts** - Boot doesn't hang waiting for unavailable devices
3. **Configures systemd timeouts** - 300s timeout for mount operations
4. **Disables PAM faillock** - Prevents account lockouts during boot
5. **Verifies PARTUUIDs** - Ensures fstab references correct partitions
6. **Tests fstab syntax** - Validates mount configuration

## Usage

### Fix all nodes:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook playbooks/fix-boot-reliability.yml
```

### Fix specific node:

```bash
ansible-playbook playbooks/fix-boot-reliability.yml --limit node-0
```

### After fixing:

```bash
# Reboot the node
ansible-playbook playbooks/fix-boot-reliability.yml --limit node-0 -e "reboot=true"
# Or manually:
ssh raolivei@node-0 "sudo reboot"
```

## When to use

- **After any reboot failure** - If a node doesn't boot properly
- **Before maintenance** - Ensure nodes will boot after power cycle
- **After NVMe migration** - Fix any mount issues from device changes
- **Preventive maintenance** - Run periodically to ensure reliability

## Verification

After applying fixes and rebooting:

```bash
# Check node is online
ansible raspberry_pi -i inventory/hosts.yml -m ping

# Check fstab has nofail on optional mounts
ansible raspberry_pi -i inventory/hosts.yml -m shell -a "grep nofail /etc/fstab" --become

# Check root account is unlocked
ansible raspberry_pi -i inventory/hosts.yml -m shell -a "passwd -S root" --become
```

## Integration

This fix is automatically applied in:
- `setup-new-node.yml` - New nodes get boot reliability fixes
- `setup-nvme-boot.yml` - NVMe boot setup includes these fixes

## Troubleshooting

If a node still doesn't boot after applying fixes:

1. **Check boot logs** (if you can access console):
   ```bash
   journalctl -b
   systemctl status
   ```

2. **Check fstab manually**:
   ```bash
   cat /etc/fstab
   # Verify optional mounts have nofail
   ```

3. **Check for failed mounts**:
   ```bash
   systemctl list-units --type=mount --failed
   ```

4. **Boot from SD card** (if NVMe boot fails):
   - Remove NVMe drive
   - Boot from SD card
   - Run fix-boot-reliability.yml
   - Reinstall NVMe and retry

## Prevention

To prevent this issue in the future:

1. **Always use `nofail`** on optional mounts in fstab
2. **Never remove `nofail`** from backup/storage mounts
3. **Test reboots** after any fstab changes
4. **Run fix-boot-reliability.yml** after major system changes

