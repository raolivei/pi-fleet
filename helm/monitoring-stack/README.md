# monitoring-stack

Complete monitoring solution for pi-fleet with Prometheus and Grafana.

## Features

- **Prometheus**: Metrics collection and storage with optimized scraping
- **Grafana**: Visualization with 9 comprehensive Kubernetes dashboards
- **kube-state-metrics**: Detailed Kubernetes object metrics
- **Node Exporter**: Host-level metrics (CPU, memory, disk, network)
- **Pre-configured datasources**: Prometheus → Grafana
- **Built-in dashboards**: Cluster views, resource monitoring, API server, PVs, nodes

## Values

```yaml
global:
  domain: eldertree.local
  clusterIssuer: selfsigned-cluster-issuer

prometheus:
  enabled: true
  server:
    persistentVolume:
      size: 8Gi

grafana:
  enabled: true
  adminPassword: admin
  persistence:
    size: 2Gi
```

## Access

- Prometheus: `https://prometheus.eldertree.local`
- Grafana: `https://grafana.eldertree.local`

## Deployment

This chart is deployed via FluxCD from the git repository.

## Dashboards

See [DASHBOARDS.md](./DASHBOARDS.md) for dashboard details and useful PromQL queries.
