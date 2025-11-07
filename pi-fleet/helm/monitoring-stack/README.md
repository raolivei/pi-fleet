# monitoring-stack

Complete monitoring solution for pi-fleet with Prometheus and Grafana.

## Features

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization with pre-configured dashboards
- **Node Exporter**: Host metrics
- **Pre-configured datasources**: Prometheus → Grafana
- **Built-in dashboards**: Kubernetes Cluster, Node Exporter

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
