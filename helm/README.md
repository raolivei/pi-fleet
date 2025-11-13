# Custom Helm Charts

Custom Helm charts for the pi-fleet cluster.

**Helm v4 Compatible** - All charts tested with Helm v4.0.0.

## Available Charts

### cert-manager-issuers

Custom cert-manager ClusterIssuers (self-signed, ACME).

### monitoring-stack

Complete monitoring solution with Prometheus and Grafana.

## Structure

```
helm/
├── cert-manager-issuers/
├── monitoring-stack/
└── <chart-name>/
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    └── README.md
```

## Usage

Charts are deployed via FluxCD HelmRelease from the git repository:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
spec:
  chart:
    spec:
      chart: ./helm/<chart-name>
      sourceRef:
        kind: GitRepository
        name: flux-system
```

## Creating a New Chart

```bash
cd helm
helm create <chart-name>
```

## Migration Notes

Infrastructure components were migrated to custom Helm charts for better management:

- **cert-manager-issuers**: Manages ClusterIssuers (self-signed, ACME)
- **monitoring-stack**: Bundles Prometheus + Grafana with coordinated config

**Benefits:**
- Templating via values.yaml
- Explicit versioning
- Managed dependencies
- Reusable across clusters
- GitOps-friendly (FluxCD deploys from git)
