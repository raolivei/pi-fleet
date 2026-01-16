# Grafana Dashboards

Access Grafana at `https://grafana.eldertree.local:32474` (default credentials: admin/admin)

> ⚠️ **Note:** Use NodePort `:32474` for HTTPS access (MetalLB LoadBalancer IPs not reachable from Wi-Fi).

## Access URLs

| Service      | URL                                            |
| ------------ | ---------------------------------------------- |
| Grafana      | `https://grafana.eldertree.local:32474`        |
| Prometheus   | `https://prometheus.eldertree.local:32474`     |

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
- **Traefik** (11462): Ingress controller requests, latency, and errors
- **Cert-Manager** (11001): Certificate status, renewal monitoring
- **External Secrets** (15159): Secret sync status and errors
- **KEDA** (13627): Autoscaling metrics and scaler status
- **Flux Cluster** (15991): GitOps reconciliation status
- **Pi-hole** (10176): DNS query stats and blocking metrics
- **Hardware Health** (custom): Raspberry Pi temperature and hardware metrics

### Database Monitoring

- **PostgreSQL** (9628): Connection stats, query performance, replication
- **Redis** (763): Memory usage, connected clients, keyspace stats

### Application Dashboards (Custom)

| Dashboard | Description | File |
|-----------|-------------|------|
| **Pi Fleet Overview** | Cluster health summary, resource trends | `pi-fleet-overview.json` |
| **Hardware Health** | Raspberry Pi temperature and hardware | `hardware-health.json` |
| **SwimTO** | swimTO API, Web, Postgres, Redis metrics | `swimto-dashboard.json` |
| **Journey** | Journey API, Frontend, Postgres metrics | `journey-dashboard.json` |
| **Nima** | NIMA AI/ML API metrics | `nima-dashboard.json` |
| **US Law Severity Map** | Law visualization web app metrics | `us-law-severity-map-dashboard.json` |
| **Canopy** | Canopy API, Frontend, Postgres, Redis | `canopy-dashboard.json` |
| **Pitanga & NorthwaySignal** | Website traffic and health | `pitanga-dashboard.json` |
| **Visage Training** | GPU training progress, loss, steps | `visage-training.json` |
| **Visage Operations** | System health, API metrics, resources | `visage-operations.json` |

## Alerting

Alertmanager is configured with the following alert rules:

### Node Alerts
- **NodeDown**: Node unreachable for >2 minutes (critical)
- **HighCPUUsage**: CPU >85% for >5 minutes (warning)
- **HighMemoryUsage**: Memory >90% for >5 minutes (warning)
- **HighNodeTemperature**: Temperature >75°C for >5 minutes (warning)

### Kubernetes Alerts
- **PodCrashLooping**: >5 restarts in 1 hour (warning)
- **PodNotReady**: Pod not ready for >10 minutes (warning)
- **DeploymentReplicasMismatch**: Replica count mismatch for >10 minutes (warning)

### Storage Alerts
- **PVCAlmostFull**: PVC >85% full (warning)
- **DiskSpaceLow**: Disk <15% available (warning)

## External GPU Worker (Visage)

The Visage GPU worker runs on an external Mac with Apple Silicon. It pushes metrics to Prometheus via Pushgateway:

```bash
# Configure the worker to push metrics
export PUSHGATEWAY_URL=https://pushgateway.eldertree.local
```

## Useful PromQL Queries

### Cluster Health

```promql
# Nodes ready
sum(kube_node_status_condition{condition="Ready",status="true"})

# Pods not running
count(kube_pod_status_phase{phase!="Running"})

# Container restarts (last hour)
sum(increase(kube_pod_container_status_restarts_total[1h]))

# Failed pods by namespace
count(kube_pod_status_phase{phase="Failed"}) by (namespace)
```

### Resource Usage

```promql
# CPU usage by namespace
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)

# Memory usage by namespace
sum(container_memory_working_set_bytes) by (namespace)

# Available cluster CPU (cores)
sum(machine_cpu_cores) - sum(rate(container_cpu_usage_seconds_total[5m]))

# Top 5 memory consumers
topk(5, sum(container_memory_working_set_bytes{container!=""}) by (pod, namespace))
```

### Storage

```promql
# PV usage %
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100

# Node disk usage %
(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100

# PVCs over 80% full
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) > 0.8
```

### Network

```promql
# Network receive rate by namespace
sum(rate(container_network_receive_bytes_total[5m])) by (namespace)

# Network transmit rate by namespace
sum(rate(container_network_transmit_bytes_total[5m])) by (namespace)

# Traefik request rate by service
sum(rate(traefik_service_requests_total[5m])) by (service)
```

### Application Metrics

```promql
# API request rate by app
sum(rate(traefik_service_requests_total{service=~".*-api.*"}[5m])) by (service, code)

# API response time p95
histogram_quantile(0.95, sum(rate(traefik_service_request_duration_seconds_bucket{service=~".*-api.*"}[5m])) by (le, service))

# Database connections (if postgres_exporter is running)
pg_stat_activity_count

# Redis memory usage
redis_memory_used_bytes
```

### Hardware (Raspberry Pi)

```promql
# Node temperature
node_hwmon_temp_celsius

# CPU throttling
node_thermal_zone_temp > 70

# Max temperature across all nodes
max(node_hwmon_temp_celsius)
```

## Quick Tips

- Use time range selectors for historical analysis
- Alerts are configured in Alertmanager - check the Alertmanager UI for firing alerts
- Dashboards are editable - customize for your needs
- Export custom dashboards via JSON for backup
- Pushgateway metrics expire after 5 minutes if not refreshed
- Use `{namespace="app-name"}` label to filter metrics by application
