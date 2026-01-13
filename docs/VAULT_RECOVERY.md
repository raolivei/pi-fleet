<!-- MIGRATED TO RUNBOOK -->
> **📚 This document has been migrated to the Eldertree Runbook**
>
> For the latest version, see: [VAULT-001](https://docs.eldertree.xyz/runbook/issues/storage/VAULT-001)
>
> The runbook provides searchable troubleshooting guides with improved formatting.

---


# Vault Recovery Guide

This guide covers how to recover Vault in various failure scenarios.

## Quick Recovery

The easiest way to recover Vault is using the automated recovery script:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
export KUBECONFIG=~/.kube/config-eldertree

# Run recovery script
./scripts/operations/recover-vault.sh
```

The script will:
1. ✅ Check cluster connectivity
2. ✅ Ensure Vault namespace exists
3. ✅ Ensure Vault pod is running (deploy if needed)
4. ✅ Check initialization status (initialize if needed)
5. ✅ Unseal Vault using backup keys
6. ✅ Login to Vault
7. ✅ Restore secrets from backup (if missing)
8. ✅ Update External Secrets Operator token

## Recovery Scenarios

### Scenario 1: Vault is Sealed (After Restart)

**Symptoms:**
- Vault pod is running
- Vault is sealed (requires unseal keys)

**Solution:**
```bash
# Option 1: Use recovery script (recommended)
./scripts/operations/recover-vault.sh

# Option 2: Manual unseal
./scripts/operations/unseal-vault.sh
```

### Scenario 2: Vault Pod Not Running

**Symptoms:**
- `kubectl get pods -n vault` shows no vault-0 pod
- HelmRelease may or may not exist

**Solution:**
```bash
# Recovery script will handle this automatically
./scripts/operations/recover-vault.sh

# Or manually:
# 1. Check HelmRelease
kubectl get helmrelease vault -n vault

# 2. If missing, apply it
kubectl apply -f clusters/eldertree/secrets-management/vault/helmrelease.yaml

# 3. Wait for pod
kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=300s

# 4. Continue with unsealing
./scripts/operations/unseal-vault.sh
```

### Scenario 3: Vault Not Initialized

**Symptoms:**
- Vault pod is running
- `vault status` shows `Initialized: false`

**Solution:**
```bash
# Recovery script will initialize automatically
./scripts/operations/recover-vault.sh

# Or manually:
# 1. Initialize (this generates NEW keys - old data will be lost!)
kubectl exec -n vault vault-0 -- vault operator init

# 2. Save the output securely!
# 3. Unseal with 3 keys
./scripts/operations/unseal-vault.sh
```

**⚠️ WARNING:** Initializing a new Vault will destroy all existing secrets unless you restore from backup!

### Scenario 4: Secrets Missing

**Symptoms:**
- Vault is unsealed
- `vault kv list secret/` shows no secrets or missing secrets

**Solution:**
```bash
# Recovery script will restore from backup automatically
./scripts/operations/recover-vault.sh

# Or manually:
# 1. Ensure Vault is unsealed and logged in
kubectl exec -n vault vault-0 -- vault status

# 2. Restore from backup
./scripts/operations/restore-vault-secrets.sh vault-backup-20251115-163624.json
```

### Scenario 5: Complete Recovery (PVC Lost)

**Symptoms:**
- Vault PVC deleted or corrupted
- All data lost

**Solution:**
```bash
# Use recreate script (will backup first if possible)
./scripts/operations/recreate-vault.sh

# Then restore secrets
./scripts/operations/restore-vault-secrets.sh vault-backup-20251115-163624.json
```

## Backup Files

### Default Backup Locations

- **Secrets Backup**: `vault-backup-20251115-163624.json`
- **Init Data**: `backups/vault-20251123-032746/vault-init.json`
- **Root Token**: `backups/vault-20251123-032746/vault-root-token.txt`

### Using Custom Backup Files

```bash
./scripts/operations/recover-vault.sh \
  --backup-file /path/to/backup.json \
  --init-file /path/to/init.json \
  --root-token-file /path/to/token.txt
```

## Manual Recovery Steps

If the automated script doesn't work, follow these manual steps:

### Step 1: Check Vault Status

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check pod
kubectl get pods -n vault

# Check status
kubectl exec -n vault vault-0 -- vault status
```

### Step 2: Ensure Vault is Running

```bash
# If pod doesn't exist, check HelmRelease
kubectl get helmrelease vault -n vault

# If missing, apply it
kubectl apply -f clusters/eldertree/secrets-management/vault/helmrelease.yaml

# Wait for pod
kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=300s
```

### Step 3: Initialize (if needed)

```bash
# Check if initialized
kubectl exec -n vault vault-0 -- vault status -format=json | jq -r '.initialized'

# If false, initialize (WARNING: destroys existing data!)
kubectl exec -n vault vault-0 -- vault operator init -format=json > vault-init.json

# Save the output securely!
```

### Step 4: Unseal

```bash
# Use unseal script
./scripts/operations/unseal-vault.sh

# Or manually with keys from backup
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>
kubectl exec -n vault vault-0 -- vault operator unseal <key3>
```

### Step 5: Login

```bash
# Get root token from backup
ROOT_TOKEN=$(cat backups/vault-20251123-032746/vault-root-token.txt)

# Login
kubectl exec -n vault vault-0 -- vault login -method=token token="$ROOT_TOKEN"
```

### Step 6: Restore Secrets

```bash
# Restore from backup
./scripts/operations/restore-vault-secrets.sh vault-backup-20251115-163624.json
```

### Step 7: Update External Secrets Operator

```bash
# Get root token
ROOT_TOKEN=$(cat backups/vault-20251123-032746/vault-root-token.txt)

# Update secret
kubectl delete secret vault-token -n external-secrets --ignore-not-found=true
kubectl create secret generic vault-token \
  --from-literal=token="$ROOT_TOKEN" \
  -n external-secrets
```

## Verification

After recovery, verify everything is working:

```bash
# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# List secrets
kubectl exec -n vault vault-0 -- vault kv list secret/

# Check External Secrets
kubectl get externalsecrets -A

# Check synced secrets
kubectl get secrets -A | grep -E "(grafana|canopy|swimto|journey)"

# Access Vault UI
kubectl port-forward -n vault svc/vault 8200:8200
# Then visit: https://localhost:8200
```

## Troubleshooting

### Recovery Script Fails

1. **Check cluster connectivity:**
   ```bash
   kubectl cluster-info
   ```

2. **Check Vault pod logs:**
   ```bash
   kubectl logs -n vault vault-0
   ```

3. **Check HelmRelease status:**
   ```bash
   kubectl describe helmrelease vault -n vault
   ```

4. **Check PVC:**
   ```bash
   kubectl get pvc -n vault
   kubectl describe pvc data-vault-0 -n vault
   ```

### Unseal Keys Not Working

- Verify you're using the correct keys from the backup
- Check if Vault was reinitialized (new keys generated)
- Ensure you're using base64 keys (not hex)

### Secrets Not Restoring

- Verify backup file is valid JSON: `jq . vault-backup-20251115-163624.json`
- Check Vault is unsealed and logged in
- Verify backup file path is correct

### External Secrets Not Syncing

- Check External Secrets Operator logs:
  ```bash
  kubectl logs -n external-secrets deployment/external-secrets
  ```

- Verify token secret exists:
  ```bash
  kubectl get secret vault-token -n external-secrets
  ```

- Check ExternalSecret resources:
  ```bash
  kubectl get externalsecrets -A
  kubectl describe externalsecret <name> -n <namespace>
  ```

## Prevention

To avoid needing recovery:

1. **Regular Backups:**
   ```bash
   ./scripts/operations/backup-vault-secrets.sh > vault-backup-$(date +%Y%m%d-%H%M%S).json
   ```

2. **Save Credentials Securely:**
   - Store unseal keys in password manager
   - Keep backup files in secure location
   - Document backup locations

3. **Monitor Vault Status:**
   ```bash
   # Add to monitoring
   kubectl exec -n vault vault-0 -- vault status
   ```

## Related Documentation

- [VAULT.md](../VAULT.md) - Complete Vault documentation
- [VAULT_DEPLOYMENT_SUCCESS.md](../VAULT_DEPLOYMENT_SUCCESS.md) - Deployment details
- [VAULT_MIGRATION.md](VAULT_MIGRATION.md) - Migration guide

