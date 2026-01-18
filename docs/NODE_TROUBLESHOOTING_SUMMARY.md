<!-- MIGRATED TO RUNBOOK -->
> **📚 This document has been migrated to the Eldertree Runbook**
>
> For the latest version, see: [NODE-004](https://docs.eldertree.xyz/runbook/issues/node/NODE-004)
>
> The runbook provides searchable troubleshooting guides with improved formatting.

---


# Node Troubleshooting Summary

## Issues Identified and Status

### ✅ Issue 1: node-1 NotReady - RESOLVED
- **Status:** Removed from cluster
- **Action Taken:** Deleted node-1.eldertree.local from cluster
- **Note:** Node may still appear in `kubectl get nodes` until cache clears, but it's been removed

### ⚠️ Issue 2: node-2 NotReady - IN PROGRESS
- **Status:** k3s-agent authentication failure
- **Error:** "Node password rejected, duplicate hostname"
- **Root Cause:** k3s-agent cannot authenticate with control plane
- **Fix Script:** `scripts/fix-node-2-k3s.sh`

### ✅ Issue 3: node-1 Status - VERIFIED
- **Status:** Ready and functioning
- **Note:** Shows as Ready, but etcd configuration may need review

### ✅ Issue 4: node-3 Status - VERIFIED  
- **Status:** Ready and functioning

## Current Cluster State

```
NAME                     STATUS     ROLES                       AGE     VERSION
node-1.eldertree.local   NotReady   control-plane,etcd,master   14d     v1.33.6+k3s1  [REMOVED]
node-1.eldertree.local   Ready      control-plane,etcd,master   12d     v1.33.6+k3s1  [ACTIVE]
node-2.eldertree.local   NotReady   <none>                      7d20h   v1.33.6+k3s1  [FIXING]
node-3.eldertree.local   Ready      <none>                      4d19h   v1.33.6+k3s1  [ACTIVE]
```

## IP Address Configuration

**Actual Network IPs (verified):**
- node-1: 192.168.2.101 (wlan0), 10.0.0.1 (eth0) ✅
- node-2: 192.168.2.102 (wlan0), 10.0.0.2 (eth0) ✅
- node-3: 192.168.2.103 (wlan0), 10.0.0.3 (eth0) ✅

**Kubernetes Reported IPs:**
- node-1: 10.0.0.1 ✅
- node-2: 10.0.0.3 ⚠️ (should be 10.0.0.2, but actual network is correct)
- node-3: 10.0.0.3 ✅

**Note:** The IP conflict shown in Kubernetes (node-2 and node-3 both showing 10.0.0.3) is a reporting issue. The actual network configuration is correct. Once node-2's k3s-agent is fixed, it should report the correct IP.

## Next Steps

### Immediate Actions

1. **Fix node-2 k3s-agent:**
   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet
   ./scripts/fix-node-2-k3s.sh
   ```

2. **Monitor node-2 recovery:**
   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   kubectl get nodes node-2.eldertree.local -w
   ```

3. **Verify node-1 removal (may take a few minutes):**
   ```bash
   kubectl get nodes
   # node-1 should disappear after cache clears
   ```

### Verification Commands

```bash
# Check all nodes
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes -o wide

# Check node-2 specifically
kubectl describe node node-2.eldertree.local

# Check k3s-agent on node-2
ssh raolivei@192.168.2.102 "sudo systemctl status k3s-agent"
ssh raolivei@192.168.2.102 "sudo journalctl -u k3s-agent -n 50 --no-pager"
```

## Troubleshooting Scripts

All diagnostic and fix scripts are in `pi-fleet/scripts/`:

- `diagnose-node-issues.sh` - Comprehensive node diagnostics
- `fix-node-issues.sh` - Interactive fix script
- `fix-node-2-k3s.sh` - Fix node-2 authentication issue

## Expected Final State

After fixes complete:
- ✅ node-1: Ready (control-plane)
- ✅ node-2: Ready (worker) 
- ✅ node-3: Ready (worker)
- ❌ node-1: Removed (no longer in cluster)

## Related Documentation

- [Node Troubleshooting Guide](./NODE_TROUBLESHOOTING.md)
- [Ansible Playbooks](../ansible/README.md)
- [Network Configuration](./NETWORK_ARCHITECTURE.md)




