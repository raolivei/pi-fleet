# Canopy Deployment

Personal finance, investment, and budgeting dashboard.

## Prerequisites

- **All secrets must be stored in Vault** before deployment
- Container images must be built and pushed to GHCR
- Vault must be accessible and configured

## Secrets Management

**⚠️ IMPORTANT: All secrets are stored in Vault, not in Kubernetes manifests or local files.**

See [VAULT_SECRETS.md](./VAULT_SECRETS.md) for complete secret storage instructions.

### Quick Setup

1. **Store all secrets in Vault** (see VAULT_SECRETS.md for details):
   ```bash
   vault kv put secret/kv/canopy/postgres password="..."
   vault kv put secret/kv/canopy/app secret-key="..."
   vault kv put secret/kv/canopy/database url="..."
   vault kv put secret/kv/canopy/ghcr-token token="..."
   ```

2. **Sync secrets from Vault to Kubernetes**:
   ```bash
   ./sync-secrets.sh
   ```

## Build and Push Images

From the canopy repository:

```bash
# Build backend
cd backend
docker build -t ghcr.io/raolivei/canopy-api:latest -f Dockerfile .
docker push ghcr.io/raolivei/canopy-api:latest

# Build frontend
cd ../frontend
docker build -t ghcr.io/raolivei/canopy-frontend:latest -f Dockerfile .
docker push ghcr.io/raolivei/canopy-frontend:latest
```

## Deploy

FluxCD will automatically deploy once changes are merged to main.

Manual deployment:

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl apply -k clusters/eldertree/canopy/
```

## Access

Add to `/etc/hosts`:

```
192.168.2.83  canopy.eldertree.local
```

Access at: https://canopy.eldertree.local

## Verify Deployment

```bash
# Check pods
kubectl get pods -n canopy

# Check services
kubectl get svc -n canopy

# Check ingress
kubectl get ingress -n canopy

# Check certificate
kubectl get certificate -n canopy

# View logs
kubectl logs -n canopy -l app=canopy,component=api
kubectl logs -n canopy -l app=canopy,component=frontend
```

## Resources

**Optimized for Raspberry Pi:**
- API: 128Mi-256Mi RAM, 100m-250m CPU
- Frontend: 64Mi-128Mi RAM, 50m-100m CPU
- Redis: 32Mi-64Mi RAM, 25m-50m CPU
- Postgres: 128Mi-256Mi RAM, 100m-250m CPU, 5Gi storage

