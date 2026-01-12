# Network Configuration Best Practices

## Overview

This document outlines the proper network configuration for Eldertree cluster nodes to prevent dual IP issues, network instability, and connectivity problems.

## Root Cause of Node-1 Issues

Node-1 experienced recurring network issues due to:
1. **Dual IP Configuration**: Both static IP (192.168.2.101) and DHCP IP (192.168.2.86) on wlan0
2. **Conflicting Configuration**: netplan had `dhcp4: true` while also configuring a static IP
3. **NetworkManager Confusion**: NetworkManager tried to use both DHCP and static IP

## Proper Network Configuration

### For wlan0 (WiFi - Management Network)

**Required Configuration:**
- ✅ **Single static IP** per node:
  - node-1: `192.168.2.101/24`
  - node-2: `192.168.2.102/24`
  - node-3: `192.168.2.103/24`
- ✅ **DHCP disabled** in netplan
- ✅ **NetworkManager** configured for manual/static IP
- ✅ **Gateway**: `192.168.2.1`
- ✅ **DNS**: `192.168.2.201` (Pi-hole), `8.8.8.8` (fallback)

**What NOT to do:**
- ❌ Don't enable `dhcp4: true` in netplan when using static IP
- ❌ Don't configure both DHCP and static IP in NetworkManager
- ❌ Don't manually add multiple IPs to wlan0 (except kube-vip VIP)

### For eth0 (Gigabit Ethernet - Cluster Network)

**Required Configuration:**
- ✅ **Static IP** on isolated subnet:
  - node-1: `10.0.0.1/24`
  - node-2: `10.0.0.2/24`
  - node-3: `10.0.0.3/24`
- ✅ **No gateway** (isolated network)
- ✅ **No DNS** (uses wlan0 DNS)
- ✅ **DHCP disabled**

### Special Case: kube-vip VIP

The VIP (`192.168.2.100/32`) is automatically assigned by kube-vip to the leader node's wlan0 interface. This is **expected and correct** - do not remove it.

## Validation Checklist

Before considering a node's network configuration correct, verify:

1. ✅ **Single IP on wlan0** (excluding VIP)
   ```bash
   ip addr show wlan0 | grep "inet " | grep -v "192.168.2.100"
   # Should show only one IP: 192.168.2.10X
   ```

2. ✅ **DHCP disabled in netplan**
   ```bash
   sudo grep -r "dhcp4: true" /etc/netplan/
   # Should return nothing
   ```

3. ✅ **NetworkManager configured correctly**
   ```bash
   sudo nmcli connection show | grep wlan0
   # Check that method is "manual" not "auto" or "dhcp"
   ```

4. ✅ **No duplicate routes**
   ```bash
   ip route show | grep "192.168.2.0/24" | grep wlan0
   # Should show only one route
   ```

5. ✅ **Interface is UP**
   ```bash
   ip link show wlan0
   # Should show "state UP"
   ```

## Automation

### Validation Script

Run the validation script to check all nodes:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
./scripts/validate-network-config.sh
```

This script checks:
- Multiple IPs on wlan0 (excluding VIP)
- DHCP enabled in netplan
- NetworkManager configuration
- Duplicate routes
- Interface status

### Fix Script

If issues are found, use the Ansible playbook to fix them:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/fix-network-config.yml
```

## Prevention

### During Initial Setup

1. **Configure static IP in router** (DHCP reservation)
2. **Disable DHCP in netplan** when configuring static IP
3. **Use NetworkManager** for WiFi connections with manual IP
4. **Validate configuration** before rebooting

### After Changes

1. **Always validate** network configuration after changes
2. **Test connectivity** before considering it done
3. **Monitor for dual IPs** - run validation script periodically
4. **Document changes** to network configuration

### Monitoring

Consider adding network validation to:
- **Pre-deployment checks** in CI/CD
- **Post-reboot validation** scripts
- **Periodic health checks** (cron job)

## Troubleshooting

### If Dual IP Detected

1. **Remove extra IP**:
   ```bash
   sudo ip addr del <wrong-ip>/24 dev wlan0
   ```

2. **Disable DHCP in netplan**:
   ```bash
   sudo sed -i 's/dhcp4: true/dhcp4: false/' /etc/netplan/*.yaml
   sudo netplan apply
   ```

3. **Fix NetworkManager**:
   ```bash
   sudo nmcli connection modify <connection-name> ipv4.method manual
   sudo systemctl restart NetworkManager
   ```

4. **Verify**:
   ```bash
   ./scripts/validate-network-config.sh
   ```

### If Node Loses Connectivity

1. **Check interface status**: `ip link show wlan0`
2. **Check IP assignment**: `ip addr show wlan0`
3. **Check routing**: `ip route show`
4. **Check DNS**: `nslookup google.com`
5. **Check gateway**: `ping 192.168.2.1`

## References

- [Node-1 Root Cause Analysis](NODE_1_ROOT_CAUSE.md)
- [Network Configuration Safety](NETWORK_CONFIGURATION_SAFETY.md)
- [Network Architecture](NETWORK_ARCHITECTURE.md)


