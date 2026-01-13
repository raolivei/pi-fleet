# Deployment Status and Next Steps

## ✅ Completed

1. **Image Published**: `ghcr.io/raolivei/pitanga-website:latest` (multi-platform: amd64+arm64)
2. **Deployments Created**: Both `pitanga-website` and `northwaysignal-website` deployments exist
3. **Services Created**: Services are configured
4. **Ingress Created**: Ingress resources are configured with TLS
5. **Build Fixed**: Trivy scan fixed (multi-platform build)

## ❌ Current Issues

### 1. GHCR Secret Missing (BLOCKING)

**Problem**: Pods can't pull images - `ghcr-secret` doesn't exist in Kubernetes

**Error**:

```
Error: ImagePullBackOff
Failed to pull image "ghcr.io/raolivei/pitanga-website:latest":
failed to authorize: 401 Unauthorized
```

**Root Cause**: ExternalSecret can't sync from Vault because:

- ClusterSecretStore can't connect to Vault (timeout)
- Token might not exist in Vault at `secret/pitanga/ghcr-token`

**Quick Fix** (Manual secret creation):

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Create GitHub Personal Access Token with 'read:packages' permission
# Then create the secret:
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password='YOUR_GITHUB_TOKEN' \
  -n pitanga

# Restart deployments
kubectl rollout restart deployment/pitanga-website -n pitanga
kubectl rollout restart deployment/northwaysignal-website -n pitanga
```

**Proper Fix** (Store in Vault):

```bash
export KUBECONFIG=~/.kube/config-eldertree
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Store token in Vault
kubectl exec -n vault $VAULT_POD -- vault kv put secret/pitanga/ghcr-token token='YOUR_GITHUB_TOKEN'

# Then fix Vault connection (see issue #2)
```

### 2. Vault Connection Timeout (BLOCKING)

**Problem**: ClusterSecretStore can't validate Vault connection

**Error**:

```
Status: ValidationFailed
Message: unable to validate store: invalid vault credentials: context deadline exceeded
```

**Check**:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check ClusterSecretStore
kubectl describe clustersecretstore vault

# Check vault-token secret
kubectl get secret vault-token -n external-secrets

# Test Vault connection manually
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- vault status
```

**Fix**: Ensure `vault-token` secret exists in `external-secrets` namespace with valid Vault root token

### 3. Certificate Not Synced (NON-BLOCKING for HTTP)

**Problem**: TLS secret `pitanga-cloudflare-origin-tls` doesn't exist

**Impact**: HTTPS won't work, but HTTP will (if pods are running)

**Fix**: Once Vault connection is fixed, ExternalSecret will sync automatically. Or create manually:

```bash
export KUBECONFIG=~/.kube/config-eldertree
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

CERT=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=certificate secret/pitanga/cloudflare-origin-cert)
KEY=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=private-key secret/pitanga/cloudflare-origin-cert)

kubectl create secret tls pitanga-cloudflare-origin-tls \
  --cert=<(echo "$CERT") \
  --key=<(echo "$KEY") \
  -n pitanga
```

## 🎯 Priority Actions

### Immediate (To get deployments running):

1. **Create GHCR secret manually** (see Quick Fix above)
2. **Restart deployments** to pull images
3. **Verify pods are running**

### Next (To enable automatic sync):

1. **Fix Vault connection** (ClusterSecretStore validation)
2. **Store GHCR token in Vault** at `secret/pitanga/ghcr-token`
3. **Verify ExternalSecrets sync**

### Then (To enable HTTPS):

1. **Fix certificate sync** (once Vault is working)
2. **Test HTTPS** on both domains

## Verification Commands

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check deployments
kubectl get deployments -n pitanga

# Check pods
kubectl get pods -n pitanga

# Check services
kubectl get services -n pitanga

# Check ingress
kubectl get ingress -n pitanga

# Check secrets
kubectl get secrets -n pitanga

# Check ExternalSecrets
kubectl get externalsecrets -n pitanga

# Watch pod logs
kubectl logs -f deployment/pitanga-website -n pitanga
kubectl logs -f deployment/northwaysignal-website -n pitanga
```

## Expected Final State

- ✅ Both deployments: `READY 1/1`
- ✅ Both pods: `Running`
- ✅ GHCR secret exists
- ✅ TLS secret exists
- ✅ Ingress shows TLS configured
- ✅ HTTPS works: `https://pitanga.cloud` and `https://northwaysignal.pitanga.cloud`
