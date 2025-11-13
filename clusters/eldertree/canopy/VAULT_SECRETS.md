# Canopy Secrets in Vault

## GHCR Token

**Path**: `secret/canopy/ghcr-token`  
**Key**: `token`  
**Value**: `[STORED_IN_VAULT]` (see vault path below)  
**Purpose**: GitHub Container Registry authentication for pulling Docker images  
**Created**: 2025-01-XX  
**Expires**: Check GitHub token settings

### Store in Vault

```bash
# If vault CLI is configured
vault kv put secret/canopy/ghcr-token token="YOUR_GITHUB_TOKEN_HERE"

# Or via vault UI at: https://vault.eldertree.local
```

### Create Kubernetes Secret from Vault

If using External Secrets Operator or similar:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ghcr-secret
  namespace: canopy
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: ghcr-secret
    creationPolicy: Owner
  data:
  - secretKey: .dockerconfigjson
    remoteRef:
      key: secret/canopy/ghcr-token
      property: token
```

### Manual Creation

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password="YOUR_GITHUB_TOKEN_HERE" \
  --namespace canopy
```

