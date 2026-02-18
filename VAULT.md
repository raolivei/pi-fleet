# Vault Secrets Management

Vault stores secrets for all pi-fleet projects in **production mode with persistent storage**. External Secrets Operator automatically syncs secrets from Vault to Kubernetes.

## Production Setup

**✅ Persistence Enabled:** Vault now runs in production mode with persistent storage. Secrets survive pod restarts and Raspberry Pi reboots.

**🔒 Manual Unsealing Required:** After each restart, Vault must be manually unsealed using 3 of 5 unseal keys.

## Quick Start

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config-eldertree

# After restart, unseal Vault
./scripts/operations/unseal-vault.sh

# External Secrets Operator syncs automatically
```

## Initial Setup (One-Time)

If migrating from dev mode or setting up fresh, see [VAULT_MIGRATION.md](docs/VAULT_MIGRATION.md).

### Quick Setup Steps:

1. **Initialize Vault** (one-time only):
```bash
kubectl exec -n vault vault-0 -- vault operator init
```
**⚠️ SAVE THE OUTPUT:** You'll get 5 unseal keys and 1 root token. Store these securely!

2. **Unseal Vault** (requires 3 keys):
```bash
./scripts/operations/unseal-vault.sh
```

3. **Login to Vault**:
```bash
kubectl exec -n vault vault-0 -- vault login
# Enter your root token
```

4. **Create secrets** (see Secret Paths section below)

5. **Setup External Secrets Operator**:
```bash
# Create token secret with your root token
kubectl create secret generic vault-token \
  --from-literal=token=YOUR_ROOT_TOKEN_HERE \
  -n external-secrets
```

6. **Setup Vault Policies and Service Tokens** (recommended):
```bash
# Create per-project policies and service tokens
./scripts/operations/setup-vault-policies.sh
```

This creates:
- Per-project policies (canopy, swimto, journey, nima, us-law-severity-map, monitoring, infrastructure)
- Service tokens for each project stored in Kubernetes secrets
- GitHub Container Registry tokens stored in Vault

## Policy-Based Access Control

Vault uses policies to enforce least-privilege access. Each project has its own policy that grants access only to its own secrets.

### Policies

- **canopy-policy** - Access to `secret/canopy/*`
- **swimto-policy** - Access to `secret/swimto/*`
- **journey-policy** - Access to `secret/journey/*`
- **nima-policy** - Access to `secret/nima/*`
- **us-law-severity-map-policy** - Access to `secret/us-law-severity-map/*`
- **monitoring-policy** - Access to `secret/monitoring/*`
- **infrastructure-policy** - Access to `secret/pi-fleet/*` (terraform, external-dns, cloudflare-tunnel) and legacy paths (`secret/pihole/*`, `secret/flux/*`, `secret/external-dns/*`, `secret/terraform/*`, `secret/cloudflare-tunnel/*`)
- **eso-readonly-policy** - Read-only access to all secrets (for External Secrets Operator)

### Service Tokens

Each project has a service token stored in Kubernetes secrets in the `external-secrets` namespace:

- `vault-token-canopy` - Token with `canopy-policy`
- `vault-token-swimto` - Token with `swimto-policy`
- `vault-token-journey` - Token with `journey-policy`
- `vault-token-nima` - Token with `nima-policy`
- `vault-token-us-law-severity-map` - Token with `us-law-severity-map-policy`
- `vault-token-monitoring` - Token with `monitoring-policy`
- `vault-token-infrastructure` - Token with `infrastructure-policy`

### Using Project-Specific Tokens

Project scripts should use their project-specific token instead of the root token:

```bash
# Get project token from Kubernetes secret
VAULT_TOKEN=$(kubectl get secret vault-token-swimto -n external-secrets -o jsonpath='{.data.token}' | base64 -d)

# Use token in Vault operations
kubectl exec -n vault vault-0 -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='${VAULT_TOKEN}' && vault kv put secret/swimto/app key=value"
```

### Benefits

1. **Isolation**: Each project can only access its own secrets
2. **Principle of Least Privilege**: Tokens have minimal required permissions
3. **Prevents Accidents**: Scripts cannot accidentally write to wrong project paths
4. **Auditability**: Each project's access is tracked separately

## Secret Paths

### Monitoring
- `secret/monitoring/grafana` - Grafana admin username and password (`adminUser`, `adminPassword`)

### Infrastructure (pi-fleet)
All infrastructure secrets are organized under `secret/pi-fleet/`:
- `secret/pi-fleet/terraform/cloudflare-api-token` - Cloudflare API token for Terraform DNS management (`api-token`)
- `secret/pi-fleet/external-dns/cloudflare-api-token` - Cloudflare API token for External-DNS Cloudflare provider (`api-token`)
- `secret/pi-fleet/cloudflare-tunnel/token` - Cloudflare Tunnel token for cloudflared connector (`token`)
- `secret/pi-fleet/terraform/pi-user` - Pi SSH username (optional, defaults to "pi") (`pi-user`)
- `secret/pi-fleet/pihole/webpassword` - Pi-hole web admin password
- `secret/pi-fleet/flux/git` - Flux Git SSH private key (`sshKey`)
- `secret/pi-fleet/external-dns/tsig-secret` - External DNS TSIG secret for RFC2136 DNS updates

### Legacy Infrastructure (Deprecated)
The following paths are being migrated to `secret/pi-fleet/`:
- `secret/canopy/ghcr-token` - GitHub Container Registry token (still used by multiple projects)

### Canopy Application
- `secret/canopy/postgres` - Canopy PostgreSQL password
- `secret/canopy/app` - Canopy application secret key
- `secret/canopy/database` - Canopy database URL
- `secret/canopy/questrade` - Questrade API refresh token (`refresh-token`); used for Celery background sync and optional env in API
- `secret/canopy/wise` - Wise API token (`api-token`); used for Wise sync (balances/transactions) and optional env in API

### SwimTO Application
- `secret/swimto/database` - SwimTO database URL
- `secret/swimto/postgres` - SwimTO PostgreSQL password
- `secret/swimto/redis` - SwimTO Redis URL
- `secret/swimto/app` - SwimTO admin token and secret key
- `secret/swimto/api-keys` - OpenAI and Leonardo.ai API keys
- `secret/swimto/oauth` - Google OAuth client ID and secret

### Journey Application
- `secret/journey/postgres` - Journey PostgreSQL password and user (`password`, `user`)
- `secret/journey/database` - Journey database URL (`url`)

### US Law Severity Map
- `secret/us-law-severity-map/mapbox` - Mapbox API token

### NIMA
- (No secrets currently required, placeholder configured for future use)

## After Raspberry Pi Restart

When your Raspberry Pi reboots, Vault starts in a **sealed state**. Follow these steps:

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config-eldertree

# Wait for Vault pod to be ready
kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=300s

# Unseal Vault (you'll be prompted for 3 keys)
./scripts/operations/unseal-vault.sh

# Verify Vault is unsealed
kubectl exec -n vault vault-0 -- vault status
```

External Secrets Operator will automatically resume syncing once Vault is unsealed.

## Backup and Restore

### Backup Secrets

```bash
# Backup all secrets to JSON file
./scripts/backup-vault-secrets.sh > vault-backup-$(date +%Y%m%d).json
```

**⚠️ Store backups securely!** They contain all your secrets in plain text.

### Restore Secrets

```bash
# Restore from backup
./scripts/restore-vault-secrets.sh vault-backup-20250115.json
```

## Access Vault

```bash
# Port forward to Vault UI
kubectl port-forward -n vault svc/vault 8200:8200

# Access UI: https://localhost:8200
# Login with your root token
```

## Manual Operations

```bash
# Get Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Read secret
kubectl exec -n vault $VAULT_POD -- vault kv get secret/monitoring/grafana

# Write secret (External Secrets Operator will sync automatically)
kubectl exec -n vault $VAULT_POD -- vault kv put secret/monitoring/grafana adminUser=admin adminPassword=yourpassword
```

## External Secrets

External Secrets Operator syncs secrets from Vault to Kubernetes automatically. Secrets are refreshed every 24 hours.

### Monitoring
- `monitoring/grafana-admin` - Grafana admin username and password

### Infrastructure
- `pihole/pihole-secrets` - Pi-hole web admin password
- `flux-system/flux-system` - Flux Git SSH key
- `canopy/ghcr-secret` - GitHub Container Registry token
- `external-dns/external-dns-tsig-secret` - External DNS TSIG secret for RFC2136
- `external-dns/external-dns-cloudflare-secret` - Cloudflare API token for External-DNS

### Applications
- `canopy/canopy-secrets` - Canopy database, app secrets
- `swimto/swimto-secrets` - SwimTO database, Redis, API keys, OAuth
- `journey/journey-secrets` - Journey database credentials and URL
- `us-law-severity-map/us-law-severity-map-secrets` - Mapbox token
- `nima/nima-secrets` - NIMA secrets (placeholder for future use)

## Setting Secrets in Vault

To set secrets in Vault, use the following commands:

```bash
# Get Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Canopy secrets
kubectl exec -n vault $VAULT_POD -- vault kv put secret/canopy/postgres password=yourpassword
kubectl exec -n vault $VAULT_POD -- vault kv put secret/canopy/app secret-key=your-secret-key
kubectl exec -n vault $VAULT_POD -- vault kv put secret/canopy/database url=postgresql+psycopg://canopy:password@canopy-postgres:5432/canopy
kubectl exec -n vault $VAULT_POD -- vault kv put secret/canopy/questrade refresh-token=YOUR_QUESTRADE_REFRESH_TOKEN
kubectl exec -n vault $VAULT_POD -- vault kv put secret/canopy/wise api-token=YOUR_WISE_API_TOKEN

# Grafana secrets
kubectl exec -n vault $VAULT_POD -- vault kv put secret/monitoring/grafana adminUser=admin adminPassword=yourpassword

# SwimTO secrets
kubectl exec -n vault $VAULT_POD -- vault kv put secret/swimto/postgres password=yourpassword
kubectl exec -n vault $VAULT_POD -- vault kv put secret/swimto/database url=postgresql+psycopg://postgres:password@postgres-service:5432/pools
kubectl exec -n vault $VAULT_POD -- vault kv put secret/swimto/redis url=redis://redis-service:6379
kubectl exec -n vault $VAULT_POD -- vault kv put secret/swimto/app admin-token=your-admin-token secret-key=your-secret-key
kubectl exec -n vault $VAULT_POD -- vault kv put secret/swimto/api-keys openai-api-key=your-key leonardo-api-key=your-key
kubectl exec -n vault $VAULT_POD -- vault kv put secret/swimto/oauth google-client-id=your-id google-client-secret=your-secret

# US Law Severity Map secrets
kubectl exec -n vault $VAULT_POD -- vault kv put secret/us-law-severity-map/mapbox token=your-mapbox-token

# Cloudflare secrets (pi-fleet infrastructure)
kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token=your-cloudflare-api-token
kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/external-dns/cloudflare-api-token api-token=your-cloudflare-api-token
```

**Note:** All secrets are automatically synced to Kubernetes by External Secrets Operator within 24 hours, or immediately on ExternalSecret resource creation/update.

## Troubleshooting

### Vault is Sealed After Restart

This is expected behavior. Run:
```bash
./scripts/operations/unseal-vault.sh
```

### Lost Unseal Keys

⚠️ **Critical:** If you lose your unseal keys, you cannot access Vault data. You must:
1. Delete the Vault PVC (destroys all secrets)
2. Re-initialize Vault
3. Re-enter all secrets

**Prevention:** Always backup unseal keys securely (password manager, encrypted file, etc.)

### External Secrets Not Syncing

Check if Vault is unsealed:
```bash
kubectl exec -n vault vault-0 -- vault status
```

Check External Secrets Operator logs:
```bash
kubectl logs -n external-secrets deployment/external-secrets
```

Verify token secret:
```bash
kubectl get secret vault-token -n external-secrets
```

### Check Secret Sync Status

```bash
# List all ExternalSecrets
kubectl get externalsecrets -A

# Check specific ExternalSecret
kubectl describe externalsecret grafana-admin -n monitoring

# Verify synced Kubernetes secret
kubectl get secret grafana-admin -n monitoring -o yaml
```

## Migration from Dev Mode

If you're migrating from the previous dev mode setup (without persistence), see the complete guide:

**[docs/VAULT_MIGRATION.md](docs/VAULT_MIGRATION.md)**

## GitHub Container Registry Tokens

GitHub Container Registry (GHCR) tokens are stored in Vault for each project:

- `secret/swimto/ghcr-token` - SwimTO GitHub token
- `secret/us-law-severity-map/ghcr-token` - US Law Severity Map GitHub token
- `secret/nima/ghcr-token` - NIMA GitHub token
- `secret/canopy/ghcr-token` - Canopy GitHub token

These tokens are automatically stored when running `./scripts/operations/setup-vault-policies.sh`.

## Security Best Practices

1. **Store unseal keys securely** - Use password manager or split among trusted individuals
2. **Backup secrets regularly** - Run `./scripts/backup-vault-secrets.sh` weekly
3. **Use project-specific tokens** - Don't use root token in project scripts
4. **Rotate tokens periodically** - Regenerate service tokens when needed
5. **Enable audit logging** - Track all Vault access (future enhancement)

## Future Enhancements

- Auto-unseal using cloud KMS or Kubernetes secrets
- Automated backup to external storage
- High availability (HA) mode for multi-node
- Audit logging for security compliance
