# Visage — archived infrastructure reference (2026-04)

**Status:** ARCHIVED — not deployed on Eldertree by default.

This folder preserves **historical** pi-fleet observability and scrape configs for [Visage](https://github.com/raolivei/visage). They are **not** applied by Flux/kustomize.

| File | Was used for |
|------|----------------|
| `visage-scrape-config.yaml` | Prometheus scrape for `visage-api` and `visage-redis` |
| `visage-operations.json` | Grafana operations dashboard |
| `visage-training.json` | Grafana training / GPU metrics dashboard |

**Live cluster:** Remove namespace `visage` and tunnel/DNS when you want resources back — optional; see [workspace-config/docs/PROJECT_DECOMMISSIONING.md](../../../workspace-config/docs/PROJECT_DECOMMISSIONING.md).

**App manifests:** Remain in the Visage repo under `k8s/` for reference.
