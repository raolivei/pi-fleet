# Canopy FluxCD Deployment - Setup Summary

## Changes Made

### New Files Created

1. **`canopy-secrets-external.yaml`** (CRITICAL - was missing)
   - ExternalSecret for application secrets from Vault
   - Maps: postgres-password, secret-key, questrade-refresh-token, wise-api-token
   - Constructs DATABASE_URL from postgres-password

2. **`migration-job.yaml`**
   - Kubernetes Job for running Alembic database migrations
   - Should be run after initial deployment and schema updates
   - Uses same API image, runs `alembic upgrade head`

3. **`DEPLOYMENT.md`**
   - Comprehensive deployment guide
   - Prerequisites, architecture, deployment steps
   - Troubleshooting guide
   - Observability and security notes

4. **`README.md`**
   - Quick reference for common operations
   - Architecture diagram
   - Common commands and troubleshooting

5. **`verify-deployment.sh`**
   - Automated verification script
   - Checks all resources are healthy
   - Tests API health endpoint
   - Needs `chmod +x` before use

### Modified Files

1. **`kustomization.yaml`**
   - Added `canopy-secrets-external.yaml` to resources list
   - Ensures secrets are created before StatefulSet and HelmRelease

### Existing Files (Already Correct)

- `deploy.yaml` - Namespace definition
- `helmrelease.yaml` - HelmRelease using eldertree-app chart
- `statefulset-postgres.yaml` - PostgreSQL with 10Gi PVC
- `ghcr-secret-external.yaml` - GHCR authentication
- `basic-auth-external.yaml` - Web UI basic auth
- `cloudflare-origin-cert-external.yaml` - Public TLS certificate

## What Was Missing

The **critical missing piece** was the `canopy-secrets` ExternalSecret. The HelmRelease and StatefulSet both reference `canopy-secrets` for:
- DATABASE_URL (API)
- postgres-password (PostgreSQL)
- secret-key (API)
- Optional integration tokens

Without this ExternalSecret, the pods would fail to start with "secret not found" errors.

## Next Steps

### 1. Set Up Vault Secrets (REQUIRED)

```bash
# Connect to Vault (adjust based on your setup)
export VAULT_ADDR="https://vault.eldertree.local"
vault login

# Generate strong values
POSTGRES_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")

# Store required secrets
vault kv put secret/canopy/postgres-password password="$POSTGRES_PASSWORD"
vault kv put secret/canopy/secret-key key="$SECRET_KEY"

# Optional: Integration tokens (if you have them)
# vault kv put secret/canopy/questrade-refresh-token token="<your-token>"
# vault kv put secret/canopy/wise-api-token token="<your-token>"

# Basic auth for web UI
# Generate: htpasswd -nb <username> <password>
vault kv put secret/canopy/basic-auth users="username:$apr1$..."

# GHCR token (if not already set)
vault kv put secret/canopy/ghcr-token token="<github-pat>"
```

### 2. Build and Push Images (if not done)

```bash
cd /Users/roliveira/WORKSPACE/raolivei/canopy

# Build API
docker build -t ghcr.io/raolivei/canopy-api:latest -f backend/Dockerfile .
docker push ghcr.io/raolivei/canopy-api:latest

# Build Frontend
docker build -t ghcr.io/raolivei/canopy-frontend:latest -f frontend/Dockerfile .
docker push ghcr.io/raolivei/canopy-frontend:latest
```

### 3. Create Git Branch and Commit

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# Create feature branch
git checkout main
git pull
git checkout -b feat/canopy-flux-deployment

# Make verify script executable
chmod +x clusters/eldertree/canopy/verify-deployment.sh

# Stage changes
git add clusters/eldertree/canopy/

# Commit
git commit -m "feat: add canopy FluxCD deployment with ExternalSecrets

- Add canopy-secrets ExternalSecret (database, API keys)
- Add migration Job for Alembic schema updates
- Add comprehensive deployment documentation
- Add verification script for deployment health
- Update kustomization to include new secrets

Closes #<issue-number>"

# Push
git push -u origin feat/canopy-flux-deployment
```

### 4. Deploy and Verify

```bash
# FluxCD will auto-reconcile after merge, or force:
flux reconcile kustomization flux-system --with-source

# Watch deployment
kubectl get pods -n canopy -w

# Run verification (in another terminal)
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/canopy
./verify-deployment.sh
```

### 5. Run Database Migrations

```bash
# Apply migration job
kubectl apply -f clusters/eldertree/canopy/migration-job.yaml

# Wait for completion
kubectl wait --for=condition=complete --timeout=300s job/canopy-migration -n canopy

# Check logs
kubectl logs job/canopy-migration -n canopy

# Clean up
kubectl delete job canopy-migration -n canopy
```

### 6. Access Application

- **Local**: https://canopy.eldertree.local
- **Public**: https://canopy.eldertree.xyz

Use basic auth credentials from Vault.

## Verification Checklist

- [ ] Vault secrets created (postgres-password, secret-key, basic-auth, ghcr-token)
- [ ] Docker images built and pushed to GHCR
- [ ] Git branch created and pushed
- [ ] FluxCD reconciled (or PR merged)
- [ ] All ExternalSecrets synced: `kubectl get externalsecrets -n canopy`
- [ ] All pods running: `kubectl get pods -n canopy`
- [ ] API health check: `curl -k https://canopy.eldertree.local/v1/health`
- [ ] Database migrations run successfully
- [ ] Web UI accessible with basic auth
- [ ] Frontend and API working together

## Common Issues

### ExternalSecret not syncing

```bash
# Check status
kubectl describe externalsecret canopy-secrets -n canopy

# Common causes:
# - Vault path doesn't exist
# - ClusterSecretStore not configured
# - Vault token expired
```

### Pods not starting

```bash
# Check events
kubectl describe pod <pod-name> -n canopy

# Common causes:
# - ExternalSecret not synced (secrets missing)
# - Image pull failure (check ghcr-secret)
# - Resource limits too low
```

### Database connection failures

```bash
# Check postgres pod
kubectl logs -n canopy -l component=postgres

# Check secret value
kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.database-url}' | base64 -d

# Common causes:
# - Postgres not ready (check PVC)
# - Wrong password in Vault
# - DATABASE_URL format incorrect
```

## Architecture Overview

```
Vault (secret/canopy/*)
  │
  ▼
ExternalSecrets (canopy-secrets, ghcr-secret, basic-auth, tls-cert)
  │
  ▼
Kubernetes Secrets
  │
  ├─▶ PostgreSQL StatefulSet (10Gi PVC)
  │
  └─▶ HelmRelease (eldertree-app chart)
       ├─▶ API Deployment (2 replicas)
       ├─▶ Frontend Deployment (2 replicas)
       └─▶ Redis Deployment (1 replica, ephemeral)
```

## Resources Created

- Namespace: `canopy`
- Deployments: `canopy-api`, `canopy-frontend`, `canopy-redis`
- StatefulSet: `canopy-postgres`
- Services: `canopy-api`, `canopy-frontend`, `canopy-redis`, `canopy-postgres`
- PVC: `postgres-data-canopy-postgres-0` (10Gi)
- Secrets: `canopy-secrets`, `ghcr-secret`, `canopy-basic-auth`, `canopy-cloudflare-origin-tls`
- ExternalSecrets: 4 (mapping Vault → K8s)
- Ingress: 2 routes (local + public)
- Middleware: 2 (HTTPS redirect, basic auth)

## Maintenance

### Updating Images

```bash
# Build and push new images
docker build -t ghcr.io/raolivei/canopy-api:latest ...
docker push ghcr.io/raolivei/canopy-api:latest

# Restart to pull new image
kubectl rollout restart deployment/canopy-api -n canopy
```

### Running Migrations

```bash
kubectl apply -f clusters/eldertree/canopy/migration-job.yaml
kubectl wait --for=condition=complete job/canopy-migration -n canopy
kubectl delete job canopy-migration -n canopy
```

### Checking Logs

```bash
kubectl logs -n canopy -l component=api -f
kubectl logs -n canopy -l component=frontend -f
```

---

**Created**: 2026-06-16  
**Status**: Ready for deployment (after Vault secrets setup)
