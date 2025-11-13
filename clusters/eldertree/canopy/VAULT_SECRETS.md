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

**Vault UI**: https://vault.eldertree.local/ui/vault/secrets/secret/kv/canopy/ghcr-token/details

### 2. PostgreSQL Password

**Vault Path**: `secret/kv/canopy/postgres`  
**Key**: `password`  
**Purpose**: PostgreSQL database password for canopy user  
**Status**: ⚠️ Needs to be stored in Vault

**Vault Path**: `secret/kv/canopy/postgres`  
**Key**: `password`  
**Value**: `0J9E7DwcsBQkcHim8OobTTugNcgahUFPjChVeIC4XEw=`

**Store in Vault via UI**:
1. Go to: https://vault.eldertree.local/ui/vault/secrets/secret/kv/canopy/postgres/create
2. Add key: `password`
3. Add value: `0J9E7DwcsBQkcHim8OobTTugNcgahUFPjChVeIC4XEw=`
4. Click "Save"

**Store in Vault via CLI**:
```bash
export VAULT_ADDR=https://vault.eldertree.local
export VAULT_SKIP_VERIFY=true
# Authenticate first: vault auth -method=userpass username=your_username
vault kv put secret/kv/canopy/postgres password="0J9E7DwcsBQkcHim8OobTTugNcgahUFPjChVeIC4XEw="
```

### 3. Application Secret Key

**Vault Path**: `secret/kv/canopy/app`  
**Key**: `secret-key`  
**Purpose**: Application secret key for encryption/signing  
**Status**: ⚠️ Needs to be stored in Vault

**Vault Path**: `secret/kv/canopy/app`  
**Key**: `secret-key`  
**Value**: `dC0L6hlYisylorwu2tDJBVcUqOv18U57PuXYPWwgdhU`

**Store in Vault via UI**:
1. Go to: https://vault.eldertree.local/ui/vault/secrets/secret/kv/canopy/app/create
2. Add key: `secret-key`
3. Add value: `dC0L6hlYisylorwu2tDJBVcUqOv18U57PuXYPWwgdhU`
4. Click "Save"

**Store in Vault via CLI**:
```bash
export VAULT_ADDR=https://vault.eldertree.local
export VAULT_SKIP_VERIFY=true
# Authenticate first: vault auth -method=userpass username=your_username
vault kv put secret/kv/canopy/app secret-key="dC0L6hlYisylorwu2tDJBVcUqOv18U57PuXYPWwgdhU"
```

### 4. Database URL

**Vault Path**: `secret/kv/canopy/database`  
**Key**: `url`  
**Purpose**: Complete PostgreSQL connection string  
**Status**: ⚠️ Needs to be stored in Vault (derived from postgres password)

**Vault Path**: `secret/kv/canopy/database`  
**Key**: `url`  
**Value**: `postgresql+psycopg://canopy:0J9E7DwcsBQkcHim8OobTTugNcgahUFPjChVeIC4XEw=@canopy-postgres:5432/canopy`

**Store in Vault via UI**:
1. Go to: https://vault.eldertree.local/ui/vault/secrets/secret/kv/canopy/database/create
2. Add key: `url`
3. Add value: `postgresql+psycopg://canopy:0J9E7DwcsBQkcHim8OobTTugNcgahUFPjChVeIC4XEw=@canopy-postgres:5432/canopy`
4. Click "Save"

**Store in Vault via CLI**:
```bash
export VAULT_ADDR=https://vault.eldertree.local
export VAULT_SKIP_VERIFY=true
# Authenticate first: vault auth -method=userpass username=your_username
vault kv put secret/kv/canopy/database url="postgresql+psycopg://canopy:0J9E7DwcsBQkcHim8OobTTugNcgahUFPjChVeIC4XEw=@canopy-postgres:5432/canopy"
```

## Complete Vault Setup

### Quick Setup via Vault UI

1. **PostgreSQL Password**:
   - Path: https://vault.eldertree.local/ui/vault/secrets/secret/kv/canopy/postgres/create
   - Key: `password`
   - Value: `0J9E7DwcsBQkcHim8OobTTugNcgahUFPjChVeIC4XEw=`

2. **Application Secret Key**:
   - Path: https://vault.eldertree.local/ui/vault/secrets/secret/kv/canopy/app/create
   - Key: `secret-key`
   - Value: `dC0L6hlYisylorwu2tDJBVcUqOv18U57PuXYPWwgdhU`

3. **Database URL**:
   - Path: https://vault.eldertree.local/ui/vault/secrets/secret/kv/canopy/database/create
   - Key: `url`
   - Value: `postgresql+psycopg://canopy:0J9E7DwcsBQkcHim8OobTTugNcgahUFPjChVeIC4XEw=@canopy-postgres:5432/canopy`

4. **GHCR Token**: ✅ Already stored
   - Path: https://vault.eldertree.local/ui/vault/secrets/secret/kv/canopy/ghcr-token/details

### Setup via CLI (requires authentication)

```bash
export VAULT_ADDR=https://vault.eldertree.local
export VAULT_SKIP_VERIFY=true
# Authenticate: vault auth -method=userpass username=your_username

# Store secrets
vault kv put secret/kv/canopy/postgres password="0J9E7DwcsBQkcHim8OobTTugNcgahUFPjChVeIC4XEw="
vault kv put secret/kv/canopy/app secret-key="dC0L6hlYisylorwu2tDJBVcUqOv18U57PuXYPWwgdhU"
vault kv put secret/kv/canopy/database url="postgresql+psycopg://canopy:0J9E7DwcsBQkcHim8OobTTugNcgahUFPjChVeIC4XEw=@canopy-postgres:5432/canopy"
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
