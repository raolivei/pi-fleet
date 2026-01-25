# Vault Quick Reference

Quick commands for common Vault operations on the eldertree cluster.

**Updated:** January 13, 2026  
**Mode:** HA with Raft (3 replicas)

## Setup Environment

```bash
# Eldertree is now the default context
kubectl config use-context eldertree

# Or explicitly
export KUBECONFIG=~/.kube/config-eldertree
```

## After Raspberry Pi Restart

**Most Common Task:** Unseal all Vault pods after restart

```bash
./scripts/operations/unseal-vault.sh
```

The script automatically reads unseal keys from K8s secret and unseals all 3 pods.

## Check Vault Status

```bash
# Check all Vault pods
kubectl get pods -n vault -l component=server

# Check specific pod status
kubectl exec -n vault vault-0 -- vault status
kubectl exec -n vault vault-1 -- vault status
kubectl exec -n vault vault-2 -- vault status

# Check HA cluster status
kubectl exec -n vault vault-0 -- vault operator raft list-peers

# Check which node is leader
kubectl exec -n vault vault-0 -- vault operator raft autopilot state | head -10
```

## HA Failover Information

| Pod | Node | Role |
|-----|------|------|
| vault-0 | node-3 | Leader or Standby |
| vault-1 | node-1 | Leader or Standby |
| vault-2 | node-2 | Leader or Standby |

**Failure Tolerance:** 1 node (cluster survives any single node failure)

If the leader fails:
- A standby is automatically promoted within seconds
- No data loss (Raft replication)
- External Secrets continue syncing from new leader

## Backup Secrets

```bash
# Backup all secrets to JSON file
./scripts/operations/backup-vault-secrets.sh > vault-backup-$(date +%Y%m%d).json

# Store the backup securely (contains plaintext secrets!)
```

## Restore Secrets

```bash
# Restore from backup
./scripts/operations/restore-vault-secrets.sh vault-backup-20260113.json
```

## Access Vault UI

```bash
# Port forward to Vault UI (talks to active leader)
kubectl port-forward -n vault svc/vault 8200:8200

# Open browser: https://localhost:8200
# Login with your root token
```

## Working with Secrets

```bash
# Login to Vault (use any unsealed pod)
kubectl exec -n vault vault-0 -- vault login
# Enter root token (stored in K8s secret vault-unseal-keys)

# Get root token from K8s secret
kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.ROOT_TOKEN}' | base64 -d

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
kubectl describe externalsecret grafana-admin -n observability

# Verify synced Kubernetes secret
kubectl get secret grafana-admin -n observability -o yaml
```

## Troubleshooting

### Vault Pods are Sealed

```bash
# Normal after restart - unseal all pods
./scripts/operations/unseal-vault.sh

# Manual unseal (if script fails)
UNSEAL_KEY_1=$(kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.UNSEAL_KEY_1}' | base64 -d)
kubectl exec -n vault vault-0 -- vault operator unseal "$UNSEAL_KEY_1"
# Repeat with KEY_2 and KEY_3
```

### Check Raft Cluster Health

```bash
# List Raft peers
kubectl exec -n vault vault-0 -- vault operator raft list-peers

# Check autopilot (shows health and failure tolerance)
kubectl exec -n vault vault-0 -- vault operator raft autopilot state
```

### External Secrets Not Syncing

```bash
# 1. Check if all Vault pods are unsealed
for pod in vault-0 vault-1 vault-2; do
  echo "=== $pod ==="
  kubectl exec -n vault $pod -- vault status | grep Sealed
done

# 2. Check External Secrets Operator logs
kubectl logs -n external-secrets deployment/external-secrets

# 3. Verify token secret exists
kubectl get secret vault-token -n external-secrets

# 4. Restart External Secrets Operator
kubectl rollout restart deployment -n external-secrets external-secrets
```

### Leader Election Issues

```bash
# Force step-down of current leader (triggers re-election)
kubectl exec -n vault vault-0 -- vault operator step-down
```

## Important Files

- **HA Init Script:** `scripts/operations/init-vault-ha.sh`
- **Unseal Script:** `scripts/operations/unseal-vault.sh`
- **Backup Script:** `scripts/operations/backup-vault-secrets.sh`
- **Restore Script:** `scripts/operations/restore-vault-secrets.sh`
- **HelmRelease:** `clusters/eldertree/secrets-management/vault/helmrelease.yaml`

## Security Reminders

✅ **DO:**
- Unseal keys are stored in K8s secret `vault-unseal-keys` for auto-unseal
- Also store unseal keys securely offline (password manager)
- Backup secrets regularly
- Test failover periodically

❌ **DON'T:**
- Commit unseal keys to git
- Delete the `vault-unseal-keys` K8s secret without backup
- Store backups in plaintext on disk long-term

## Emergency: Lost Unseal Keys

⚠️ If you lose your unseal keys AND the K8s secret, you **cannot** recover Vault data.

**Check K8s secret first:**
```bash
kubectl get secret vault-unseal-keys -n vault -o yaml
```

**If K8s secret exists, extract keys:**
```bash
kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.UNSEAL_KEY_1}' | base64 -d
kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.ROOT_TOKEN}' | base64 -d
```

**If all is lost, must re-initialize:**

1. Delete all Vault PVCs:
   ```bash
   kubectl delete pvc -n vault --all
   ```

2. Delete Vault pods:
   ```bash
   kubectl delete pods -n vault -l component=server
   ```

3. Re-initialize HA cluster:
   ```bash
   ./scripts/operations/init-vault-ha.sh
   ```

4. Save new keys securely

5. Restore secrets from backup

**Prevention:** Backup both K8s secret AND offline storage!

## Initialize New HA Cluster

Only use after fresh install or disaster recovery:

```bash
./scripts/operations/init-vault-ha.sh
```This script:
1. Initializes vault-0 (generates new unseal keys)
2. Stores keys in K8s secret
3. Unseals all 3 pods
4. Joins all pods to Raft cluster
5. Enables KV secrets engine