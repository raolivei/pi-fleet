# Vault Secrets Bootstrap Guide

This document lists all secrets required for the eldertree cluster to function properly.

## Prerequisites

1. Vault must be unsealed and accessible
2. Run the setup script: `./scripts/operations/setup-vault-secrets.sh`

## Required Secrets

### Critical Infrastructure

| Secret Path | Key | Description | Source |
|-------------|-----|-------------|--------|
| `secret/pi-fleet/cloudflare-tunnel/token` | `token` | Cloudflare Tunnel token | [Cloudflare Dashboard](https://dash.cloudflare.com) → Zero Trust → Access → Tunnels |
| `secret/pi-fleet/external-dns/cloudflare-api-token` | `api-token` | Cloudflare API token for DNS | [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens) - needs Zone:DNS:Edit |
| `secret/pi-fleet/external-dns/tsig-secret` | `secret` | TSIG key for RFC2136 DNS | Generate: `openssl rand -base64 32` |
| `secret/pi-fleet/terraform/cloudflare-api-token` | `api-token` | Cloudflare API token for Terraform | Same as above or separate token |

### Application Secrets

| Secret Path | Keys | Description |
|-------------|------|-------------|
| `secret/swimto/database` | `url` | PostgreSQL connection URL |
| `secret/swimto/postgres` | `password` | PostgreSQL password |
| `secret/swimto/redis` | `url` | Redis connection URL |
| `secret/swimto/app` | `admin-token`, `secret-key` | App secrets |
| `secret/swimto/api-keys` | `openai-api-key`, `leonardo-api-key` | External API keys |
| `secret/swimto/oauth` | `google-client-id`, `google-client-secret` | OAuth credentials |
| `secret/canopy/postgres` | `password` | PostgreSQL password |
| `secret/canopy/app` | `secret-key` | App secret key |
| `secret/canopy/database` | `url` | PostgreSQL connection URL |
| `secret/canopy/questrade` | `refresh-token` | Questrade API refresh token (for background sync) |
| `secret/canopy/wise` | `api-token` | Wise API token (multi-currency balances/transactions sync) |
| `secret/journey/postgres` | `user`, `password` | PostgreSQL credentials |
| `secret/journey/database` | `url` | PostgreSQL connection URL |

### Monitoring & DNS

| Secret Path | Keys | Description |
|-------------|------|-------------|
| `secret/monitoring/grafana` | `adminUser`, `adminPassword` | Grafana admin credentials |
| `secret/pi-fleet/pihole/webpassword` | `password` | Pi-hole web interface password |

## Quick Setup Commands

```bash
# 1. Unseal Vault (if needed)
./scripts/operations/unseal-vault.sh

# 2. Login to Vault
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n vault $VAULT_POD -- vault login

# 3. Canopy – save all required + optional secrets in one go
./scripts/operations/save-canopy-secrets-to-vault.sh

# 4. Or run generic interactive setup
./scripts/operations/setup-vault-secrets.sh

# 5. Or set secrets directly:
VAULT_TOKEN=$(kubectl get secret -n vault vault-unseal-keys -o jsonpath='{.data.ROOT_TOKEN}' | base64 -d)

# TSIG key (generate new)
TSIG_SECRET=$(openssl rand -base64 32)
kubectl exec -n vault vault-0 -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv put secret/pi-fleet/external-dns/tsig-secret secret="$TSIG_SECRET"

# Cloudflare API token (get from dashboard)
kubectl exec -n vault vault-0 -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv put secret/pi-fleet/external-dns/cloudflare-api-token api-token="YOUR_TOKEN"

# Cloudflare Tunnel token
kubectl exec -n vault vault-0 -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv put secret/pi-fleet/cloudflare-tunnel/token token="YOUR_TUNNEL_TOKEN"
```

## Verification

```bash
# Check all ExternalSecrets are synced
kubectl get externalsecrets -A

# All should show STATUS=SecretSynced and READY=True
```

## Backup & Restore

```bash
# Backup all secrets
./scripts/operations/backup-vault-secrets.sh

# Restore from backup
./scripts/operations/restore-vault-secrets.sh
```

## Troubleshooting

### ImageUpdateAutomation: "failed to push to remote: authentication required: No anonymous write access"

Flux ImageUpdateAutomation (e.g. `canopy-updates`) commits new image tags and pushes to the pi-fleet repo. Push uses the same Git credentials as the `flux-system` GitRepository, which come from Vault at `secret/pi-fleet/flux/git` (key: `sshKey`).

**Fix:** The SSH key must have **write** access to the GitHub repo. If the deploy key is read-only:

1. In GitHub: **Settings → Deploy keys** for `raolivei/pi-fleet`, either edit the existing key and enable "Allow write access", or add a new deploy key with write access.
2. Put the private key into Vault:
   ```bash
   kubectl exec -n vault vault-0 -- vault kv put secret/pi-fleet/flux/git sshKey="$(cat /path/to/private_key)"
   ```
3. Force External Secrets to refresh: `kubectl annotate externalsecret flux-system -n flux-system force-sync=$(date +%s) --overwrite`

Until the key has write access, image tag updates will not be committed automatically; update tags in `clusters/eldertree/canopy/helmrelease.yaml` manually and push.

### ExternalSecret: "secrets 'canopy-cloudflare-origin-tls' already exists"

If the TLS secret was created manually or by another process, the ExternalSecret with `creationPolicy: Owner` cannot create it. The canopy Cloudflare cert ExternalSecret uses `creationPolicy: Merge` so it updates the existing secret instead. If you still see this error:

1. Delete the existing secret once: `kubectl delete secret canopy-cloudflare-origin-tls -n canopy`
2. On the next sync (within 24h or after force-sync), the ExternalSecret will create it.
