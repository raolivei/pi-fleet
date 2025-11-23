# Vault Quick Reference

Quick commands for common Vault operations on the eldertree cluster.

## Setup Environment

```bash
export KUBECONFIG=~/.kube/config-eldertree
```

## After Raspberry Pi Restart

**Most Common Task:** Unseal Vault after restart

```bash
./scripts/operations/unseal-vault.sh
```

You'll be prompted for 3 unseal keys. Enter them when prompted.

## Check Vault Status

```bash
# Check if Vault is sealed/unsealed
kubectl exec -n vault vault-0 -- vault status

# Quick check
kubectl get pods -n vault
```

## Backup Secrets

```bash
# Backup all secrets to JSON file
./scripts/backup-vault-secrets.sh > vault-backup-$(date +%Y%m%d).json

# Store the backup securely (contains plaintext secrets!)
```

## Restore Secrets

```bash
# Restore from backup
./scripts/restore-vault-secrets.sh vault-backup-20250115.json
```

## Access Vault UI

```bash
# Port forward to Vault UI
kubectl port-forward -n vault svc/vault 8200:8200

# Open browser: https://localhost:8200
# Login with your root token
```

## Working with Secrets

```bash
# Login to Vault
kubectl exec -n vault vault-0 -- vault login
# Enter root token

# List all secrets
kubectl exec -n vault vault-0 -- vault kv list secret/

# Read a specific secret
kubectl exec -n vault vault-0 -- vault kv get secret/monitoring/grafana

# Write/update a secret
kubectl exec -n vault vault-0 -- vault kv put secret/monitoring/grafana adminUser=admin adminPassword=newpass

# Delete a secret
kubectl exec -n vault vault-0 -- vault kv delete secret/path/to/secret
```

## Check External Secrets Sync

```bash
# List all ExternalSecrets
kubectl get externalsecrets -A

# Check specific ExternalSecret status
kubectl describe externalsecret grafana-admin -n monitoring

# Verify synced Kubernetes secret
kubectl get secret grafana-admin -n monitoring -o yaml
```

## Troubleshooting

### Vault is Sealed

```bash
# This is normal after restart
./scripts/operations/unseal-vault.sh
```

### External Secrets Not Syncing

```bash
# 1. Check if Vault is unsealed
kubectl exec -n vault vault-0 -- vault status

# 2. Check External Secrets Operator
kubectl logs -n external-secrets deployment/external-secrets

# 3. Verify token secret exists
kubectl get secret vault-token -n external-secrets
```

### Restart External Secrets Operator

```bash
kubectl rollout restart deployment -n external-secrets
```

## Important Files

- **Migration Guide:** `docs/VAULT_MIGRATION.md`
- **Full Documentation:** `VAULT.md`
- **Scripts Location:** `scripts/`

## Security Reminders

✅ **DO:**
- Store unseal keys securely (password manager)
- Backup secrets regularly
- Keep root token secret
- Unseal Vault after every restart

❌ **DON'T:**
- Commit unseal keys to git
- Share root token
- Store backups in plaintext on disk
- Forget to backup before making changes

## Emergency: Lost Unseal Keys

⚠️ If you lose your unseal keys, you **cannot** recover Vault data. You must:

1. Delete Vault PVC (destroys all secrets):
   ```bash
   kubectl delete pvc -n vault vault-data-vault-0
   ```

2. Restart Vault pod:
   ```bash
   kubectl delete pod -n vault vault-0
   ```

3. Re-initialize:
   ```bash
   kubectl exec -n vault vault-0 -- vault operator init
   ```

4. Save new keys securely

5. Re-enter all secrets or restore from backup

**Prevention:** Always backup unseal keys in multiple secure locations!

