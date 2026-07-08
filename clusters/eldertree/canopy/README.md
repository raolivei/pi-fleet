# Canopy FluxCD Deployment

Personal finance dashboard for Eldertree cluster.

## Quick Start

### Prerequisites

1. **Vault secrets** (see [DEPLOYMENT.md](DEPLOYMENT.md) for details):
   ```bash
   vault kv put secret/canopy/postgres-password password="<password>"
   vault kv put secret/canopy/secret-key key="<secret-key>"
   vault kv put secret/canopy/basic-auth users="<htpasswd>"
   vault kv put secret/canopy/ghcr-token token="<github-pat>"
   ```

2. **Docker images pushed to GHCR**:
   ```bash
   # From canopy repo
   docker build -t ghcr.io/raolivei/canopy-api:latest -f backend/Dockerfile .
   docker push ghcr.io/raolivei/canopy-api:latest
   docker build -t ghcr.io/raolivei/canopy-frontend:latest -f frontend/Dockerfile .
   docker push ghcr.io/raolivei/canopy-frontend:latest
   ```

### Deploy

FluxCD automatically reconciles. To verify:

```bash
# Watch deployment
kubectl get pods -n canopy -w

# Run verification script
chmod +x verify-deployment.sh
./verify-deployment.sh

# Run migrations
kubectl apply -f migration-job.yaml
kubectl wait --for=condition=complete --timeout=300s job/canopy-migration -n canopy
kubectl logs -f job/canopy-migration -n canopy
kubectl delete job canopy-migration -n canopy
```

### Access

- **Local**: https://canopy.eldertree.local
- **Public**: https://canopy.eldertree.xyz

Both require basic auth (credentials from Vault).

## Files

- `DEPLOYMENT.md` - Complete deployment guide
- `deploy.yaml` - Namespace
- `kustomization.yaml` - Resource manifest
- `helmrelease.yaml` - Main app (API, Frontend, Redis)
- `statefulset-postgres.yaml` - PostgreSQL with PVC
- `canopy-secrets-external.yaml` - App secrets (Vault → K8s)
- `ghcr-secret-external.yaml` - GHCR authentication
- `basic-auth-external.yaml` - Web UI authentication
- `cloudflare-origin-cert-external.yaml` - Public TLS cert
- `migration-job.yaml` - Database migration Job
- `verify-deployment.sh` - Deployment verification

## Common Commands

```bash
# Check status
kubectl get all -n canopy
kubectl get externalsecrets -n canopy

# Logs
kubectl logs -n canopy -l component=api -f
kubectl logs -n canopy -l component=frontend -f

# Restart after image update
kubectl rollout restart deployment/canopy-api -n canopy
kubectl rollout restart deployment/canopy-frontend -n canopy

# Database access
kubectl exec -it statefulset/canopy-postgres -n canopy -- psql -U canopy -d canopy

# Test API
curl -k https://canopy.eldertree.local/v1/health
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Ingress                              │
│  canopy.eldertree.local / canopy.eldertree.xyz              │
│           (HTTPS + Basic Auth)                              │
└─────────────┬───────────────────────────────────────────────┘
              │
        ┌─────┴─────┐
        │           │
        ▼           ▼
  ┌─────────┐  ┌──────────┐
  │Frontend │  │   API    │──────┐
  │(Next.js)│  │(FastAPI) │      │
  │  x2     │  │   x2     │      │
  └─────────┘  └────┬─────┘      │
                    │            │
           ┌────────┴────┐       │
           │             │       │
           ▼             ▼       ▼
      ┌────────┐    ┌───────────────┐
      │ Redis  │    │  PostgreSQL   │
      │(cache) │    │(StatefulSet)  │
      │  x1    │    │   + 10Gi PVC  │
      └────────┘    └───────────────┘
```

## Resources

- API: 256Mi RAM / 250m CPU (request), 512Mi / 500m (limit)
- Frontend: 128Mi RAM / 100m CPU (request), 256Mi / 200m (limit)
- Redis: 64Mi RAM / 50m CPU (request), 128Mi / 100m (limit)
- PostgreSQL: 256Mi RAM / 250m CPU (request), 512Mi / 500m (limit)

## Troubleshooting

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed troubleshooting steps.

Quick checks:
```bash
# Check ExternalSecrets sync
kubectl get externalsecrets -n canopy
kubectl describe externalsecret canopy-secrets -n canopy

# Check pod issues
kubectl describe pod <pod-name> -n canopy
kubectl logs <pod-name> -n canopy

# Check HelmRelease
kubectl describe helmrelease canopy -n canopy
```

---

**Full documentation**: [DEPLOYMENT.md](DEPLOYMENT.md)
