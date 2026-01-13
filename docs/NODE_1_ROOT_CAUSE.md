<!-- MIGRATED TO RUNBOOK -->

> **📚 This document has been migrated to the Eldertree Runbook**
>
> For the latest version, see: [NODE-003](https://docs.eldertree.xyz/runbook/issues/node/NODE-003)
>
> The runbook provides searchable troubleshooting guides with improved formatting.

---

# Node-1 Root Cause - IDENTIFIED ✅

## Primary Root Cause: Dual IP Configuration on wlan0

**Issue**: wlan0 interface has TWO IP addresses:

- Primary: `192.168.2.101/24` (static, configured via netplan)
- Secondary: `192.168.2.86/24` (dynamic, from DHCP)

**Why This Causes Problems:**

1. **Routing Confusion**: Two routes for the same network (192.168.2.0/24) with same metric
2. **Connection Timeouts**: System doesn't know which IP to use for outbound connections
3. **SSH Issues**: Connections may try to use the wrong IP
4. **API Server Issues**: k3s API server may bind to wrong IP or get confused
5. **Network Instability**: Can cause the interface to become unresponsive

**Evidence from Diagnostics:**

```
3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP>
    inet 192.168.2.101/24 ... scope global noprefixroute wlan0
    inet 192.168.2.86/24 ... scope global secondary dynamic noprefixroute wlan0

Routing table:
192.168.2.0/24 dev wlan0 proto kernel scope link src 192.168.2.101 metric 600
192.168.2.0/24 dev wlan0 proto kernel scope link src 192.168.2.86 metric 600
```

## Netplan Configuration Issue

The netplan config has:

```yaml
dhcp4: true # ← This is the problem!
ipv4.address1: "192.168.2.101/24" # Static IP also configured
```

This causes NetworkManager to:

1. Assign static IP: 192.168.2.101
2. Also get DHCP lease: 192.168.2.86
3. Result: Dual IP configuration

## Solution

### Immediate Fix (When Node-1 is Accessible)

Run the fix script:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
ssh raolivei@node-1 'bash -s' < scripts/fix-node-1-dual-ip.sh
```

Or manually:

```bash
# 1. Remove secondary IP
sudo ip addr del 192.168.2.86/24 dev wlan0

# 2. Disable DHCP in netplan
sudo sed -i 's/dhcp4: true/dhcp4: false/' /etc/netplan/90-NM-a22ee936-95b8-3145-95e5-9b44c6e6b7ca.yaml

# 3. Apply changes
sudo netplan apply

# 4. Verify
ip addr show wlan0 | grep "inet "
```

### Permanent Fix

Update the netplan configuration to disable DHCP:

```yaml
network:
  version: 2
  wifis:
    wlan0:
      renderer: NetworkManager
      dhcp4: false # ← Change from true to false
      addresses:
        - 192.168.2.101/24
      gateway4: 192.168.2.1
      nameservers:
        addresses:
          - 192.168.2.201
          - 8.8.8.8
      access-points:
        "homebase":
          auth:
            key-management: "psk"
            password: "..."
```

## Other Issues Found (Secondary)

1. **Longhorn Webhook Timeouts**: Hairpin mode issue (already documented)
2. **Metrics API Service Unavailable**: v1beta1.metrics.k8s.io returning 503 (not critical)
3. **DNS Nameserver Limits**: Too many nameservers configured (minor)

## System Health (Good)

- ✅ Memory: 6.7GB available (plenty)
- ✅ Disk: 85GB free (24% used)
- ✅ Load: Very low (0.29)
- ✅ Temperature: 50.5°C (normal)
- ✅ No OOM kills
- ✅ No power throttling

## Why Node-1 Specifically?

Node-1 likely has this issue because:

1. It was the first node set up
2. Network configuration may have been changed multiple times
3. DHCP was left enabled when static IP was added
4. Other nodes (node-2, node-3) were configured correctly from the start

## Prevention

When configuring new nodes or updating network config:

1. **Always disable DHCP when using static IPs**
2. **Verify only one IP per interface**: `ip addr show <interface>`
3. **Check routing table**: `ip route show` (should not have duplicate routes)
4. **Test connectivity** after network changes

## Verification After Fix

After applying the fix, verify:

```bash
# Should show only ONE IP
ip addr show wlan0 | grep "inet "

# Should show only ONE route for wlan0
ip route show | grep wlan0

# Test connectivity
ping -c 3 192.168.2.1
ping -c 3 8.8.8.8

# Test SSH
ssh raolivei@node-1 "echo 'SSH OK'"

# Test API server
curl -k https://192.168.2.101:6443/healthz
```

## Next Steps

1. **When node-1 is back up**: Run the fix script immediately
2. **Monitor**: Watch for the dual IP issue returning
3. **Compare**: Check node-2 and node-3 to ensure they don't have this issue
4. **Document**: Update Ansible playbooks to prevent this in the future
