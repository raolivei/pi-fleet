# Vault Deployment Success - November 23, 2025

## ✅ Deployment Status: COMPLETE

Vault has been successfully deployed to the **eldertree** cluster with persistent storage enabled and policy-based access control configured.

## 📊 Deployment Details

- **Cluster**: eldertree
- **Namespace**: vault
- **Version**: 1.17.2
- **Storage**: 10Gi persistent volume (local-path)
- **Storage Type**: file
- **HA Enabled**: false (standalone mode)
- **Status**: Initialized and Unsealed
- **Policies**: ✅ Configured (per-project isolation enabled)

## 🔒 Vault Credentials

**⚠️ CRITICAL: Save these credentials securely in your password manager!**

### Unseal Keys (Need 3 of 5 to unseal)

```
Unseal Key 1: lVfUeZWUjz2TmR6BAUBv3zf0li6BqAb6kxec5juUWxej
Unseal Key 2: h09gkFGcFYDCYB6lFCPKaVaSw7HwLg3PygB7RcAz1dFi
Unseal Key 3: XHNZETftvaeGxVFnIZtdxUyiIgbq3CEHf6a4rWMY3hAp
Unseal Key 4: 0f4TnvlALgAuNlx/FF+tjbQVW5z1xKpuKtTmg2eePgg6
Unseal Key 5: DzXrpUygnHJiLND/D6jUG/N2v1UOWdJoHIxgsMrOtbuc
```

**Backup Location**: `backups/vault-20251123-032746/vault-init.json`

### Root Token

```
⚠️ CRITICAL: Root token is stored securely in password manager
⚠️ DO NOT commit actual tokens to Git
⚠️ Retrieve token from secure storage when needed
```

**Location**: Stored in Kubernetes secret `vault-token` in the `external-secrets` namespace for External Secrets Operator use.

**Backup Location**: `backups/vault-20251123-032746/vault-init.json`

## 🔐 Policy-Based Access Control

Vault now uses per-project policies to prevent cross-project secret access. Each project has its own service token with limited permissions.

### Policies Created

- `canopy-policy` - Access to `secret/canopy/*`
- `swimto-policy` - Access to `secret/swimto/*`
- `journey-policy` - Access to `secret/journey/*`
- `nima-policy` - Access to `secret/nima/*`
- `us-law-severity-map-policy` - Access to `secret/us-law-severity-map/*`
- `monitoring-policy` - Access to `secret/monitoring/*`
- `infrastructure-policy` - Access to infrastructure secrets
- `eso-readonly-policy` - Read-only access for External Secrets Operator

### Service Tokens

Project-specific tokens are stored in Kubernetes secrets in the `external-secrets` namespace:

- `vault-token-canopy`
- `vault-token-swimto`
- `vault-token-journey`
- `vault-token-nima`
- `vault-token-us-law-severity-map`
- `vault-token-monitoring`
- `vault-token-infrastructure`

**Usage**: Project scripts should use their project-specific token instead of the root token.

### GitHub Container Registry Tokens

GitHub tokens are stored in Vault for each project:

- `secret/swimto/ghcr-token`
- `secret/us-law-severity-map/ghcr-token`
- `secret/nima/ghcr-token`
- `secret/canopy/ghcr-token`

## 💾 Persistent Storage

- **PVC**: data-vault-0
- **Volume**: pvc-b69948a2-3c66-4990-9322-4f201c5075b4
- **Capacity**: 10Gi
- **Access Mode**: ReadWriteOnce (RWO)
- **Storage Class**: local-path
- **Node**: eldertree
- **Mount Path**: /vault/data

## 🚀 Next Steps

### 1. Setup External Secrets Operator

The vault-token secret for External Secrets Operator is already configured:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Verify token secret exists
kubectl get secret vault-token -n external-secrets
```

### 2. Configure Secrets in Vault

Login to Vault and configure your secrets:

```bash
# Login to Vault (get token from Kubernetes secret or password manager)
ROOT_TOKEN=$(kubectl get secret vault-token -n external-secrets -o jsonpath='{.data.token}' | base64 -d)
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN

# Example: Set Grafana admin password
kubectl exec -n vault vault-0 -- vault kv put secret/monitoring/grafana adminUser=admin adminPassword=yourpassword

# Example: Set Canopy secrets
kubectl exec -n vault vault-0 -- vault kv put secret/canopy/postgres password=yourpassword
kubectl exec -n vault vault-0 -- vault kv put secret/canopy/app secret-key=your-secret-key
```

See [VAULT.md](VAULT.md) for complete list of secret paths.

### 3. Setup Vault Policies (Already Completed)

Policies and service tokens have been created. To recreate them:

```bash
export KUBECONFIG=~/.kube/config-eldertree
export SWIMTO_GHCR_TOKEN="your-token"
export US_LAW_SEVERITY_MAP_GHCR_TOKEN="your-token"
export NIMA_GHCR_TOKEN="your-token"
export CANOPY_GHCR_TOKEN="your-token"
./scripts/operations/setup-vault-policies.sh
```

### 4. After Raspberry Pi Restart

When your Raspberry Pi reboots, Vault will start in a **sealed state**. Run:

```bash
export KUBECONFIG=~/.kube/config-eldertree
./scripts/operations/unseal-vault.sh
```

Or manually unseal with 3 keys:

```bash
kubectl exec -n vault vault-0 -- vault operator unseal lVfUeZWUjz2TmR6BAUBv3zf0li6BqAb6kxec5juUWxej
kubectl exec -n vault vault-0 -- vault operator unseal h09gkFGcFYDCYB6lFCPKaVaSw7HwLg3PygB7RcAz1dFi
kubectl exec -n vault vault-0 -- vault operator unseal XHNZETftvaeGxVFnIZtdxUyiIgbq3CEHf6a4rWMY3hAp
```

## 📝 Backup and Restore

### Backup Secrets

```bash
./scripts/operations/backup-vault-secrets.sh > vault-backup-$(date +%Y%m%d-%H%M%S).json
```

**Current Backup**: `backups/vault-20251123-032746/`

### Restore Secrets

```bash
./scripts/operations/restore-vault-secrets.sh vault-backup-20251123-032746.json
```

## 🔍 Verification Commands

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check pod status
kubectl get pods -n vault

# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# Check persistent volume
kubectl get pvc -n vault

# List all policies
kubectl exec -n vault vault-0 -- vault policy list

# Check service tokens
kubectl get secrets -n external-secrets | grep vault-token

# Access Vault UI
kubectl port-forward -n vault svc/vault 8200:8200
# Then visit: https://localhost:8200
```

## 📚 Documentation

- [VAULT.md](VAULT.md) - Complete Vault documentation with policy-based access control
- [docs/VAULT_MIGRATION.md](docs/VAULT_MIGRATION.md) - Migration guide
- [scripts/operations/setup-vault-policies.sh](scripts/operations/setup-vault-policies.sh) - Policy setup script

## ⚠️ Security Reminders

1. **Save unseal keys and root token in your password manager immediately**
2. **Backup secrets regularly** - Run `./scripts/operations/backup-vault-secrets.sh`
3. **Never commit credentials to Git**
4. **Unseal Vault after each Raspberry Pi reboot**
5. **Use project-specific tokens** - Don't use root token in project scripts
6. **Policies prevent cross-project access** - Each project can only access its own secrets

## 🎯 Recent Updates (November 23, 2025)

- ✅ Implemented policy-based access control
- ✅ Created per-project service tokens
- ✅ Stored GitHub Container Registry tokens in Vault
- ✅ Updated project scripts to use project-specific tokens
- ✅ Enhanced security with least-privilege access

---

**Deployment Date**: November 17, 2025  
**Last Updated**: November 23, 2025  
**Deployed By**: Cursor AI Assistant  
**Cluster**: eldertree (Raspberry Pi k3s)
