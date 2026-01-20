# Grafana Dashboards

Access Grafana at `https://grafana.eldertree.local` (or `:32474` NodePort for Wi-Fi clients)

## Access URLs

| Service      | URL                                        | Notes |
|--------------|--------------------------------------------|-------|
| Grafana      | `https://grafana.eldertree.local`          | Default admin/admin |
| Prometheus   | `https://prometheus.eldertree.local`       | No auth |
| Alertmanager | `https://alertmanager.eldertree.local`     | Alert routing |
| Pushgateway  | `https://pushgateway.eldertree.local`      | External worker metrics |

> **Note:** kube-vip LoadBalancer IPs (192.168.2.200-210) are directly accessible from Wi-Fi clients.

---

## Dashboard Inventory

### Infrastructure (14 dashboards)

| Dashboard | Source | ID | Description |
|-----------|--------|-----|-------------|
| **Eldertree Cluster** | Custom | - | 3-node HA cluster overview, Vault status, all services |
| **Pi Fleet Overview** | Custom | - | Cluster health summary, resource trends |
| **Hardware Health** | Custom | - | Raspberry Pi temperature and hardware |
| K8s Views Global | Grafana.com | 15757 | Cluster-wide health, resources, nodes |
| K8s Views Namespaces | Grafana.com | 15758 | Per-namespace CPU, memory, network |
| K8s Views Pods | Grafana.com | 15759 | Individual pod metrics |
| K8s API Server | Grafana.com | 12006 | kube-apiserver health (critical for HA) |
| K8s Persistent Volumes | Grafana.com | 13646 | Storage usage and PV status |
| Node Exporter Full | Grafana.com | 1860 | Node-level metrics (CPU, disk, network) |
| Traefik | Grafana.com | 11462 | Ingress controller metrics |
| Flux Cluster | Grafana.com | 15991 | GitOps reconciliation status |
| CoreDNS | Grafana.com | 14981 | k3s DNS health and queries |
| etcd | Grafana.com | 3070 | HA cluster etcd health |
| Vault | Grafana.com | 12904 | Vault HA and operations |

### Applications (12 dashboards)

| Dashboard | File | Description |
|-----------|------|-------------|
| **SwimTO** | `swimto-dashboard.json` | Pool finder - API, Web, Postgres, Redis |
| **Canopy** | `canopy-dashboard.json` | Personal finance - API, Web, Postgres, Redis |
| **Journey** | `journey-dashboard.json` | Career pathfinder - API, Frontend, Postgres |
| **Visage Operations** | `visage-operations.json` | AI headshots - System health, API, resources |
| **Visage Training** | `visage-training.json` | AI headshots - GPU training progress, loss |
| **NIMA** | `nima-dashboard.json` | ML platform - API, Frontend metrics |
| **Ollie** | `ollie-dashboard.json` | AI assistant - Core, Ollama, TTS, Whisper, UI |
| **iPhone Export** | `iphone-export-dashboard.json` | E-commerce - API, Web, Postgres, Redis |
| **Pitanga & NorthwaySignal** | `pitanga-dashboard.json` | Company websites traffic and health |
| **US Law Severity Map** | `us-law-severity-map-dashboard.json` | Legal visualization web app |

### Database & Services (5 dashboards)

| Dashboard | Source | ID | Description |
|-----------|--------|-----|-------------|
| PostgreSQL | Grafana.com | 9628 | Connections, queries, replication |
| Redis | Grafana.com | 763 | Memory, clients, keyspace |
| Pi-hole | Grafana.com | 10176 | DNS queries, blocking stats |
| Cert-manager | Grafana.com | 11001 | Certificate status, renewals |
| External Secrets | Grafana.com | 15159 | Vault sync status |

### Resource Views (2 dashboards)

| Dashboard | Source | ID | Description |
|-----------|--------|-----|-------------|
| Compute Resources - Namespace | Grafana.com | 15661 | CPU/memory by namespace |
| Compute Resources - Pod | Grafana.com | 15662 | CPU/memory by pod |

---

## Alerting

Alertmanager URL: `https://alertmanager.eldertree.local`

### Node Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| NodeDown | Node unreachable >2m | Critical |
| HighCPUUsage | CPU >85% for >5m | Warning |
| HighMemoryUsage | Memory >90% for >5m | Warning |
| HighNodeTemperature | Temp >75C for >5m | Warning |

### Kubernetes Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| PodCrashLooping | >5 restarts in 1h | Warning |
| PodNotReady | Not ready for >10m | Warning |
| DeploymentReplicasMismatch | Replicas mismatch >10m | Warning |

### Storage Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| PVCAlmostFull | PVC >85% full | Warning |
| DiskSpaceLow | Disk <15% available | Warning |

---

## External GPU Worker (Visage)

The Visage GPU worker runs on an external Mac with Apple Silicon and pushes metrics via Pushgateway:

```bash
export PUSHGATEWAY_URL=https://pushgateway.eldertree.local
```

Metrics available:
- `visage_training_progress_percent` - Training completion
- `visage_training_loss` - Current loss value
- `visage_training_step` - Current step
- `visage_images_generated_total` - Images generated

---

## Useful PromQL Queries

### Cluster Health

```promql
# Nodes ready (should be 3)
sum(kube_node_status_condition{condition="Ready",status="true"})

# Total running pods
sum(kube_pod_status_phase{phase="Running"})

# Container restarts (last hour)
sum(increase(kube_pod_container_status_restarts_total[1h]))

# Vault HA pods
sum(kube_pod_status_phase{namespace="vault", pod=~"vault-.*", phase="Running"})
```

### Resource Usage

```promql
# Cluster CPU usage %
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Cluster memory usage %
(1 - (sum(node_memory_MemAvailable_bytes) / sum(node_memory_MemTotal_bytes))) * 100

# CPU by namespace
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)

# Memory by namespace
sum(container_memory_working_set_bytes) by (namespace)

# Top 5 memory consumers
topk(5, sum(container_memory_working_set_bytes{container!=""}) by (pod, namespace))
```

### Storage

```promql
# PV usage %
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100

# Root disk usage %
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# PVCs over 80% full
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) > 0.8
```

### Network

```promql
# Network receive by namespace
sum(rate(container_network_receive_bytes_total[5m])) by (namespace)

# Traefik request rate by service
sum(rate(traefik_service_requests_total[5m])) by (service)
```

### Application Metrics

```promql
# API request rate by app
sum(rate(traefik_service_requests_total{service=~".*-api.*"}[5m])) by (service, code)

# API response time p95
histogram_quantile(0.95, sum(rate(traefik_service_request_duration_seconds_bucket{service=~".*-api.*"}[5m])) by (le, service))

# PostgreSQL connections
pg_stat_activity_count

# Redis memory
redis_memory_used_bytes
```

### Hardware (Raspberry Pi)

```promql
# Node temperature
node_hwmon_temp_celsius

# Max temperature across nodes
max(node_hwmon_temp_celsius)

# Average cluster temperature
avg(node_hwmon_temp_celsius)
```

---

## Adding New Dashboards

### From Grafana.com

Add to `values.yaml` under `grafana.dashboards.default`:

```yaml
my-dashboard:
  gnetId: 12345
  revision: 1
  datasource: Prometheus
```

### Custom Dashboard

1. Create JSON file in `dashboards/` directory
2. Include `eldertree` tag for consistency
3. Use proper UID format: `app-name-dashboard`
4. Dashboard will be auto-deployed via ConfigMap

### App with monitoring.yaml

1. Add `monitoring.yaml` to app repository
2. Run generator: `workspace-config/monitoring/generator/generate.sh app-name`
3. Generated dashboard will be placed in `dashboards/`

---

## Quick Tips

- Use time range selectors for historical analysis
- Alertmanager shows firing alerts - check first during incidents
- Dashboards are editable - customize for your needs
- Export custom dashboards via JSON for backup
- Pushgateway metrics expire after 5 minutes if not refreshed
- Use `{namespace="app-name"}` to filter by application
- Temperature >70C triggers throttling on Raspberry Pi
