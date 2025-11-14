# keda-scaledobjects

Helm chart for managing KEDA ScaledObjects across all application deployments in pi-fleet cluster.

## Features

- **Centralized Configuration**: All autoscaling settings managed via `values.yaml`
- **Per-Service Control**: Enable/disable autoscaling per service
- **Consistent Thresholds**: Global CPU and Memory thresholds with per-service overrides
- **GitOps Ready**: Deployed via FluxCD HelmRelease

## Supported Services

### Canopy Namespace
- `canopy-api` - API service (min: 2, max: 5)
- `canopy-frontend` - Frontend service (min: 2, max: 3)
- `canopy-redis` - Redis cache (min: 1, max: 3)
- `canopy-postgres` - PostgreSQL database StatefulSet (min: 1, max: 2)

### SwimTO Namespace
- `swimto-api` - API service (min: 1, max: 5)
- `swimto-web` - Web frontend (min: 1, max: 3)
- `swimto-postgres` - PostgreSQL database (min: 1, max: 2)
- `swimto-redis` - Redis cache (min: 1, max: 3)

### Nima Namespace
- `nima-api` - API service (min: 2, max: 5)

### US Law Severity Map Namespace
- `us-law-severity-map-web` - Web frontend (min: 2, max: 3)

## Configuration

### Global Settings

```yaml
global:
  pollingInterval: 30      # Seconds between metric checks
  cooldownPeriod: 300       # Seconds to wait before scaling down
  cpuThreshold: "50"       # CPU utilization percentage threshold
  memoryThreshold: "80"     # Memory utilization percentage threshold
```

### Per-Service Settings

Each service can be enabled/disabled and have custom replica ranges:

```yaml
canopy:
  enabled: true
  api:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
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

- **CPU Trigger**: Scales up when CPU utilization exceeds threshold
- **Memory Trigger**: Scales up when Memory utilization exceeds threshold
- **Combined**: KEDA evaluates all triggers and scales based on the highest demand
- **Cooldown**: Prevents rapid scaling oscillations with 5-minute cooldown period

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

## Notes

- **StatefulSets**: PostgreSQL StatefulSets can scale but require careful consideration for data consistency
- **Resource Constraints**: Max replicas are conservative for Raspberry Pi cluster limitations
- **Metrics**: Requires metrics-server to be installed and running

