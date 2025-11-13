# Grafana Dashboards

Access Grafana at `https://grafana.eldertree.local` (default credentials: admin/admin)

## Included Dashboards

### Kubernetes Views (Recommended)
- **Global View** (15757): Cluster-wide health, resource usage, node status
- **Namespaces View** (15758): Per-namespace CPU, memory, network, pods
- **Pods View** (15759): Individual pod metrics and logs

### Resource Monitoring
- **Compute Resources - Namespace** (15661): CPU/memory by namespace
- **Compute Resources - Pod** (15662): CPU/memory by pod
- **Persistent Volumes** (13646): Storage usage and PV status

### Infrastructure
- **Cluster Monitoring** (6417): Overall cluster health
- **API Server** (12006): kube-apiserver performance
- **Node Exporter** (1860): Node-level metrics (CPU, disk, network)

## Useful PromQL Queries

### Cluster Health
```promql
# Nodes ready
sum(kube_node_status_condition{condition="Ready",status="true"})

# Pods not running
count(kube_pod_status_phase{phase!="Running"})

# Container restarts (last hour)
sum(increase(kube_pod_container_status_restarts_total[1h]))
```

### Resource Usage
```promql
# CPU usage by namespace
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)

# Memory usage by namespace
sum(container_memory_working_set_bytes) by (namespace)

# Available cluster CPU (cores)
sum(machine_cpu_cores) - sum(rate(container_cpu_usage_seconds_total[5m]))
```

### Storage
```promql
# PV usage %
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100

# Node disk usage %
(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100
```

### Network
```promql
# Network receive rate
sum(rate(container_network_receive_bytes_total[5m])) by (namespace)

# Network transmit rate
sum(rate(container_network_transmit_bytes_total[5m])) by (namespace)
```

## Quick Tips

- Use time range selectors for historical analysis
- Set up alerts based on these queries in Prometheus
- Dashboards are editable - customize for your needs
- Export custom dashboards via JSON for backup

