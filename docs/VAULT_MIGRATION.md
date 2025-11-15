# Vault Migration to Production Mode

This guide walks you through migrating Vault from dev mode (no persistence) to production mode with persistent storage.

## Overview

**Dev Mode Issues:**
- ❌ Secrets lost on pod restart
- ❌ New root token generated each restart
- ❌ External Secrets Operator breaks after restart

**Production Mode Benefits:**
- ✅ Secrets persist across restarts
- ✅ Stable root token and unseal keys
- ✅ Production-ready security model

## Prerequisites

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config-eldertree

# Backup existing secrets (CRITICAL - do this first!)
./scripts/backup-vault-secrets.sh
```

## Migration Steps

### 1. Apply Updated Vault Configuration

The Vault HelmRelease has been updated to enable persistence. Flux will automatically detect and apply the changes.

```bash
# Check if Flux has detected the changes
kubectl get helmrelease -n vault vault

# Force reconciliation if needed
flux reconcile helmrelease vault -n vault

# Watch the rollout
kubectl get pods -n vault -w
```

**Note:** The pod will recreate with a new StatefulSet and PersistentVolumeClaim.

### 2. Initialize Vault (One-Time Setup)

Once the new pod is running, you need to initialize Vault:

```bash
# Check pod status
kubectl get pods -n vault

# Initialize Vault (one-time only)
kubectl exec -n vault vault-0 -- vault operator init
```

**CRITICAL:** Save the output! You'll receive:
- **5 Unseal Keys** - Need 3 of 5 to unseal Vault after restarts
- **1 Initial Root Token** - Use this to authenticate

Example output:
```
Unseal Key 1: AbCdEfGh...
Unseal Key 2: IjKlMnOp...
Unseal Key 3: QrStUvWx...
Unseal Key 4: YzAbCdEf...
Unseal Key 5: GhIjKlMn...

Initial Root Token: hvs.EXAMPLE_TOKEN_SAVE_THIS_SECURELY
```

**⚠️ SECURITY:** Store these keys securely! Consider:
- Password manager (1Password, Bitwarden)
- Encrypted file
- Physical secure location
- Split keys among trusted individuals

### 3. Unseal Vault

After initialization (and after every restart), Vault needs to be unsealed:

```bash
# Unseal with 3 different keys (you'll be prompted for each)
kubectl exec -n vault vault-0 -- vault operator unseal
# Enter Unseal Key 1

kubectl exec -n vault vault-0 -- vault operator unseal
# Enter Unseal Key 2

kubectl exec -n vault vault-0 -- vault operator unseal
# Enter Unseal Key 3

# Verify Vault is unsealed
kubectl exec -n vault vault-0 -- vault status
```

**Tip:** Use the provided script for easier unsealing:
```bash
./scripts/unseal-vault.sh
```

### 4. Restore Secrets

Now that Vault is initialized and unsealed, restore your secrets:

```bash
# Login with root token
kubectl exec -n vault vault-0 -- vault login
# Enter your Initial Root Token

# Restore secrets from backup
./scripts/restore-vault-secrets.sh

# Or manually restore each secret:
kubectl exec -n vault vault-0 -- vault kv put secret/monitoring/grafana adminUser=admin adminPassword=yourpassword
# ... (repeat for all secrets)
```

### 5. Update External Secrets Operator Token

External Secrets Operator needs the new root token:

```bash
# Delete old token secret
kubectl delete secret vault-token -n external-secrets

# Create new token secret with your root token
kubectl create secret generic vault-token \
  --from-literal=token=YOUR_ROOT_TOKEN_HERE \
  -n external-secrets

# Restart External Secrets Operator
kubectl rollout restart deployment -n external-secrets
```

### 6. Verify Everything Works

```bash
# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# List secrets
kubectl exec -n vault vault-0 -- vault kv list secret/

# Check External Secrets sync
kubectl get externalsecrets -A

# Verify a synced secret
kubectl get secret grafana-admin -n monitoring -o yaml
```

## After Raspberry Pi Restarts

When your Raspberry Pi reboots, Vault will start in a **sealed state**. You need to unseal it:

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config-eldertree

# Wait for Vault pod to be ready
kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=300s

# Unseal Vault (requires 3 keys)
./scripts/unseal-vault.sh

# Verify unsealed
kubectl exec -n vault vault-0 -- vault status
```

**Note:** External Secrets Operator will automatically resume syncing once Vault is unsealed.

## Auto-Unseal (Future Enhancement)

For automatic unsealing after restarts, consider:
- **Cloud KMS** (AWS KMS, GCP Cloud KMS, Azure Key Vault)
- **Transit Auto-Unseal** (requires second Vault cluster)
- **Kubernetes Secrets** (less secure but convenient for homelab)

See: https://developer.hashicorp.com/vault/docs/concepts/seal#auto-unseal

## Troubleshooting

### Pod Stuck in Init

```bash
# Check logs
kubectl logs -n vault vault-0

# Check PVC
kubectl get pvc -n vault
```

### Unseal Not Working

```bash
# Check seal status
kubectl exec -n vault vault-0 -- vault status

# Verify you're using correct keys
# Each key must be different (3 of the 5 keys)
```

### External Secrets Not Syncing

```bash
# Check External Secrets Operator logs
kubectl logs -n external-secrets deployment/external-secrets

# Verify ClusterSecretStore
kubectl get clustersecretstore vault -o yaml

# Check token secret
kubectl get secret vault-token -n external-secrets
```

### Lost Unseal Keys

If you lose unseal keys, you must:
1. Delete the Vault PVC (⚠️ destroys all secrets)
2. Re-initialize Vault
3. Re-enter all secrets

**Prevention:** Always backup unseal keys securely!

## Backup Strategy

### Manual Backup

```bash
# Export all secrets to file
./scripts/backup-vault-secrets.sh > vault-backup-$(date +%Y%m%d).json
```

### Automated Backup

Consider setting up a CronJob:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vault-backup
  namespace: vault
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: vault:1.15.0
            command: ["/bin/sh"]
            args: ["-c", "vault kv get -format=json secret/ > /backup/vault-$(date +%Y%m%d).json"]
            # ... mount backup volume
```

## References

- [HashiCorp Vault Production Hardening](https://developer.hashicorp.com/vault/tutorials/operations/production-hardening)
- [Vault on Kubernetes Deployment Guide](https://developer.hashicorp.com/vault/docs/platform/k8s)
- [Vault Storage Backends](https://developer.hashicorp.com/vault/docs/configuration/storage)

