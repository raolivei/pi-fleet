# Emergency Boot Recovery

## Current Situation

All 3 nodes (node-1, node-1, node-2) are stuck after reboot.

## ⚠️ IMPORTANT: Recovery via SD Card

Since nodes are stuck during boot, **it's not possible to apply fixes via Ansible**. You need to use SD card backup to recover, **one node at a time**.

**See complete guide**: [`docs/RECOVERY_FROM_SD_CARD.md`](../docs/RECOVERY_FROM_SD_CARD.md)

## Quick Process (one node at a time)

### 1. Prepare Node

- Insert SD card backup
- Remove NVMe (temporarily)
- Power on node and wait for boot (1-2 minutes)

### 2. Apply Fixes

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
./scripts/recover-node-from-sd.sh node-1
```

### 3. Test

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible
ansible node-1 -i inventory/hosts.yml -m reboot --become
# Wait 2 minutes
ansible node-1 -i inventory/hosts.yml -m ping
```

### 4. Repeat for next node

- **node-1 first** (control plane - most critical)
- **node-1 next** (worker)
- **node-2 last** (worker)

## Recovery Order

1. **node-1** - Control plane, most critical
2. **node-1** - Worker
3. **node-2** - Worker

## What the fix does:

- ✅ Adds `nofail` to all optional mounts in fstab
- ✅ Configures systemd timeouts (300s)
- ✅ Unlocks root account
- ✅ Disables PAM faillock
- ✅ Verifies PARTUUIDs are correct

## After Recovering All Nodes

```bash
# 1. Verify nodes are online
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible
ansible raspberry_pi -i inventory/hosts.yml -m ping

# 2. Apply preventive fixes to all
ansible-playbook playbooks/fix-boot-reliability.yml

# 3. Verify cluster
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes

# 4. Test reboot (one node at a time)
ansible node-1 -i inventory/hosts.yml -m reboot --become
# Wait 2 minutes
ansible node-1 -i inventory/hosts.yml -m ping
```

## Future Prevention

This problem should not happen again because:

1. The `fix-boot-reliability.yml` playbook fixes the root cause
2. The `setup-new-node.yml` already includes these fixes
3. All optional mounts now have `nofail`

## Complete Documentation

- **Recovery guide**: [`docs/RECOVERY_FROM_SD_CARD.md`](../docs/RECOVERY_FROM_SD_CARD.md)
- **Boot reliability fix**: [`docs/BOOT_RELIABILITY_FIX.md`](../docs/BOOT_RELIABILITY_FIX.md)
