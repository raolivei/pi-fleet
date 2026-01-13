<!-- MIGRATED TO RUNBOOK -->

> **📚 This document has been migrated to the Eldertree Runbook**
>
> For the latest version, see: [NET-004](https://docs.eldertree.xyz/runbook/issues/network/NET-004)
>
> The runbook provides searchable troubleshooting guides with improved formatting.

---

# Preventing Network Configuration Issues

## Overview

This document explains how to prevent the network issues that affected node-1 (dual IP, DHCP conflicts, connectivity problems) from happening again on any node.

## Problem Summary

**What happened on node-1:**

- Dual IP configuration: Both static IP (192.168.2.101) and DHCP IP (192.168.2.86) on wlan0
- Root cause: netplan had `dhcp4: true` while also configuring a static IP
- Result: Network instability, SSH failures, API server connectivity issues

**Why it happened:**

- Conflicting configuration between netplan and NetworkManager
- DHCP enabled when static IP was configured
- No validation before/after network changes

## Prevention Strategy

### 1. Validation Script

**Run before making network changes:**

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
./scripts/validate-network-config.sh
```

**Run after making network changes:**

```bash
./scripts/validate-network-config.sh
```

**What it checks:**

- ✅ Single IP on wlan0 (excluding kube-vip VIP)
- ✅ DHCP disabled in netplan
- ✅ NetworkManager configured correctly
- ✅ No duplicate routes
- ✅ Interface is UP

### 2. Automated Fix Playbook

If validation finds issues, fix them automatically:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/fix-network-config.yml
```

**What it fixes:**

- Removes extra IPs from wlan0
- Disables DHCP in netplan files
- Configures NetworkManager for static IP
- Applies netplan changes

### 3. Best Practices

**When configuring network:**

1. ✅ Always use static IPs for cluster nodes
2. ✅ Disable DHCP in netplan when using static IP
3. ✅ Configure NetworkManager for manual/static mode
4. ✅ Validate configuration before rebooting
5. ✅ Test connectivity after changes

**When making changes:**

1. ✅ Run validation script first
2. ✅ Make changes using Ansible playbooks when possible
3. ✅ Run validation script after changes
4. ✅ Test connectivity
5. ✅ Document any manual changes

**Before rebooting:**

1. ✅ Run validation script
2. ✅ Ensure all nodes pass validation
3. ✅ Have physical access or IPMI/KVM access ready

### 4. Monitoring

**Periodic checks:**

```bash
# Add to crontab (runs daily at 2 AM)
0 2 * * * /Users/roliveira/WORKSPACE/raolivei/pi-fleet/scripts/validate-network-config.sh >> /var/log/network-validation.log 2>&1
```

**Pre-deployment checks:**

- Add network validation to CI/CD pipeline
- Run before deploying network-related changes
- Run after cluster maintenance

**Post-reboot validation:**

- Run validation script after any node reboot
- Verify connectivity before considering node ready
- Check kube-vip VIP assignment

## Quick Reference

### Check Network Status

```bash
./scripts/validate-network-config.sh
```

### Fix Network Issues

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/fix-network-config.sh
```

### Manual Fix (if automation fails)

```bash
# On the affected node
sudo ip addr del <wrong-ip>/24 dev wlan0
sudo sed -i 's/dhcp4: true/dhcp4: false/' /etc/netplan/*.yaml
sudo netplan apply
sudo systemctl restart NetworkManager
```

### Verify Fix

```bash
ip addr show wlan0 | grep "inet "
sudo grep -r "dhcp4: true" /etc/netplan/
sudo nmcli connection show | grep wlan0
```

## Files Created

1. **`scripts/validate-network-config.sh`**

   - Validates network configuration on all nodes
   - Checks for dual IPs, DHCP conflicts, routing issues
   - Returns exit code 0 if all checks pass

2. **`ansible/playbooks/fix-network-config.yml`**

   - Automatically fixes network configuration issues
   - Removes extra IPs, disables DHCP, configures NetworkManager
   - Can be run safely on all nodes

3. **`docs/NETWORK_CONFIGURATION_BEST_PRACTICES.md`**
   - Comprehensive guide to proper network configuration
   - Troubleshooting steps
   - Prevention strategies

## Integration with Existing Workflows

### Before Node Conversion

```bash
# Validate network before converting worker to control plane
./scripts/validate-network-config.sh || exit 1
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/convert-worker-to-control-plane.yml
./scripts/validate-network-config.sh || exit 1
```

### After Node Reboot

```bash
# Validate network after reboot
./scripts/validate-network-config.sh
# If issues found, fix them
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/fix-network-config.yml
```

### During Cluster Maintenance

```bash
# Validate all nodes before maintenance
./scripts/validate-network-config.sh

# Perform maintenance...

# Validate all nodes after maintenance
./scripts/validate-network-config.sh
```

## Success Criteria

A node's network is correctly configured when:

- ✅ Validation script passes with 0 errors
- ✅ Single IP on wlan0 (excluding VIP)
- ✅ DHCP disabled in netplan
- ✅ NetworkManager using manual/static mode
- ✅ No duplicate routes
- ✅ Interface is UP
- ✅ Can ping gateway (192.168.2.1)
- ✅ Can resolve DNS (nslookup google.com)
- ✅ Can reach other nodes

## References

- [Network Configuration Best Practices](NETWORK_CONFIGURATION_BEST_PRACTICES.md)
- [Node-1 Root Cause Analysis](NODE_1_ROOT_CAUSE.md)
- [Network Architecture](NETWORK_ARCHITECTURE.md)
