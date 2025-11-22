# keda-scaledobjects

Helm chart for managing KEDA ScaledObjects across all application deployments in pi-fleet cluster.

## Features

- **Centralized Configuration**: All autoscaling settings managed via `values.yaml`
- **Per-Service Control**: Enable/disable autoscaling per service
- **Consistent Thresholds**: Global CPU and Memory thresholds with per-service overrides
- **GitOps Ready**: Deployed via FluxCD HelmRelease

## Supported Services

### Canopy Namespace

- `canopy-api` - API service (min: 0, max: 5) - Scale-to-zero with HTTP rate trigger
- `canopy-frontend` - Frontend service (min: 1, max: 3) - HTTP rate trigger, kept at 1 for fast response
- `canopy-redis` - Redis cache (min: 1, max: 3) - CPU/Memory trigger
- `canopy-postgres` - PostgreSQL database StatefulSet (min: 1, max: 2) - CPU/Memory trigger

### SwimTO Namespace

- `swimto-api` - API service (min: 0, max: 5) - Scale-to-zero with HTTP rate trigger
- `swimto-web` - Web frontend (min: 1, max: 3) - HTTP rate trigger, kept at 1 for fast response
- `swimto-postgres` - PostgreSQL database (min: 1, max: 2) - CPU/Memory trigger
- `swimto-redis` - Redis cache (min: 1, max: 3) - CPU/Memory trigger

### Nima Namespace

- `nima-api` - API service (min: 0, max: 5) - Scale-to-zero with HTTP rate trigger (lower threshold for ML service)

### US Law Severity Map Namespace

- `us-law-severity-map-web` - Web frontend (min: 1, max: 3) - HTTP rate trigger, kept at 1 for fast response

## Configuration

### Global Settings

```yaml
global:
  prometheus:
    serverAddress: "http://prometheus-stack.observability.svc.cluster.local:9090"
  pollingInterval: 30 # Seconds between metric checks
  cooldownPeriod: 300 # Seconds to wait before scaling down (5 minutes)
  cpuThreshold: "50" # CPU utilization percentage threshold (for stateful services)
  memoryThreshold: "80" # Memory utilization percentage threshold (for stateful services)
```

### Per-Service Settings

Each service can be enabled/disabled and have custom replica ranges and trigger types:

**Stateless Services (HTTP Rate Triggers):**

```yaml
canopy:
  enabled: true
  api:
    enabled: true
    minReplicas: 0 # Scale to zero in standby
    maxReplicas: 5
    triggerType: "http-rate"
    httpRateThreshold: "5" # requests/sec to scale up
  frontend:
    enabled: true
    minReplicas: 1 # Keep 1 for fast response
    maxReplicas: 3
    triggerType: "http-rate"
    httpRateThreshold: "10" # requests/sec to scale up
```

**Stateful Services (CPU/Memory Triggers):**

```yaml
canopy:
  redis:
    enabled: true
    minReplicas: 1 # Keep at least 1 for stateful service
    maxReplicas: 3
    triggerType: "cpu-memory"
  postgres:
    enabled: true
    minReplicas: 1
    maxReplicas: 2
    triggerType: "cpu-memory"
```

## Usage

### Deploy via FluxCD

The chart is automatically deployed via HelmRelease:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: keda-scaledobjects
  namespace: keda
spec:
  chart:
    spec:
      chart: ./helm/keda-scaledobjects
      sourceRef:
        kind: GitRepository
        name: flux-system
```

### Manual Deployment

```bash
helm install keda-scaledobjects ./helm/keda-scaledobjects \
  --namespace keda \
  --create-namespace
```

### Upgrade

```bash
helm upgrade keda-scaledobjects ./helm/keda-scaledobjects \
  --namespace keda
```

## Scaling Behavior

### HTTP Rate Triggers (Stateless Services)

Stateless services (APIs and frontends) use **HTTP request rate** triggers via Prometheus metrics from Traefik ingress:

- **How it works**: KEDA queries Prometheus for Traefik HTTP request metrics
- **Scale-to-zero**: APIs scale to 0 replicas when no traffic detected
- **Scale-up**: Services scale up when HTTP request rate exceeds threshold
- **Frontends**: Kept at minimum 1 replica for fast response (better UX)
- **APIs**: Scale to zero to save resources during standby

**Prometheus Query Example:**

```promql
sum(rate(traefik_service_requests_total{
  service="canopy-api",
  namespace="canopy"
}[2m]))
```

**Thresholds:**

- Frontends: 10 requests/sec
- APIs: 5 requests/sec
- ML services (nima-api): 2 requests/sec (lower threshold)

### CPU/Memory Triggers (Stateful Services)

Stateful services (PostgreSQL, Redis) use **CPU and Memory** utilization triggers:

- **CPU Trigger**: Scales up when CPU utilization exceeds 50%
- **Memory Trigger**: Scales up when Memory utilization exceeds 80%
- **Combined**: KEDA evaluates all triggers and scales based on the highest demand
- **Minimum Replicas**: Always kept at 1 (stateful services cannot scale to zero)

### Cooldown Period

- **Duration**: 300 seconds (5 minutes)
- **Purpose**: Prevents rapid scaling oscillations
- **Behavior**: After scaling down, KEDA waits 5 minutes before scaling down again

### Scale-to-Zero Behavior

**Cold Start Implications:**

- When scaled to zero, first request triggers pod creation
- Cold start latency: 5-60 seconds depending on service
  - `nima-api`: ~60s (30s readiness + model loading)
  - APIs with DB: ~15-20s (readiness + DB connection pool)
  - Frontends: Fast startup (kept at min 1 to avoid cold starts)
- **First Request**: May fail/timeout during cold start
- **Subsequent Requests**: Normal response time once pod is ready

**Best Practices:**

- Frontends kept at min 1 replica for better UX
- APIs can tolerate cold start for resource savings
- Monitor readiness probe delays to ensure they're within tolerance

## Monitoring

Check ScaledObject status:

```bash
kubectl get scaledobjects -A
kubectl describe scaledobject <name> -n <namespace>
```

Check HPA created by KEDA:

```bash
kubectl get hpa -A
```

View KEDA operator logs:

```bash
kubectl logs -n keda deployment/keda-operator
```

## Traefik Metrics

KEDA uses Traefik ingress metrics for HTTP rate scaling. Traefik exposes Prometheus metrics at `/metrics` endpoint.

**Required Metrics:**

- `traefik_service_requests_total` - Total HTTP requests per service

**Verification:**

```bash
# Check if Traefik exposes metrics
kubectl port-forward -n kube-system svc/traefik 8080:8080
curl http://localhost:8080/metrics | grep traefik_service_requests_total

# Query Prometheus directly
curl 'http://prometheus-stack.observability.svc.cluster.local:9090/api/v1/query?query=traefik_service_requests_total'
```

**Service Name Matching:**

- Ensure Traefik service names match Kubernetes service names
- Service names used in queries:
  - `canopy-api`, `canopy-frontend`
  - `swimto-api-service`, `swimto-web-service`
  - `nima-api`
  - `us-law-severity-map-web`

## Notes

- **StatefulSets**: PostgreSQL StatefulSets can scale but require careful consideration for data consistency
- **Resource Constraints**: Max replicas are conservative for Raspberry Pi cluster limitations
- **Metrics**: Requires Prometheus and Traefik metrics to be available
- **Scale-to-Zero**: First request after scale-to-zero may experience cold start delay (5-60s)
- **Frontend Strategy**: Frontends kept at min 1 replica to avoid cold start delays for better UX
- **Monitoring**: Monitor ScaledObject status and HPA metrics to verify scaling behavior
