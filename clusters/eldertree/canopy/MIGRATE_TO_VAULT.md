# Migrate Canopy Secrets to Vault

This guide helps you migrate all Canopy secrets from Kubernetes to Vault.

## Current Secrets

The following secrets currently exist in Kubernetes and need to be migrated to Vault:

1. **canopy-secrets** (Opaque)
   - `postgres-password`: [Get from current Kubernetes secret]
   - `secret-key`: [Get from current Kubernetes secret]
   - `database-url`: [Get from current Kubernetes secret]

2. **ghcr-secret** (dockerconfigjson)
   - Token: [Already stored in Vault ✅]

## Migration Steps

### Step 1: Store Secrets in Vault

Run these commands to store all secrets in Vault:

```bash
# Get current values from Kubernetes secrets
export KUBECONFIG=~/.kube/config-eldertree
POSTGRES_PASSWORD=$(kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.postgres-password}' | base64 -d)
SECRET_KEY=$(kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.secret-key}' | base64 -d)
DATABASE_URL=$(kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.database-url}' | base64 -d)

# Store in Vault
vault kv put secret/kv/canopy/postgres password="$POSTGRES_PASSWORD"
vault kv put secret/kv/canopy/app secret-key="$SECRET_KEY"
vault kv put secret/kv/canopy/database url="$DATABASE_URL"

# GHCR Token (already stored, verify if needed)
# vault kv get secret/kv/canopy/ghcr-token
```

### Step 2: Verify Secrets in Vault

```bash
# List all Canopy secrets
vault kv list secret/kv/canopy/

# Verify each secret
vault kv get secret/kv/canopy/postgres
vault kv get secret/kv/canopy/app
vault kv get secret/kv/canopy/database
vault kv get secret/kv/canopy/ghcr-token
```

### Step 3: Update Kubernetes Secrets from Vault

Use the sync script to update Kubernetes secrets from Vault:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/canopy
./sync-secrets.sh
```

Or manually sync:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Get secrets from Vault
POSTGRES_PASSWORD=$(vault kv get -field=password secret/kv/canopy/postgres)
SECRET_KEY=$(vault kv get -field=secret-key secret/kv/canopy/app)
DATABASE_URL=$(vault kv get -field=url secret/kv/canopy/database)
GHCR_TOKEN=$(vault kv get -field=token secret/kv/canopy/ghcr-token)

# Update canopy-secrets
kubectl create secret generic canopy-secrets \
  --namespace canopy \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=secret-key="$SECRET_KEY" \
  --from-literal=database-url="$DATABASE_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

# Update ghcr-secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password="$GHCR_TOKEN" \
  --namespace canopy \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Step 4: Verify Deployment

After syncing secrets, verify pods are running:

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get pods -n canopy
kubectl get secrets -n canopy
```

## Post-Migration

After migration is complete:

1. ✅ All secrets stored in Vault
2. ✅ Kubernetes secrets synced from Vault
3. ✅ Application running successfully
4. ✅ Remove any local secret files or scripts that contain plaintext secrets
5. ✅ Use `sync-secrets.sh` for future secret updates

## Future Secret Updates

To update secrets in the future:

1. Update secret in Vault:
   ```bash
   vault kv put secret/kv/canopy/postgres password="NEW_PASSWORD"
   ```

2. Sync to Kubernetes:
   ```bash
   ./sync-secrets.sh
   ```

3. Restart pods if needed:
   ```bash
   kubectl rollout restart deployment -n canopy
   ```

## Security Best Practices

- ✅ **Vault is the source of truth** - Never store secrets in git or local files
- ✅ **Rotate secrets regularly** - Update in Vault and re-sync
- ✅ **Limit Vault access** - Use proper authentication and authorization
- ✅ **Audit secret access** - Monitor Vault audit logs
- ✅ **Use External Secrets Operator** - For automatic syncing (optional)

