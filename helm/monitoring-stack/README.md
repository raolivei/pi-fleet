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

## Lens IDE

To show node/workload metrics in Lens, set **Metrics Source** → **Prometheus** and **Prometheus Service Address** to:

```
observability/observability-monitoring-stack-prometheus-server:80
```

Leave **Custom path prefix** empty. The scrape config adds a `node` label so Lens can match metrics to cluster nodes.

## Dashboards

See [DASHBOARDS.md](./DASHBOARDS.md) for dashboard details and useful PromQL queries.
