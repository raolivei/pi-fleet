# Fixing Current Issues

## Issues Found

1. **GHCR Secret Missing**: `ghcr-secret` not synced (ExternalSecret can't connect to Vault)
2. **Image Pull Error**: `pitanga-website` pod can't pull image (needs GHCR secret)
3. **Vault Connection Timeout**: ClusterSecretStore can't validate Vault connection

## Solutions

### Option 1: Fix Vault Connection (Recommended)

The ClusterSecretStore is timing out. Check the vault-token secret:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check if vault-token secret exists
kubectl get secret vault-token -n external-secrets

# If missing, create it (need Vault root token)
# Get Vault root token from your Vault setup
kubectl create secret generic vault-token \
  --from-literal=token='YOUR_VAULT_ROOT_TOKEN' \
  -n external-secrets
```

### Option 2: Store GHCR Token in Vault

The ExternalSecret expects the token at `secret/pitanga/ghcr-token`:

```bash
export KUBECONFIG=~/.kube/config-eldertree
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Create GitHub Personal Access Token with 'read:packages' permission
# Then store it in Vault:
kubectl exec -n vault $VAULT_POD -- vault kv put secret/pitanga/ghcr-token token='YOUR_GITHUB_TOKEN'
```

### Option 3: Create GHCR Secret Manually (Quick Fix)

If Vault connection can't be fixed immediately, create the secret manually:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Create GitHub Personal Access Token with 'read:packages' permission
# Then create the secret:
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password='YOUR_GITHUB_TOKEN' \
  -n pitanga
```

### Option 4: Make Image Public (Temporary)

If the image is public, you can remove the imagePullSecrets requirement:

```bash
# Edit deployment to remove imagePullSecrets
kubectl edit deployment pitanga-website -n pitanga
# Remove the imagePullSecrets section
```

## Quick Fix Commands

**If you have a GitHub token ready:**

```bash
export KUBECONFIG=~/.kube/config-eldertree
GITHUB_TOKEN='your-token-here'

# Option A: Store in Vault (if Vault connection works)
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- vault kv put secret/pitanga/ghcr-token token="$GITHUB_TOKEN"

# Option B: Create secret directly (faster)
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password="$GITHUB_TOKEN" \
  -n pitanga

# Then restart pods
kubectl rollout restart deployment/pitanga-website -n pitanga
kubectl rollout restart deployment/northwaysignal-website -n pitanga
```

## Verify Fix

After applying the fix:

```bash
# Check secret exists
kubectl get secret ghcr-secret -n pitanga

# Check pods are pulling images
kubectl get pods -n pitanga

# Watch pod status
kubectl get pods -n pitanga -w
```

## Next: Certificate Sync

Once GHCR secret is fixed, address the certificate sync:

```bash
# Check ExternalSecret
kubectl describe externalsecret pitanga-cloudflare-origin-cert -n pitanga

# If Vault connection is still failing, manually create the TLS secret:
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
CERT=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=certificate secret/pitanga/cloudflare-origin-cert)
KEY=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=private-key secret/pitanga/cloudflare-origin-cert)

kubectl create secret tls pitanga-cloudflare-origin-tls \
  --cert=<(echo "$CERT") \
  --key=<(echo "$KEY") \
  -n pitanga
```
