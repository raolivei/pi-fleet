# Vault Secrets Management

Vault stores secrets for all pi-fleet projects.

## Quick Start

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config-eldertree

# Sync secrets from Vault to Kubernetes
./scripts/sync-vault-to-k8s.sh
```

## Secret Paths

- `secret/monitoring/grafana` - Grafana admin password
- `secret/flux/git` - Flux Git SSH private key
- `secret/canopy/postgres` - Canopy PostgreSQL password
- `secret/canopy/app` - Canopy application secret key
- `secret/canopy/database` - Canopy database URL
- `secret/canopy/ghcr-token` - GitHub Container Registry token

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

# Write secret
kubectl exec -n vault $VAULT_POD -- vault kv put secret/monitoring/grafana adminPassword=yourpassword
```

