# Vault Issue Diagnosis

## Problem

Vault pod is stuck in `Pending` status and cannot be scheduled.

## Root Cause

The Vault PersistentVolume (PV) was created on `node-3.eldertree.local`, but this node no longer exists in the cluster. The PV has node affinity that requires it to be on `node-3`, which prevents the pod from being scheduled on the available nodes (`node-1` and `node-2`).

**Evidence:**
- PVC `data-vault-0` is bound to PV `pvc-c228a4d1-2445-4666-9209-2dddf9bcddf0`
- PVC annotation shows: `volume.kubernetes.io/selected-node: node-3.eldertree.local`
- Current nodes: `node-1.eldertree.local`, `node-2.eldertree.local` (no `node-3`)
- Pod events show: `0/2 nodes are available: 2 node(s) didn't match PersistentVolume's node affinity`

## Impact

- Vault pod cannot start
- Cannot access secrets stored in Vault
- Cannot update Cloudflare API token in Vault
- External Secrets Operator cannot sync secrets from Vault

## Solutions

### Option 1: Delete and Recreate Vault (⚠️ Data Loss)

If Vault data can be recreated or is backed up:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Delete Vault StatefulSet (this will delete the pod)
kubectl delete statefulset vault -n vault

# Delete the PVC (this will delete the PV)
kubectl delete pvc data-vault-0 -n vault

# Delete the PV (if it still exists)
kubectl delete pv pvc-c228a4d1-2445-4666-9209-2dddf9bcddf0

# Flux will automatically recreate Vault
# Wait for pod to be scheduled on an available node
kubectl get pods -n vault -w
```

**⚠️ WARNING**: This will delete all Vault data. Only do this if:
- You have backups
- You can recreate the secrets
- The data is not critical

### Option 2: Patch PV Node Affinity (Recommended if data is important)

Modify the PV to allow it to be used on any available node:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Get current PV spec
kubectl get pv pvc-c228a4d1-2445-4666-9209-2dddf9bcddf0 -o yaml > /tmp/pv-backup.yaml

# Patch PV to remove node affinity (or change to match available nodes)
kubectl patch pv pvc-c228a4d1-2445-4666-9209-2dddf9bcddf0 --type='json' \
  -p='[{"op": "remove", "path": "/spec/nodeAffinity"}]'

# Or patch to allow node-1 or node-2
kubectl patch pv pvc-c228a4d1-2445-4666-9209-2dddf9bcddf0 --type='json' \
  -p='[{"op": "replace", "path": "/spec/nodeAffinity/required/nodeSelectorTerms/0/matchExpressions/0/values", "value": ["node-1.eldertree.local", "node-2.eldertree.local"]}]'
```

**Note**: With `local-path` storage, the data is physically on `node-3`. If that node is gone, the data is lost anyway. This option only helps if `node-3` still exists but isn't in the cluster.

### Option 3: Restore from Backup

If you have Vault backups:

1. Delete current Vault deployment
2. Restore from backup
3. Vault will create new PV on available node

### Option 4: Temporarily Use Terraform Token Directly

While Vault is unavailable, use the Cloudflare API token directly in Terraform:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform
export TF_VAR_cloudflare_api_token="YOUR_CLOUDFLARE_API_TOKEN"
export TF_VAR_pitanga_cloud_zone_id="4d674555d7344d4b5d46681fd17b49bd"
terraform apply
```

This bypasses Vault for now. Once Vault is fixed, update the token in Vault.

## Recommended Action

Since `local-path` volumes are node-specific and `node-3` is gone, the data is likely lost. Recommended approach:

1. **Delete and recreate Vault** (Option 1)
2. **Recreate secrets** (Cloudflare API token, etc.)
3. **Update token in Vault** once it's running

## Prevention

For production, consider:
- Using a storage class that supports node migration (e.g., NFS, Longhorn)
- Regular Vault backups
- Using Vault's integrated backup features


