# Longhorn Storage Recommendation

## Current Status

Longhorn is experiencing issues:
- **Webhook connectivity problems** - Managers can't verify webhook service
- **Stuck in uninstalling state** - HelmRelease is trying to uninstall but failing
- **PVCs in Pending state** - Cannot provision new volumes
- **Root cause**: Hairpin mode required but cannot be enabled on cni0 bridge

## What "Continue with local-path storage" Means

The recommendation means:

✅ **DO:**
- Use `local-path` storage class for **new PVCs** (already the default)
- Keep Longhorn installed but **suspended** (don't actively use it)
- Use local-path for all new deployments

❌ **DON'T:**
- Create new PVCs with `storageClassName: longhorn`
- Rely on Longhorn for critical workloads
- Expect Longhorn to work reliably until issues are resolved

## Options

### Option 1: Suspend Longhorn (Recommended)

**What it does:**
- Keeps Longhorn installed but stops Flux from trying to reconcile it
- Prevents further installation/uninstallation attempts
- Allows you to re-enable it later when issues are fixed

**How to do it:**
```bash
# Suspend the HelmRelease
kubectl patch helmrelease longhorn -n longhorn-system --type=json \
  -p='[{"op": "add", "path": "/spec/suspend", "value": true}]'

# Or edit the HelmRelease file
# Add: suspend: true
# Then commit and push
```

**Pros:**
- Quick and reversible
- Keeps configuration for future use
- No data loss risk

**Cons:**
- Longhorn resources still consume some resources
- Stuck pods may remain

### Option 2: Complete Uninstall

**What it does:**
- Removes Longhorn completely from the cluster
- Cleans up all Longhorn resources
- Frees up resources

**Prerequisites:**
- Migrate any existing Longhorn PVCs to local-path first
- Backup any important data

**How to do it:**
```bash
# 1. Migrate PVCs first (if any have data)
# 2. Delete HelmRelease
kubectl delete helmrelease longhorn -n longhorn-system

# 3. Clean up remaining resources
kubectl delete namespace longhorn-system
```

**Pros:**
- Clean slate
- No resource usage
- No stuck resources

**Cons:**
- Permanent (need to reinstall later)
- Requires PVC migration
- More work

### Option 3: Try to Fix

**What it involves:**
- Continue troubleshooting webhook issues
- Try different Longhorn versions
- Attempt to enable hairpin mode manually
- May require switching CNI

**Pros:**
- If successful, get distributed storage benefits
- No need to migrate data

**Cons:**
- Time-consuming
- May not be solvable with current setup
- May require significant changes

## Recommendation

**For now: Suspend Longhorn (Option 1)**

Reasons:
1. ✅ Quick and reversible
2. ✅ No data migration needed
3. ✅ Can re-enable when issues are fixed
4. ✅ local-path is working fine for current needs

**When to revisit:**
- When hairpin mode can be properly enabled
- When Longhorn fixes webhook design issues
- When switching to a CNI that supports hairpin mode better
- When distributed storage becomes critical

## Current Storage Strategy

**Use local-path for:**
- ✅ All new PVCs (default storage class)
- ✅ Stateful applications
- ✅ Databases
- ✅ Any workload needing persistent storage

**local-path benefits:**
- ✅ Works reliably
- ✅ No additional configuration needed
- ✅ Suitable for single-node or small clusters
- ✅ Good performance for local storage

**Limitations:**
- ⚠️  Not distributed (data on single node)
- ⚠️  No replication across nodes
- ⚠️  Node failure = data loss (unless backed up)

## Migration Path (If Needed)

If you have data in Longhorn PVCs that needs to be preserved:

1. **Identify PVCs:**
   ```bash
   kubectl get pvc --all-namespaces -o json | \
     jq -r '.items[] | select(.spec.storageClassName == "longhorn")'
   ```

2. **Backup data** (if PVCs are bound and have data)

3. **Create new PVCs with local-path:**
   ```yaml
   storageClassName: local-path
   ```

4. **Restore data** to new PVCs

5. **Update deployments** to use new PVCs

6. **Delete old Longhorn PVCs**

## References

- [Longhorn Troubleshooting](https://longhorn.io/docs/troubleshooting/)
- [Hairpin Mode Issue](https://github.com/longhorn/longhorn/issues/XXXX)
- [local-path Provisioner](https://github.com/rancher/local-path-provisioner)


