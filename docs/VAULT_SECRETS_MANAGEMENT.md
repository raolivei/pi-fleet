# Vault Secrets Management Guide

## Overview

**All secrets MUST be stored in Vault** - never hardcode secrets in scripts, configuration files, or commit them to Git.

## Principles

1. ✅ **All secrets in Vault** - No exceptions
2. ✅ **Read from Vault** - Scripts should read secrets from Vault, not hardcode them
3. ✅ **Use External Secrets Operator** - For Kubernetes deployments, use External Secrets to sync from Vault
4. ✅ **Never commit secrets** - Use `.gitignore` for any files that might contain secrets
5. ✅ **Audit regularly** - Run `./scripts/audit-secrets.sh` to find hardcoded secrets

## Getting Secrets from Vault

### Using the Helper Script

```bash
# Get a secret value
./scripts/get-vault-secret.sh <secret-path> <key-name>

# Examples:
./scripts/get-vault-secret.sh secret/canopy/ghcr-token token
./scripts/get-vault-secret.sh secret/pi-fleet/terraform/cloudflare-api-token api-token
```

### Using kubectl exec (Direct)

```bash
# Get Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Get secret
kubectl exec -n vault $VAULT_POD -- \
  sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && \
  export VAULT_TOKEN=\$(cat /tmp/vault-init.json | jq -r '.root_token') && \
  vault kv get -format=json secret/canopy/ghcr-token | jq -r '.data.data.token'"
```

### In Scripts

**❌ DON'T:**

```bash
GITHUB_TOKEN="ghp_YOUR_TOKEN_HERE"  # Hardcoded - never do this!
```

**✅ DO:**

```bash
# Read from Vault
GITHUB_TOKEN=$(./scripts/get-vault-secret.sh secret/canopy/ghcr-token token)

# Or use environment variable (if already set from Vault)
GITHUB_TOKEN="${GITHUB_TOKEN:-$(./scripts/get-vault-secret.sh secret/canopy/ghcr-token token)}"
```

## Common Secret Paths

### GitHub Container Registry

- **Path**: `secret/canopy/ghcr-token` or `secret/pi-fleet/ghcr-token`
- **Key**: `token`
- **Usage**: For pulling/pushing Docker images to GHCR

### Cloudflare API

- **Path**: `secret/pi-fleet/terraform/cloudflare-api-token`
- **Key**: `api-token`
- **Usage**: Terraform DNS management

- **Path**: `secret/pi-fleet/external-dns/cloudflare-api-token`
- **Key**: `api-token`
- **Usage**: External-DNS Cloudflare provider

### Application Secrets

- **Path**: `secret/{app}/postgres`
- **Key**: `password`
- **Usage**: Database passwords

- **Path**: `secret/{app}/app`
- **Key**: `secret-key` or `admin-token`
- **Usage**: Application secret keys

See [VAULT.md](../VAULT.md) for complete list of secret paths.

## Setting Secrets in Vault

### Using the Setup Script

```bash
./scripts/operations/setup-vault-secrets.sh
```

### Manual Setup

```bash
# Get Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Set secret
kubectl exec -n vault $VAULT_POD -- \
  sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && \
  export VAULT_TOKEN=\$(cat /tmp/vault-init.json | jq -r '.root_token') && \
  vault kv put secret/canopy/ghcr-token token='YOUR_TOKEN_HERE'"
```

## Using Secrets in Kubernetes

### External Secrets Operator (Recommended)

Create an `ExternalSecret` resource:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ghcr-secret
  namespace: my-namespace
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: ghcr-secret
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: secret/canopy/ghcr-token
        property: token
```

Then reference in your deployment:

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
        - name: ghcr-secret
```

### Direct kubectl (Not Recommended)

Only use for one-off operations:

```bash
TOKEN=$(./scripts/get-vault-secret.sh secret/canopy/ghcr-token token)
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password="$TOKEN"
```

## Fixing Hardcoded Secrets

### Step 1: Identify the Secret

Run the audit script:

```bash
./scripts/audit-secrets.sh
```

### Step 2: Store in Vault

```bash
# Store the secret in Vault
./scripts/operations/setup-vault-secrets.sh
# Or manually:
kubectl exec -n vault $VAULT_POD -- vault kv put secret/path/to/secret key="value"
```

### Step 3: Update Scripts

Replace hardcoded values with Vault reads:

**Before:**

```bash
GITHUB_TOKEN="ghp_YOUR_TOKEN_HERE"  # Hardcoded - bad!
```

**After:**

```bash
GITHUB_TOKEN=$(./scripts/get-vault-secret.sh secret/canopy/ghcr-token token)
```

### Step 4: Verify

```bash
# Test the script
./your-script.sh

# Run audit again
./scripts/audit-secrets.sh
```

## Best Practices

1. **Always use Vault** - No hardcoded secrets, ever
2. **Use helper scripts** - `get-vault-secret.sh` for consistency
3. **Document secret paths** - Update VAULT.md when adding new secrets
4. **Audit regularly** - Run `audit-secrets.sh` before commits
5. **Use External Secrets** - For Kubernetes deployments
6. **Rotate secrets** - Update in Vault, External Secrets will sync automatically

## Troubleshooting

### Vault Not Found

```bash
# Check Vault pod
kubectl get pods -A | grep vault

# Check if unsealed
kubectl exec -n vault $VAULT_POD -- vault status
```

### Secret Not Found

```bash
# List secrets in Vault
kubectl exec -n vault $VAULT_POD -- vault kv list secret/

# Get specific secret
kubectl exec -n vault $VAULT_POD -- vault kv get secret/path/to/secret
```

### Permission Denied

Make sure you're using the root token or have proper Vault policies configured.

## References

- [Vault Documentation](../VAULT.md)
- [External Secrets Operator](https://external-secrets.io/)
- [Secret Audit Script](../scripts/audit-secrets.sh)
