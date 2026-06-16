# Canopy FluxCD Deployment Guide

Self-hosted personal finance dashboard deployed to Eldertree K3s cluster via FluxCD.

## Prerequisites

### 1. Vault Secrets

The following secrets must exist in HashiCorp Vault before deployment:

```bash
# Generate a strong secret key
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Store required secrets in Vault
vault kv put secret/canopy/postgres-password password="<strong-password>"
vault kv put secret/canopy/secret-key key="<generated-key>"

# Optional integration secrets
vault kv put secret/canopy/questrade-refresh-token token="<token>"
vault kv put secret/canopy/wise-api-token token="<token>"

# Basic auth for web UI (htpasswd format)
# Generate: htpasswd -nb username password
vault kv put secret/canopy/basic-auth users="<username>:<hashed-password>"

# GHCR access (if using private images)
vault kv put secret/canopy/ghcr-token token="<github-pat>"
```

### 2. Docker Images

Ensure images are built and pushed to GHCR:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/canopy

# Build and push API
docker build -t ghcr.io/raolivei/canopy-api:latest -f backend/Dockerfile .
docker push ghcr.io/raolivei/canopy-api:latest

# Build and push Frontend
docker build -t ghcr.io/raolivei/canopy-frontend:latest -f frontend/Dockerfile .
docker push ghcr.io/raolivei/canopy-frontend:latest
```

## Deployment Architecture

### Components

1. **canopy-api** (2 replicas)
   - FastAPI backend
   - Port: 8000
   - Health: `/v1/health`
   - Resources: 256Mi RAM, 250m CPU (request)

2. **canopy-frontend** (2 replicas)
   - Next.js UI
   - Port: 3000
   - Resources: 128Mi RAM, 100m CPU (request)
   - Session affinity enabled (ClientIP) for Next.js chunk consistency

3. **canopy-redis** (1 replica)
   - Redis 7 Alpine
   - Port: 6379
   - Ephemeral storage (emptyDir)
   - Resources: 64Mi RAM, 50m CPU (request)

4. **canopy-postgres** (StatefulSet, 1 replica)
   - PostgreSQL 16 Alpine
   - Port: 5432
   - Persistent storage: 10Gi PVC (local-path)
   - Resources: 256Mi RAM, 250m CPU (request)

### Ingress Routes

- **Local**: `https://canopy.eldertree.local` (HTTPS redirect + basic auth)
- **Public**: `https://canopy.eldertree.xyz` (basic auth, Cloudflare tunnel)

Both routes proxy `/v1/*` to the API and `/*` to the frontend.

## Deployment Steps

### Initial Deployment

1. **Verify Vault secrets** (see Prerequisites above)

2. **Create branch and commit** (if making changes):
   ```bash
   cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
   git checkout main
   git pull
   git checkout -b feat/canopy-flux-deployment
   # Make any needed changes
   git add clusters/eldertree/canopy/
   git commit -m "feat: add canopy FluxCD deployment with ExternalSecrets"
   git push -u origin feat/canopy-flux-deployment
   ```

3. **FluxCD will automatically reconcile** the changes:
   ```bash
   # Watch reconciliation
   flux get kustomizations -n flux-system --watch
   
   # Check canopy resources
   kubectl get all -n canopy
   ```

4. **Run database migrations**:
   ```bash
   kubectl apply -f clusters/eldertree/canopy/migration-job.yaml
   kubectl wait --for=condition=complete --timeout=300s job/canopy-migration -n canopy
   kubectl logs -f job/canopy-migration -n canopy
   
   # Clean up job after success
   kubectl delete job canopy-migration -n canopy
   ```

5. **Verify deployment**:
   ```bash
   # Check pods
   kubectl get pods -n canopy
   
   # Check secrets (should be synced from Vault)
   kubectl get externalsecrets -n canopy
   kubectl get secrets -n canopy
   
   # Check ingress
   kubectl get ingress -n canopy
   
   # Test API health
   curl -k https://canopy.eldertree.local/v1/health
   
   # Test frontend
   curl -k https://canopy.eldertree.local/
   ```

### Updating Images

Images use `tag: latest` with `pullPolicy: Always` for single-user simplicity. To deploy new versions:

```bash
# Build and push new images (from canopy repo)
docker build -t ghcr.io/raolivei/canopy-api:latest -f backend/Dockerfile .
docker push ghcr.io/raolivei/canopy-api:latest

docker build -t ghcr.io/raolivei/canopy-frontend:latest -f frontend/Dockerfile .
docker push ghcr.io/raolivei/canopy-frontend:latest

# Restart deployments to pull new images
kubectl rollout restart deployment/canopy-api -n canopy
kubectl rollout restart deployment/canopy-frontend -n canopy

# Watch rollout
kubectl rollout status deployment/canopy-api -n canopy
kubectl rollout status deployment/canopy-frontend -n canopy
```

**Optional**: To enable automatic image updates, restore `image-automation.yaml` from git history and delete the note in `helmrelease.yaml` lines 23-29.

### Running Migrations After Updates

If schema changes are included in the new API image:

```bash
# Apply migration job
kubectl apply -f clusters/eldertree/canopy/migration-job.yaml
kubectl wait --for=condition=complete --timeout=300s job/canopy-migration -n canopy

# Check logs
kubectl logs job/canopy-migration -n canopy

# Clean up
kubectl delete job canopy-migration -n canopy
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl get pods -n canopy

# Describe failing pod
kubectl describe pod <pod-name> -n canopy

# Check logs
kubectl logs <pod-name> -n canopy

# Common issues:
# - ExternalSecrets not synced: kubectl get externalsecrets -n canopy
# - Image pull failure: kubectl describe pod ... | grep -A 5 Events
# - Database connection: Check DATABASE_URL in secret
```

### External Secrets not syncing

```bash
# Check ExternalSecret status
kubectl get externalsecrets -n canopy
kubectl describe externalsecret canopy-secrets -n canopy

# Check ClusterSecretStore
kubectl get clustersecretstore vault
kubectl describe clustersecretstore vault

# Verify Vault connectivity
kubectl logs -n external-secrets-system deployment/external-secrets
```

### Database connection issues

```bash
# Check postgres pod
kubectl get pod -n canopy -l component=postgres
kubectl logs -n canopy -l component=postgres

# Check service
kubectl get svc canopy-postgres -n canopy

# Test connection from API pod
kubectl exec -it -n canopy deployment/canopy-api -- /bin/sh
# Inside pod:
# python -c "import psycopg; psycopg.connect('postgresql://canopy:password@canopy-postgres:5432/canopy')"
```

### Migration failures

```bash
# Check migration job logs
kubectl logs job/canopy-migration -n canopy

# Check current database version
kubectl exec -it statefulset/canopy-postgres -n canopy -- psql -U canopy -d canopy -c "SELECT * FROM alembic_version;"

# Rollback if needed (manual)
kubectl exec -it deployment/canopy-api -n canopy -- /bin/sh
# Inside pod:
# cd /app && alembic downgrade -1
```

### Ingress issues

```bash
# Check ingress
kubectl get ingress -n canopy
kubectl describe ingress -n canopy

# Check Traefik logs
kubectl logs -n traefik deployment/traefik

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://canopy-frontend.canopy.svc.cluster.local:3000
```

## File Structure

```
clusters/eldertree/canopy/
├── DEPLOYMENT.md                      # This file
├── deploy.yaml                        # Namespace definition
├── kustomization.yaml                 # Kustomize resources list
├── helmrelease.yaml                   # HelmRelease (API, Frontend, Redis)
├── statefulset-postgres.yaml          # PostgreSQL with PVC
├── migration-job.yaml                 # Database migration Job
├── canopy-secrets-external.yaml       # App secrets (NEW)
├── ghcr-secret-external.yaml          # GHCR auth
├── basic-auth-external.yaml           # Traefik basic auth
└── cloudflare-origin-cert-external.yaml  # Public TLS cert
```

## Dependencies

- **External Secrets Operator**: Syncs secrets from Vault
- **Traefik**: Ingress controller with middleware
- **Cert-Manager**: TLS certificates for `.eldertree.local`
- **ExternalDNS**: DNS records for local domain
- **Cloudflare Tunnel**: Public access via `.eldertree.xyz`

## Observability

### Metrics

API exposes Prometheus metrics (if configured):
- Endpoint: `/metrics`
- ServiceMonitor: TBD (see observability standards)

### Logs

```bash
# API logs
kubectl logs -n canopy -l component=api -f

# Frontend logs
kubectl logs -n canopy -l component=frontend -f

# All canopy logs
kubectl logs -n canopy -l app=canopy -f --all-containers
```

### Health Checks

```bash
# API health
curl -k https://canopy.eldertree.local/v1/health

# Expected: {"status":"healthy"}
```

## Security

- **Secrets**: All secrets in Vault, synced via ExternalSecrets
- **Authentication**: Basic auth on all ingress routes
- **TLS**: Cert-Manager for local, Cloudflare Origin Cert for public
- **Network**: ClusterIP services, ingress-only external access
- **Container**: Non-root user (UID 1000) in API container

## References

- **Canopy repo**: `/Users/roliveira/WORKSPACE/raolivei/canopy`
- **Canopy CLAUDE.md**: `canopy/CLAUDE.md`
- **Pi-fleet docs**: `pi-fleet/docs/`
- **Helm chart**: `pi-fleet/helm/eldertree-app/`
- **Observability standards**: `workspace-config/docs/OBSERVABILITY_STANDARDS.md`

---

**Last Updated**: 2026-06-16
