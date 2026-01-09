# Node Troubleshooting Guide - eldertree Cluster

## Current Issues

### Issue 1: node-0 NotReady and Unreachable

**Symptoms:**
- node-0.eldertree.local shows as `NotReady`
- Last heartbeat: ~5 days ago (2026-01-03)
- Cannot ping or SSH to 192.168.2.100
- Status: `NodeStatusUnknown` - "Kubelet stopped posting node status"

**Root Cause:**
- Node is powered off, network disconnected, or unreachable
- Node has been offline for ~5 days

**Solution Options:**

#### Option A: Remove node-0 (Recommended if node is no longer in use)

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Drain node-0 (if possible)
kubectl drain node-0.eldertree.local --ignore-daemonsets --delete-emptydir-data --force

# Delete node from cluster
kubectl delete node node-0.eldertree.local
```

#### Option B: Recover node-0 (If node should be active)

1. **Physical check:**
   - Verify node is powered on
   - Check network cable connection
   - Verify LED indicators

2. **Network check:**
   ```bash
   # Try to ping
   ping 192.168.2.100
   
   # Try SSH
   ssh raolivei@192.168.2.100
   ```

3. **If accessible, restart k3s:**
   ```bash
   ssh raolivei@192.168.2.100
   sudo systemctl restart k3s
   sudo systemctl status k3s
   ```

### Issue 2: IP Address Conflict

**Symptoms:**
- node-0 and node-1 both have InternalIP: `10.0.0.1`
- node-2 and node-3 both have InternalIP: `10.0.0.3`

**Root Cause:**
- Network misconfiguration
- Multiple nodes configured with the same IP address

**Expected Configuration:**
According to cluster documentation:
- **node-1**: 192.168.2.101 (wlan0), 10.0.0.1 (eth0) ✅ Correct
- **node-2**: 192.168.2.102 (wlan0), 10.0.0.2 (eth0) ❌ Currently 10.0.0.3
- **node-3**: 192.168.2.103 (wlan0), 10.0.0.3 (eth0) ✅ Correct

**Solution:**

1. **Fix node-2 IP address:**
   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet/ansible
   ansible-playbook playbooks/configure-eth0-static.yml --limit node-2 \
     -e eth0_ip=10.0.0.2
   ```

2. **Verify IPs after fix:**
   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   kubectl get nodes -o wide
   ```

### Issue 3: node-1 etcd Configuration

**Symptoms:**
- node-1 shows `EtcdIsVoter: False`
- Message: "Node is not a member of the etcd cluster"
- etcd annotations show node-0's name

**Root Cause:**
- node-1 was configured with node-0's hostname in etcd
- node-1 may not be properly joined to etcd cluster

**Solution:**

1. **Check etcd members:**
   ```bash
   ssh raolivei@192.168.2.101
   sudo k3s etcd-member-list
   ```

2. **If node-1 is not in etcd, it may need to be re-added:**
   - This is complex and may require cluster reconfiguration
   - Since node-1 is Ready and working, this may be acceptable if only node-1 is the control plane

3. **If node-0 is removed, node-1 should become the primary etcd member**

## Diagnostic Commands

### Check Node Status
```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes -o wide
kubectl describe node node-0.eldertree.local
kubectl describe node node-1.eldertree.local
```

### Check Network Connectivity
```bash
# Ping test
ping -c 3 192.168.2.100  # node-0
ping -c 3 192.168.2.101  # node-1

# SSH test
ssh raolivei@192.168.2.100
ssh raolivei@192.168.2.101
```

### Check IP Addresses
```bash
# From cluster
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name): \(.status.addresses[] | select(.type=="InternalIP") | .address)"'

# From nodes
ssh raolivei@192.168.2.101 "ip addr show eth0 | grep 'inet '"
ssh raolivei@192.168.2.102 "ip addr show eth0 | grep 'inet '"
```

### Check k3s Service
```bash
ssh raolivei@192.168.2.101 "systemctl status k3s"
ssh raolivei@192.168.2.101 "sudo journalctl -u k3s -n 50 --no-pager"
```

## Automated Fix Scripts

### Run Diagnostics
```bash
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/diagnose-node-issues.sh
```

### Run Fixes
```bash
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/fix-node-issues.sh
```

## Recommended Actions

1. **Immediate:**
   - ✅ Remove node-0 from cluster (it's been unreachable for 5 days)
   - ✅ Verify node-1 is functioning correctly
   - ✅ Fix node-2 IP address (10.0.0.2 instead of 10.0.0.3)

2. **Short-term:**
   - Monitor node-1 to ensure it remains stable as the sole control plane
   - Consider adding another control plane node for HA if needed

3. **Long-term:**
   - Document which nodes are active
   - Update inventory to reflect current cluster state
   - Set up monitoring/alerting for node status

## Current Cluster State

**Active Nodes:**
- ✅ node-1.eldertree.local (Ready) - Control plane
- ✅ node-3.eldertree.local (Ready) - Worker

**Problem Nodes:**
- ❌ node-0.eldertree.local (NotReady) - Unreachable, should be removed
- ⚠️  node-2.eldertree.local (NotReady) - IP conflict, needs fix

## Related Documentation

- [Network Architecture](../docs/NETWORK_ARCHITECTURE.md)
- [Ansible Playbooks](../ansible/README.md)
- [Cluster Setup](../pi-fleet-blog/chapters/05-cluster-setup.md)


