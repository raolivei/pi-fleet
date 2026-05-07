# Pi-hole LoadBalancer Fix - Complete Recovery Guide

**Date**: 2026-05-07  
**Status**: In Progress  
**Issue**: Pi-hole LoadBalancer stuck in `<pending>` state

## Problem Summary

Pi-hole DNS service cannot get external IP `192.168.2.201` due to multiple interacting issues:

1. **kube-vip v1.1.2 incompatibility**: Upgraded kube-vip broke control plane VIP
2. **K3s ServiceLB conflict**: K3s creates `svclb` pods that block kube-vip
3. **loadBalancerClass persistence**: Helm was merging old values, keeping the field
4. **Pi-hole crash loop**: Waiting for DNS resolution (chicken-and-egg)

## What Happened

### Timeline

1. **Initial Issue**: kube-vip v0.8.3 ignores services with `loadBalancerClass` set
2. **Attempted Fix**: Upgraded to kube-vip v1.1.2 to support `loadBalancerClass`
3. **Cluster Outage**: v1.1.2 broke control plane VIP (192.168.2.100)
4. **Rollback**: Reverted to v0.8.3, VIP recovered
5. **Current State**: Service has no `loadBalancerClass` but K3s ServiceLB interferes

### Root Cause

K3s comes with built-in ServiceLB (Klipper) that automatically handles LoadBalancer services.
When both K3s ServiceLB and kube-vip try to manage the same service:
- K3s creates `svclb` DaemonSet pods on each node
- These pods try to bind host port 53 (conflicts with CoreDNS)
- Pods stuck in `Pending` state
- Service never gets external IP
- kube-vip can't assign the IP because K3s ServiceLB is "handling" it

## Solution: Disable K3s ServiceLB

### Step 1: Update K3s Configuration on All Nodes

SSH to each control plane node and disable ServiceLB:

```bash
# On node-1, node-2, node-3:
ssh raolivei@192.168.2.101  # Repeat for .102, .103

# Edit k3s service
sudo nano /etc/systemd/system/k3s.service

# Add --disable servicelb to ExecStart line
# Example:
ExecStart=/usr/local/bin/k3s server \
  --disable servicelb \
  --tls-san=192.168.2.100 \
  --tls-san=192.168.2.101 \
  ... (other existing flags)

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart k3s

# Verify restart
sudo systemctl status k3s
```

### Step 2: Verify ServiceLB is Disabled

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check that svclb pods are gone
kubectl get pods -n kube-system | grep svclb
# Should return nothing

# Verify kube-vip is running
kubectl get pods -n kube-system -l app=kube-vip
# Should show 3 pods Running
```

### Step 3: Fix Pi-hole Service

```bash
# Delete service to force recreation
kubectl delete svc pi-hole -n pihole

# Force Flux to reconcile
flux suspend helmrelease pi-hole -n pihole
flux resume helmrelease pi-hole -n pihole

# Wait for service to be created (60-90 seconds)
watch kubectl get svc pi-hole -n pihole

# Should show EXTERNAL-IP: 192.168.2.201
```

### Step 4: Verify Pi-hole is Working

```bash
# Test DNS resolution
dig @192.168.2.201 google.com

# Check Pi-hole pods
kubectl get pods -n pihole

# Access web UI
open https://pihole.eldertree.local/admin/
```

## Alternative: Use NodePort Temporarily

If you need Pi-hole DNS immediately while fixing the LoadBalancer:

```bash
# Pi-hole is exposed on NodePort 30053
# Use any node IP for DNS:
dig @192.168.2.101 -p 30053 google.com
dig @192.168.2.102 -p 30053 google.com
dig @192.168.2.103 -p 30053 google.com
```

**Note**: macOS DNS settings don't support custom ports, so this only works for manual queries.

## Future: Upgrade kube-vip Properly

kube-vip v1.1.2 has better `loadBalancerClass` support but requires testing:

### Test Plan for v1.1.2 Upgrade

1. **Create test deployment**:
   - Deploy kube-vip v1.1.2 to ONE node first
   - Monitor VIP stability for 30 minutes
   - Check logs for errors

2. **Gradual rollout**:
   - If stable, roll out to second node
   - Wait 30 minutes, monitor
   - Finally roll out to third node

3. **Rollback plan**:
   - Keep v0.8.3 DaemonSet manifest ready
   - Document rollback procedure
   - Have Tailscale access confirmed working

4. **Validation**:
   - VIP responds consistently
   - All LoadBalancer services get IPs
   - No control plane disruption

## DNS Configuration for MacBook

Once Pi-hole has external IP 192.168.2.201:

### Option 1: Per-Network DNS (Recommended for VPN)

1. System Settings → Network → Wi-Fi → Details
2. DNS tab → Click **+**
3. Add: `192.168.2.201`
4. Keep existing servers as fallback: `8.8.8.8`, `1.1.1.1`
5. Click **OK**

### Option 2: Router-Wide DNS

Configure your router to use `192.168.2.201` as primary DNS for network-wide ad blocking.

### VPN Compatibility

AWS VPN typically uses split-tunnel DNS:
- VPN domains go through VPN DNS
- Everything else uses your system DNS (including Pi-hole)
- No conflicts expected

## Lessons Learned

1. **Always test infrastructure upgrades in non-production first**
2. **kube-vip manages control plane VIP - upgrading it is high-risk**
3. **Helm merges values - need explicit `null` to remove fields**
4. **K3s ServiceLB must be disabled when using alternative LB controllers**
5. **Maintain Tailscale access for recovery scenarios**

## Related Files

- kube-vip DaemonSet: `clusters/eldertree/kube-vip/kube-vip-daemonset.yaml`
- Pi-hole HelmRelease: `clusters/eldertree/dns-services/pihole/helmrelease.yaml`
- Pi-hole Helm chart: `helm/pi-hole/`
- Service template: `helm/pi-hole/templates/service.yaml`

## Status Updates

- **2026-05-04**: kube-vip v1.1.2 upgrade failed, rolled back to v0.8.3
- **2026-05-07**: Identified K3s ServiceLB conflict, documented solution
- **Next**: Disable K3s ServiceLB on all nodes
