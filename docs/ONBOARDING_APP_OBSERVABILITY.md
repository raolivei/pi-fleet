# Onboarding a new Eldertree app to Prometheus & Grafana

Workspace standard: [`workspace-config/docs/OBSERVABILITY_STANDARDS.md`](../../workspace-config/docs/OBSERVABILITY_STANDARDS.md)

## Checklist (single PR to `pi-fleet`)

### Metrics

- [ ] App exposes `/metrics` (or document why not)
- [ ] **Option A:** Add `prometheus.io/scrape` annotations on the Kubernetes **Service** (HelmRelease / Deployment)
- [ ] **Option B:** Add `clusters/eldertree/observability/<app>-scrape-config.yaml` with top-level `scrape_configs:` and wire mounts in `helm/monitoring-stack/values.yaml`
- [ ] If Postgres/Redis: use shared [`postgres-exporter.yaml`](../clusters/eldertree/observability/postgres-exporter.yaml) / [`redis-exporter.yaml`](../clusters/eldertree/observability/redis-exporter.yaml) — add DB target there, do not deploy another exporter chart

### Dashboards & alerts

- [ ] Add `helm/monitoring-stack/dashboards/<app>-dashboard.json`
- [ ] Register in `grafana.dashboardFolders` in `values.yaml`
- [ ] Bump `Chart.yaml` version + `monitoring-stack-helmrelease.yaml` `spec.chart.spec.version`
- [ ] Add alerts to `prometheus.serverFiles` only if app-specific (reuse node/pod alerts when possible)

### External URL

- [ ] Add to blackbox targets in `values.yaml` if the app has a public HTTPS URL

### Verify

```bash
# After Flux reconcile or helm upgrade
kubectl port-forward -n observability svc/observability-monitoring-stack-prometheus-server 9090:80
# Targets → job for your app should be UP

# Grafana → Dashboards → Applications/<YourApp>
```

### App repo (DRY)

- [ ] Document metrics endpoint in app `README.md` / `CLAUDE.md`
- [ ] Link to this checklist; **do not** provision production Grafana from the app repo
- [ ] Optional: keep dev-only `docker-compose` + local Prometheus
