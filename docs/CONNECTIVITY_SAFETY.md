# Connectivity Safety Measures

This document describes all safety measures implemented in Ansible playbooks to prevent connectivity loss to nodes.

## Overview

**CRITICAL PRINCIPLE**: No playbook will break connectivity to nodes. All network, hostname, firewall, and system changes include comprehensive safety checks.

## Safety Measures by Category

### 1. Network Configuration (`setup-system.yml`)

#### Pre-Flight Checks
- ✅ **Gateway Reachability**: Tests gateway connectivity before making any network changes
- ✅ **Current IP Connectivity**: Verifies current IP is reachable before changes
- ✅ **Network Mode Detection**: Only modifies DHCP configurations (never changes existing static configs)
- ✅ **Skip Logic**: Automatically skips network changes if:
  - Gateway is unreachable
  - Current IP is unreachable
  - Already configured with target IP
  - Already using static IP (preserves working configs)

#### Validation
- ✅ **Configuration Validation**: Runs `netplan generate` (dry-run) before applying
- ✅ **Syntax Checking**: Fails immediately if configuration is invalid
- ✅ **Backup Creation**: Automatically backs up Netplan configs before changes

#### Post-Change Verification
- ✅ **IP Verification**: Confirms new IP matches target IP
- ✅ **Connectivity Testing**: Tests gateway and DNS connectivity after changes
- ✅ **Automatic Failure**: Fails playbook if connectivity is lost, with rollback instructions

#### Rollback
- ✅ **Backup Location**: All backups stored in `/root/netplan-backups/`
- ✅ **Failure Messages**: Include exact backup file path for manual restoration

### 2. Firewall Configuration (`setup-system.yml`)

#### SSH Protection
- ✅ **SSH Always Allowed**: Ensures SSH is allowed BEFORE any firewall changes
- ✅ **Pre-Change Verification**: Checks if SSH is already allowed
- ✅ **Post-Change Verification**: Verifies SSH rule is active after changes
- ✅ **Automatic Failure**: Fails playbook if SSH is not allowed

#### Safe Defaults
- ✅ **UFW Reset Disabled**: UFW reset is disabled by default (can break connectivity)
- ✅ **UFW Enable Optional**: UFW enable is optional and disabled by default

### 3. Hostname Configuration (`setup-system.yml`)

#### Validation
- ✅ **FQDN Enforcement**: Validates hostname is in FQDN format (node-X.eldertree.local)
- ✅ **Prevents "eldertree"**: Explicitly prevents setting hostname to just "eldertree"
- ✅ **Idempotent Changes**: Only changes hostname if different from current

#### Safety
- ✅ **No SSH Impact**: Hostname changes don't affect SSH connectivity
- ✅ **Preserves /etc/hosts**: Updates /etc/hosts to maintain local resolution

### 4. Reboot Operations (`install-k3s.yml`, `install-k3s-worker.yml`)

#### Pre-Reboot
- ✅ **Only When Necessary**: Reboots only when cgroup configuration changes
- ✅ **Safe cmdline.txt**: Uses safe shell-based approach (never uses `lineinfile`)

#### Post-Reboot
- ✅ **Connection Wait**: Waits up to 300 seconds for node to come back online
- ✅ **Connectivity Verification**: Tests SSH and network connectivity after reboot
- ✅ **Automatic Failure**: Fails if connectivity is lost after reboot

### 5. cmdline.txt Modifications (`install-k3s.yml`, `install-k3s-worker.yml`)

#### Safety Measures
- ✅ **Source of Truth**: Uses `/proc/cmdline` (kernel) as source of truth
- ✅ **Backup Creation**: Backs up cmdline.txt before any changes
- ✅ **root= Protection**: Validates `root=` parameter exists before and after changes
- ✅ **Automatic Rollback**: Restores from backup if `root=` parameter is lost
- ✅ **No lineinfile**: Uses safe shell-based approach instead of `lineinfile` module

## Safety Checklist

Before any playbook makes a change that could affect connectivity:

- [ ] Pre-flight checks (gateway, current IP, network mode)
- [ ] Configuration validation (dry-run, syntax check)
- [ ] Backup creation
- [ ] Safe application (only when conditions are met)
- [ ] Post-change verification (IP, connectivity)
- [ ] Automatic failure with rollback instructions

## What Will NEVER Happen

1. ❌ **Network changes when gateway is unreachable**
2. ❌ **Modification of existing static network configurations**
3. ❌ **Firewall changes that block SSH**
4. ❌ **Hostname changes that break SSH**
5. ❌ **cmdline.txt modifications that remove `root=` parameter**
6. ❌ **Network changes without validation**
7. ❌ **Network changes without connectivity verification**

## Recovery Procedures

If connectivity is lost despite safety measures:

### Network Issues
1. Check backup location: `/root/netplan-backups/`
2. Restore from backup:
   ```bash
   sudo tar -xzf /root/netplan-backups/netplan-backup-*.tar.gz -C /
   sudo netplan apply
   ```
3. Or manually edit `/etc/netplan/01-eth0-static.yaml`
4. See [FIX_NODES_AFTER_NETPLAN.md](./FIX_NODES_AFTER_NETPLAN.md) for detailed steps

### SSH Issues
1. Check firewall: `sudo ufw status`
2. Ensure SSH is allowed: `sudo ufw allow OpenSSH`
3. Check SSH service: `sudo systemctl status ssh`

### Boot Issues
1. Boot from SD card (recovery SD)
2. Mount NVMe drive
3. Fix `/boot/firmware/cmdline.txt` (ensure `root=` parameter exists)
4. Reboot from NVMe

## Testing

All safety measures are tested in the following scenarios:

1. ✅ Fresh SD card boot (node-x hostname)
2. ✅ DHCP to Static IP transition
3. ✅ Existing static IP (should not be modified)
4. ✅ Gateway unreachable (should skip)
5. ✅ Current IP unreachable (should skip)
6. ✅ Firewall configuration (SSH always allowed)
7. ✅ Reboot operations (connectivity verified)
8. ✅ cmdline.txt modifications (root= protected)

## Best Practices

1. **Always run playbooks with `--check` first** (when possible)
2. **Monitor playbook output** for safety warnings
3. **Keep backups** of working configurations
4. **Test in non-production first** (if possible)
5. **Have physical access** to nodes for recovery

## Summary

All playbooks are designed with **defense in depth**:
- Multiple layers of safety checks
- Automatic validation and verification
- Clear failure messages with recovery instructions
- Never modify working configurations
- Always preserve connectivity

**Result**: Playbooks can be run safely, repeatedly, and will never break connectivity to nodes.


