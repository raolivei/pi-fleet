# Grafana Dashboards

Grafana: `https://grafana.eldertree.local` (or NodePort from `SERVICES_REFERENCE.md` if you use it).

## How dashboards get here

| Source | Mechanism |
|--------|-----------|
| **Custom JSON** | Files in [`dashboards/`](./dashboards/) are packaged by the chart into ConfigMaps (`dashboard-<name>`) in the Helm release namespace. The Grafana sidecar **only** watches namespace `observability` for `grafana_dashboard: "1"`. |
| **Grafana.com** | [`values.yaml`](./values.yaml) under `grafana.dashboards.default` (`gnetId` + `revision`). Downloaded by the Grafana subchart on deploy. |

**Verification (repo):** All **12** `dashboards/*.json` files parse as valid JSON. `visage-training.json` had broken string escaping in three `expr` fields (`job=~"..."`); that is fixed so provisioning does not silently fail.

**URL pattern:** `https://grafana.eldertree.local/d/<uid>` (optional slug: `/d/<uid>/<slug>`).

---

## Access URLs

| Service      | URL                                        | Notes |
|--------------|--------------------------------------------|-------|
| Grafana      | `https://grafana.eldertree.local`          | Admin from Vault / default |
| Prometheus   | `https://prometheus.eldertree.local`       | Targets, graph |
| Alertmanager | `https://alertmanager.eldertree.local`     | Alert routing |
| Pushgateway  | `https://pushgateway.eldertree.local`      | External workers (e.g. Visage GPU) |
| Loki         | In-cluster `loki.observability:3100`     | Use Grafana → Explore (Loki datasource) |

---

## Tag taxonomy (Grafana tags)

Use these when adding or editing dashboards for consistent browsing:

| Tag | Use for |
|-----|---------|
| `eldertree` | Any dashboard maintained for this cluster |
| `featured` | “Open first” (Ops Home, Command Center) |
| `overview` / `sre` | High-level or on-call panes |
| `kubernetes` / `workloads` / `network` / `traefik` | Platform layers |
| `applications` | App-specific (swimto, visage, pitanga, …) |
| `hardware` / `raspberry-pi` | Node temperature, Pi metrics |

Search in Grafana: **Dashboards** → filter by tag.

---

## A — Start here (on-call / featured)

| Dashboard | UID | File | What it shows |
|-----------|-----|------|----------------|
| **Eldertree Ops Home** | `eldertree-ops-home` | `eldertree-ops-home.json` | Links to other UIDs, blackbox `probe_success`, Traefik `up`, `swimto_db_users_total` |
| **Eldertree Command Center** | `eldertree-command-center` | `command-center.json` | Cluster health, resources, Traefik, PVC, top consumers, problem pods |
| **Eldertree Cluster Overview** | `eldertree-cluster` | `eldertree-cluster.json` | 3-node HA, namespaces, infra + app service rows (summary; not per-app deep dives) |

**Direct links:** [`/d/eldertree-ops-home`](https://grafana.eldertree.local/d/eldertree-ops-home) · [`/d/eldertree-command-center`](https://grafana.eldertree.local/d/eldertree-command-center) · [`/d/eldertree-cluster`](https://grafana.eldertree.local/d/eldertree-cluster)

---

## B — Platform & capacity (custom JSON)

| Dashboard | UID | File | What it shows |
|-----------|-----|------|----------------|
| **Kubernetes Workloads** | `kubernetes-workloads` | `kubernetes-workloads.json` | Deployments, StatefulSets, Jobs, restarts, CPU/memory request vs use |
| **Cluster Resource Usage by Namespace** | `namespace-resources` | `namespace-resources.json` | Per-namespace CPU/memory/network, top consumers, trends |
| **Network Intelligence** | `network-intelligence` | `network-intelligence.json` | Traefik request rates, codes, top services, node network |
| **Hardware Health** | `hardware-health` | `hardware-health.json` | Raspberry Pi temperature, load, disk, I/O |

---

## C — Applications (custom JSON)

| Dashboard | UID | File | What it shows |
|-----------|-----|------|----------------|
| **SwimTO** | `swimto-dashboard` | `swimto-dashboard.json` | Traefik + pods + Postgres/Redis for SwimTO |
| **Pitanga & NorthwaySignal** | `pitanga-dashboard` | `pitanga-dashboard.json` | Traffic and resources for pitanga / NorthwaySignal sites |
| **Visage Operations** | `visage-ops` | `visage-operations.json` | API, workers, Redis, MinIO, Postgres, GPU worker (Pushgateway) |
| **Visage Training** | `visage-training` | `visage-training.json` | Training loss, step, progress, images, queue (Pushgateway + cluster) |
| **Vault Operations** (custom) | `vault-ops` | `vault-dashboard.json` | Vault sealed, raft, tokens, requests — **Eldertree-focused** panels |

> **Not shipped as separate JSON in this folder:** Canopy, Journey, NIMA, Ollie, iPhone export, US Law map. If those apps need first-class dashboards, add new `dashboards/<app>.json` and a chart version bump, or rely on **Eldertree Cluster** / **K8s Views** until then.

---

## D — Upstream (Grafana.com) — `values.yaml`

These are **not** files under `dashboards/`; they are pulled by ID at deploy time. Datasource: **Prometheus** unless you add a Loki-based dashboard later.

### Kubernetes (views & control plane)

| Key in values | gnetId | rev | Role |
|---------------|--------|-----|------|
| `k8s-views-global` | 15757 | 37 | Cluster-wide K8s health |
| `k8s-views-namespaces` | 15758 | 34 | Per-namespace |
| `k8s-views-pods` | 15759 | 28 | Pod-level |
| `k8s-apiserver` | 12006 | 1 | API server (HA) |
| `k8s-persistent-volumes` | 13646 | 2 | PV / PVC |
| `k8s-compute-resources-namespace` | 15661 | 1 | CPU/memory by namespace (alt. view) |
| `k8s-compute-resources-pod` | 15662 | 1 | CPU/memory by pod (alt. view) |

### Node & ingress & DNS

| Key | gnetId | rev | Role |
|-----|--------|-----|------|
| `node-exporter-full` | 1860 | 37 | Node exporter (compare with **Hardware Health** for Pi-focused view) |
| `traefik` | 11462 | 1 | **Upstream** Traefik template (Eldertree also uses custom **Network Intelligence**) |
| `coredns` | 14981 | 2 | CoreDNS |
| `pihole` | 10176 | 1 | Pi-hole |

### GitOps, TLS, external secrets

| Key | gnetId | rev | Role |
|-----|--------|-----|------|
| `flux-cluster` | 15991 | 1 | Flux |
| `cert-manager` | 11001 | 1 | Certificates |
| `external-secrets` | 15159 | 1 | ESO → Vault sync |

### HA & data stores

| Key | gnetId | rev | Role |
|-----|--------|-----|------|
| `etcd` | 3070 | 3 | etcd (k3s control plane) |
| `vault` | 12904 | 2 | **Generic** Vault dashboard (complements custom **`vault-ops`**) |
| `postgresql-database` | 9628 | 7 | Generic Postgres |
| `redis` | 763 | 6 | Generic Redis |

---

## Overlaps (intentional)

| Topic | Custom | Upstream / other |
|-------|--------|-------------------|
| Traefik / edge | `network-intelligence.json`, app dashboards | `traefik` (gnet 11462) |
| Vault | `vault-dashboard.json` (`vault-ops`) | `vault` (gnet 12904) |
| Node / hardware | `hardware-health.json` | `node-exporter-full` (gnet 1860) |
| K8s capacity | `namespace-resources.json`, `kubernetes-workloads.json` | k8s-views-* gnet dashboards |

---

## Alerting

Alertmanager: `https://alertmanager.eldertree.local`

| Group | Examples |
|-------|----------|
| Node | `NodeDown`, `HighCPUUsage`, `HighMemoryUsage`, `HighNodeTemperature` |
| Kubernetes | `PodCrashLooping`, `PodNotReady`, `DeploymentReplicasMismatch` |
| Storage | `PVCAlmostFull`, `DiskSpaceLow` |
| Synthetic | `BlackboxProbeFailing` (`job=~"blackbox-.*"`) |

(Full conditions live in `values.yaml` `prometheus.serverFiles.alerting_rules.yml`.)

---

## Source of truth (HTTP / app metrics, Traefik v3)

| Signal | Source | Notes |
|--------|--------|--------|
| Edge (per service, code) | Traefik `traefik_service_requests_total`, etc. | `service` like `swimto-swimto-api-8000@kubernetes` |
| App RED | App `/metrics` (e.g. FastAPI `http_requests_total`) | `prometheus.io/*` on the **Service** |
| Product DB depth (SwimTO) | `swimto_db_users_total` | From API; **Eldertree Ops Home** |
| Postgres / Redis | Exporters in `observability` | See `postgres-exporter.yaml`, `redis-exporter.yaml` |

**Traefik scrape:** static target `traefik.kube-system:9100` (see `core-infrastructure/traefik-config.yaml`). **Loki** datasource in `values.yaml`; **Promtail** ships node logs (see cluster observability manifests).

---

## External GPU worker (Visage)

Push metrics to Pushgateway: `https://pushgateway.eldertree.local`

- `visage_training_*`, `visage_images_*`, `visage_queue_*` — see **Visage Operations** / **Visage Training** panels.

---

## Useful PromQL

### Cluster health

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

### Resource usage

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

### Application metrics

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

## Adding dashboards

1. **Custom:** Add `dashboards/<name>.json` with a stable **`uid`**, `eldertree` in **`tags`**, and bump the **monitoring-stack** chart version in `Chart.yaml` + `HelmRelease`.
2. **Grafana.com:** Add a key under `grafana.dashboards.default` in `values.yaml` (`gnetId`, `revision`, `datasource: Prometheus`).

### App with `monitoring.yaml` (optional)

Some apps use `workspace-config/monitoring/generator/generate.sh` — see pi-fleet / workspace-config docs; generated JSON still lands in `dashboards/` when committed.

---

## Quick tips

- **Browse by tag** in Grafana to see featured vs platform vs apps.
- **Alertmanager** is the first place to check for firing alerts.
- **Pushgateway** metrics disappear if the worker stops pushing for ~5 minutes.
- **Temperature** on Pis: throttling can start above ~70–75°C; see **Hardware Health** and node alerts.
- Re-export custom JSON after big edits in the UI and commit back to `dashboards/` if you want Git to stay canonical.
