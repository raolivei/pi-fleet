# HA Control Plane Implementation Progress

**Date:** 2026-01-09
**Status:** In Progress

## Completed Tasks

1. ✅ **Fixed node-2 NotReady status** - Node-2 is now Ready as a worker
2. ✅ **Verified Longhorn on all nodes** - Storage paths configured on all 3 nodes
3. ✅ **Backed up cluster state** - Full backup created in `backups/ha-migration-20260108/`
4. ✅ **Updated Ansible playbooks for HA** - `install-k3s.yml` now supports HA control plane installation
5. ✅ **Created conversion playbook** - `convert-worker-to-control-plane.yml` for automated conversion
6. ✅ **Fixed node-1 hostname** - Updated from node-0 to node-1.eldertree.local

## Current Issues

### Node-1 Configuration

- Node-1's k3s config.yaml still references `node-0.eldertree.local` in TLS SANs
- Node-1 was restarted during config update - may need to wait for full recovery
- Old "node-0" entry may still exist in cluster

### Node-2 Conversion

- k3s service file exists but service is failing to start
- Configuration mismatch error: `disable-network-policy`
- Service is in "activating (auto-restart)" state, not actually running
- Need to match exact configuration from node-1

## Next Steps

1. **Wait for node-1 to fully recover** after restart
2. **Fix node-1's k3s config.yaml** to remove node-0 references:
   ```yaml
   bind-address: 10.0.0.1
   advertise-address: 10.0.0.1
   tls-san:
     - 10.0.0.1
     - node-1.eldertree.local
   ```
3. **Remove old node-0 entry** from cluster: `kubectl delete node node-0`
4. **Complete node-2 conversion** using Ansible playbook once node-1 is stable
5. **Convert node-3** to control plane
6. **Update kubeconfig** for multiple API endpoints
7. **Test HA failover** by shutting down node-1

## Ansible Playbooks Created

- `ansible/playbooks/convert-worker-to-control-plane.yml` - Converts worker to control plane
- `ansible/playbooks/fix-node-hostname.yml` - Fixes node hostnames

## Files Modified

- `ansible/playbooks/install-k3s.yml` - Added HA control plane support
- `scripts/convert-worker-to-control-plane.sh` - Manual conversion script (backup)

## Configuration Mismatch Issue

The `disable-network-policy` configuration mismatch suggests:

- Node-1 may have network policy enabled (default)
- Node-2 needs to match this exactly
- Network policies exist in cluster (flux-system, observability namespaces)
- Solution: Ensure both nodes have same network policy setting (likely enabled/default)

## Commands to Continue

```bash
# 1. Wait for node-1 to be accessible
ssh raolivei@192.168.2.101 "sudo systemctl status k3s"

# 2. Fix node-1 config
ssh raolivei@192.168.2.101 "sudo tee /etc/rancher/k3s/config.yaml > /dev/null << 'EOF'
bind-address: 10.0.0.1
advertise-address: 10.0.0.1
tls-san:
  - 10.0.0.1
  - node-1.eldertree.local
EOF
sudo systemctl restart k3s"

# 3. Remove old node-0
export KUBECONFIG=~/.kube/config-eldertree
kubectl delete node node-0

# 4. Convert node-2
cd ansible
ansible-playbook playbooks/convert-worker-to-control-plane.yml --limit node-2

# 5. Convert node-3
ansible-playbook playbooks/convert-worker-to-control-plane.yml --limit node-3
```
