# Observability retention and storage (Eldertree)

Plan and runbook for **90-day metrics** (Prometheus) and **30-day logs** (Loki) on NVMe-backed `local-path-nvme` PVCs. Extend Loki to 90d after measuring ingest (see [GitHub issue](https://github.com/raolivei/pi-fleet/issues)).

## Targets

| Component | Retention | PVC | Storage class | Notes |
|-----------|-----------|-----|---------------|-------|
| **Prometheus** | **90d** | **64Gi** | `local-path-nvme` | `retentionSize: 58GB` safety cap (~90% of PVC) |
| **Loki** | **30d** (`720h`) | **48Gi** | `local-path-nvme` | Extend to 90d after 1-week ingest measure |
| **Alertmanager** | ~5d (default) | **2Gi** | `local-path-nvme` | Silence/notification history |
| **Grafana** | dashboards | 2Gi | `local-path` | Unchanged (not time-series) |

Git sources:

- [`clusters/eldertree/observability/monitoring-stack-helmrelease.yaml`](../clusters/eldertree/observability/monitoring-stack-helmrelease.yaml)
- [`clusters/eldertree/observability/loki.yaml`](../clusters/eldertree/observability/loki.yaml)
- [`clusters/eldertree/core-infrastructure/storage-class-nvme.yaml`](../clusters/eldertree/core-infrastructure/storage-class-nvme.yaml)

## Why NVMe + stable nodes

- Observability PVCs were **8Gi / 7d** on `local-path` (often SD-backed); retention was cut to save **node-3** disk.
- Each Pi has **~238Gi NVMe** at `/mnt/nvme/storage` via `local-path-nvme`.
- Prometheus and Loki use **ReadWriteOnce** volumes — schedule on **`eldertree.xyz/node-tier: stable`** (node-2, node-3) and keep both PVCs on the **same node** during migration.

## Phase 0 — Baseline (before changing PVCs)

```bash
export KUBECONFIG=~/.kube/config-eldertree

# PVC placement
kubectl get pvc -n observability -o wide

# Prometheus TSDB
curl -sSk https://prometheus.eldertree.local/api/v1/status/tsdb | jq .
curl -sSk https://prometheus.eldertree.local/api/v1/query \
  --data-urlencode 'query=prometheus_tsdb_head_series' | jq .

# Loki disk
kubectl exec -n observability deploy/loki -- du -sh /loki 2>/dev/null || true

# NVMe free space on observability node (SSH to node hosting PVCs)
df -h /mnt/nvme
```

Record results in the tracking issue.

## Phase 1 — Apply Git changes (Flux)

1. Merge PR with retention + `local-path-nvme` + `allowVolumeExpansion: true`.
2. Reconcile:

```bash
flux reconcile helmrelease monitoring-stack -n observability
flux reconcile kustomization observability -n flux-system --with-source
```

**Note:** Changing `storageClass` or `size` on an existing PVC does **not** resize or migrate data automatically. Phase 2 required for Prometheus/Loki data volumes.

## Phase 2 — PVC migration (one-time, ~15 min downtime)

Perform during a maintenance window. Old data on 8Gi volumes is discarded unless you snapshot first.

### Prometheus

```bash
# Scale down
kubectl scale deploy -n observability observability-monitoring-stack-prometheus-server --replicas=0

# Delete old PVC (after backup if needed)
kubectl delete pvc -n observability prometheus-server

# Flux/Helm recreate with new spec — or helm upgrade with new values
flux reconcile helmrelease monitoring-stack -n observability

kubectl scale deploy -n observability observability-monitoring-stack-prometheus-server --replicas=1
kubectl get pvc -n observability -w
```

### Loki

```bash
kubectl scale deploy -n observability loki --replicas=0
kubectl delete pvc -n observability loki-data
kubectl apply -k clusters/eldertree/observability   # or wait for Flux
kubectl scale deploy -n observability loki --replicas=1
```

Verify both new PVCs bound on the **same stable node** with NVMe:

```bash
kubectl get pvc -n observability -o custom-columns=NAME:.metadata.name,SC:.spec.storageClassName,SIZE:.spec.resources.requests.storage,NODE:.metadata.annotations.volume\.kubernetes\.io/selected-node
```

## Phase 3 — Verify retention

```bash
# Prometheus flags
kubectl exec -n observability deploy/observability-monitoring-stack-prometheus-server -- \
  prometheus --version 2>/dev/null; \
kubectl get deploy -n observability observability-monitoring-stack-prometheus-server -o yaml | grep -A2 retention

# Loki retention (720h = 30d)
kubectl exec -n observability deploy/loki -- cat /etc/loki/loki.yaml | grep retention_period

# Grafana: query range > 7d on a known metric
```

Watch disk for the first week:

```bash
# Prometheus TSDB size trend
curl -sSk 'https://prometheus.eldertree.local/api/v1/query?query=prometheus_tsdb_storage_blocks_bytes' | jq .

# Alert: kubelet volume stats if configured
```

## Phase 4 — Extend Loki to 90d (optional)

Only after **7 days** of stable ingest on 48Gi:

1. Estimate: `(du /loki after 7d) × (30/7)` for 30d actual; compare to 48Gi headroom.
2. If ≤70% projected, set `retention_period: 2160h` and `reject_old_samples_max_age: 2160h` in `loki.yaml`.
3. Expand PVC to 96Gi if needed (`allowVolumeExpansion: true` on StorageClass).

## Promtail noise reduction

[`promtail.yaml`](../clusters/eldertree/observability/promtail.yaml) drops common probe/health lines. Add namespace-specific drops if ingest remains high.

## Alerts

Use existing **storage-alerts** in `helm/monitoring-stack/values.yaml`. Confirm firing thresholds cover:

- Node disk where observability PVCs live (`node_filesystem_avail_bytes` on `/mnt/nvme`)
- Prometheus `prometheus_tsdb_storage_blocks_bytes` vs PVC size

## Cold backup (optional)

The 60GB USB at `/mnt/backup` is **not** sized for continuous 90d observability mirrors. Optional monthly:

```bash
kubectl exec -n observability deploy/observability-monitoring-stack-prometheus-server -- \
  promtool tsdb snapshot /data/prometheus
```

Copy snapshot off-cluster if needed for disaster recovery metadata — not a substitute for retention on NVMe.

## Related

- [OBSERVABILITY_BLACKBOX_AND_SYNTHETIC.md](./OBSERVABILITY_BLACKBOX_AND_SYNTHETIC.md)
- [NVME_STORAGE_SETUP.md](./NVME_STORAGE_SETUP.md)
- [helm/monitoring-stack/DASHBOARDS.md](../helm/monitoring-stack/DASHBOARDS.md) — TSDB head series diagnostics
- Workspace [OBSERVABILITY_STANDARDS.md](https://github.com/raolivei/workspace-config/blob/main/docs/OBSERVABILITY_STANDARDS.md)
