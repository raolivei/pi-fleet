# Vault Secrets Management

Vault stores secrets for all pi-fleet projects. External Secrets Operator automatically syncs secrets from Vault to Kubernetes.

## Quick Start

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config-eldertree

# External Secrets Operator syncs automatically
# Manual sync (legacy): ./scripts/sync-vault-to-k8s.sh
```

## Setup External Secrets Operator

Create Vault token secret:

```bash
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
VAULT_TOKEN=$(kubectl logs -n vault $VAULT_POD | grep "Root Token" | awk '{print $NF}')
kubectl create secret generic vault-token --from-literal=token=$VAULT_TOKEN -n external-secrets
```

## Secret Paths

### Monitoring
- `secret/monitoring/grafana` - Grafana admin username and password (`adminUser`, `adminPassword`)

### Infrastructure
- `secret/pihole/webpassword` - Pi-hole web admin password
- `secret/flux/git` - Flux Git SSH private key
- `secret/canopy/ghcr-token` - GitHub Container Registry token

### Canopy Application
- `secret/canopy/postgres` - Canopy PostgreSQL password
- `secret/canopy/app` - Canopy application secret key
- `secret/canopy/database` - Canopy database URL

### SwimTO Application
- `secret/swimto/database` - SwimTO database URL
- `secret/swimto/postgres` - SwimTO PostgreSQL password
- `secret/swimto/redis` - SwimTO Redis URL
- `secret/swimto/app` - SwimTO admin token and secret key
- `secret/swimto/api-keys` - OpenAI and Leonardo.ai API keys
- `secret/swimto/oauth` - Google OAuth client ID and secret

### US Law Severity Map
- `secret/us-law-severity-map/mapbox` - Mapbox API token

### NIMA
- (No secrets currently required, placeholder configured for future use)

## Access Vault

```bash
# Port forward to Vault UI
kubectl port-forward -n vault svc/vault 8200:8200

# Access UI: https://localhost:8200
# Dev mode token: (check pod logs)
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

### Applications
- `canopy/canopy-secrets` - Canopy database, app secrets
- `swimto/swimto-secrets` - SwimTO database, Redis, API keys, OAuth
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
```

**Note:** All secrets are automatically synced to Kubernetes by External Secrets Operator within 24 hours, or immediately on ExternalSecret resource creation/update.
