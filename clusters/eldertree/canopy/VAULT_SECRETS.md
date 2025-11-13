# Canopy Secrets in Vault

All Canopy secrets must be stored in Vault. This document provides the complete list and storage instructions.

## Vault Path Structure

All Canopy secrets are stored under: `secret/kv/canopy/`

## Required Secrets

### 1. GHCR Token

**Vault Path**: `secret/kv/canopy/ghcr-token`  
**Key**: `token`  
**Purpose**: GitHub Container Registry authentication for pulling Docker images  
**Status**: ✅ Already stored in Vault

**Current Value**: [Stored in Vault - retrieve with: `vault kv get secret/kv/canopy/ghcr-token`]

### 2. PostgreSQL Password

**Vault Path**: `secret/kv/canopy/postgres`  
**Key**: `password`  
**Purpose**: PostgreSQL database password for canopy user  
**Status**: ⚠️ Needs to be stored in Vault

**Current Value**: [Get from Kubernetes secret: `kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.postgres-password}' | base64 -d`]

**Store in Vault**:
```bash
# Get from current Kubernetes secret
POSTGRES_PASSWORD=$(kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.postgres-password}' | base64 -d)
vault kv put secret/kv/canopy/postgres password="$POSTGRES_PASSWORD"
```

### 3. Application Secret Key

**Vault Path**: `secret/kv/canopy/app`  
**Key**: `secret-key`  
**Purpose**: Application secret key for encryption/signing  
**Status**: ⚠️ Needs to be stored in Vault

**Current Value**: [Get from Kubernetes secret: `kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.secret-key}' | base64 -d`]

**Store in Vault**:
```bash
# Get from current Kubernetes secret
SECRET_KEY=$(kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.secret-key}' | base64 -d)
vault kv put secret/kv/canopy/app secret-key="$SECRET_KEY"
```

### 4. Database URL

**Vault Path**: `secret/kv/canopy/database`  
**Key**: `url`  
**Purpose**: Complete PostgreSQL connection string  
**Status**: ⚠️ Needs to be stored in Vault (derived from postgres password)

**Current Value**: [Get from Kubernetes secret: `kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.database-url}' | base64 -d`]

**Store in Vault**:
```bash
# Get from current Kubernetes secret
DATABASE_URL=$(kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.database-url}' | base64 -d)
vault kv put secret/kv/canopy/database url="$DATABASE_URL"
```

## Complete Vault Setup

Run all commands to store secrets in Vault:

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

# GHCR Token (already stored - verify if needed)
# vault kv get secret/kv/canopy/ghcr-token
```

## Vault UI Access

Access Vault UI at: https://vault.eldertree.local/ui/vault/secrets/secret/kv/canopy

## Syncing Secrets from Vault to Kubernetes

### Option 1: External Secrets Operator (Recommended)

If External Secrets Operator is installed, create ExternalSecret resources:

```yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: canopy-secrets
  namespace: canopy
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: canopy-secrets
    creationPolicy: Owner
  data:
  - secretKey: postgres-password
    remoteRef:
      key: secret/kv/canopy/postgres
      property: password
  - secretKey: secret-key
    remoteRef:
      key: secret/kv/canopy/app
      property: secret-key
  - secretKey: database-url
    remoteRef:
      key: secret/kv/canopy/database
      property: url

---
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
      key: secret/kv/canopy/ghcr-token
      property: token
```

### Option 2: Manual Sync Script

Create a script to sync secrets from Vault:

```bash
#!/bin/bash
# sync-canopy-secrets.sh
# Syncs Canopy secrets from Vault to Kubernetes

export KUBECONFIG=~/.kube/config-eldertree

# Get secrets from Vault
POSTGRES_PASSWORD=$(vault kv get -field=password secret/kv/canopy/postgres)
SECRET_KEY=$(vault kv get -field=secret-key secret/kv/canopy/app)
DATABASE_URL=$(vault kv get -field=url secret/kv/canopy/database)
GHCR_TOKEN=$(vault kv get -field=token secret/kv/canopy/ghcr-token)

# Create canopy-secrets
kubectl create secret generic canopy-secrets \
  --namespace canopy \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=secret-key="$SECRET_KEY" \
  --from-literal=database-url="$DATABASE_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create ghcr-secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password="$GHCR_TOKEN" \
  --namespace canopy \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Security Notes

- ✅ **Never commit secrets to git** - All secrets are stored in Vault only
- ✅ **Vault is the source of truth** - Kubernetes secrets are synced from Vault
- ✅ **Rotate secrets regularly** - Update in Vault and re-sync to Kubernetes
- ✅ **Access control** - Limit Vault access to authorized personnel only

## Verification

Verify secrets are stored in Vault:

```bash
# List all Canopy secrets
vault kv list secret/kv/canopy/

# Verify each secret
vault kv get secret/kv/canopy/ghcr-token
vault kv get secret/kv/canopy/postgres
vault kv get secret/kv/canopy/app
vault kv get secret/kv/canopy/database
```

## Migration Checklist

- [x] GHCR token stored in Vault
- [ ] PostgreSQL password stored in Vault
- [ ] Application secret key stored in Vault
- [ ] Database URL stored in Vault
- [ ] External Secrets Operator configured (if using)
- [ ] Kubernetes secrets synced from Vault
- [ ] Old local secret files removed
