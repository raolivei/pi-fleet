# Canopy Deployment

Personal finance, investment, and budgeting dashboard.

## Prerequisites

- Secrets must be created before deployment
- Container images must be built and pushed to GHCR

## Create Secrets

```bash
# Generate postgres password
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Generate secret key
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")

# Create secret
kubectl create secret generic canopy-secrets \
  --namespace canopy \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=database-url="postgresql+psycopg://canopy:$POSTGRES_PASSWORD@canopy-postgres:5432/canopy" \
  --from-literal=secret-key="$SECRET_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -
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

