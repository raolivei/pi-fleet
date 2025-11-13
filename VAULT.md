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

- `secret/monitoring/grafana` - Grafana admin password
- `secret/pihole/webpassword` - Pi-hole web admin password
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

# Write secret (External Secrets Operator will sync automatically)
kubectl exec -n vault $VAULT_POD -- vault kv put secret/monitoring/grafana adminPassword=yourpassword
```

## External Secrets

External Secrets Operator syncs secrets from Vault to Kubernetes automatically. Secrets are refreshed every 24 hours.

- `monitoring/grafana-admin` - Grafana admin password
- `pihole/pihole-secrets` - Pi-hole web admin password
- `flux-system/flux-system` - Flux Git SSH key
- `canopy/canopy-secrets` - Canopy app secrets
- `canopy/ghcr-secret` - GitHub Container Registry token
