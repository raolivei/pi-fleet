# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/). Dates are ISO 8601.

## [Unreleased]

### Added

- **bolao Cloudflare** — Tunnel ingress + CNAME `bolao.eldertree.xyz`; origin TLS ExternalSecret; public ingress excludes External-DNS (same pattern as canopy/swimTO).

- **bolao ARC runner** — `gha-runner-scale-set` for `raolivei/bolao` (`bolao-eldertree`).

- **bolao Flux wiring** — Register `clusters/eldertree/bolao` in root kustomization; routing registry, postgres-exporter, monitoring-stack 0.2.17 dashboard folder.

- **BIND9 LAN DNS (`helm/bind9`)** — Replaces Pi-hole (#232): authoritative `eldertree.local` on VIP `192.168.2.201`, RFC2136 on port 53. external-dns host `bind9.bind.svc.cluster.local`.
- **BIND9 cutover scripts** — [`scripts/cutover-bind9-dns.sh`](scripts/cutover-bind9-dns.sh), [`scripts/check-bind9-status.sh`](scripts/check-bind9-status.sh), [`scripts/diagnose-bind9-dns-mac.sh`](scripts/diagnose-bind9-dns-mac.sh).
- **ARC repo-scoped scale sets** — Per-repo `gha-runner-scale-set` HelmReleases for `pi-fleet-blog`, `elder`, `github-workflows`, `canopy`, `swimTO`, `personal-website`, `northwaysignal-website`, `nima`, `eldertree-docs` (each `githubConfigUrl: https://github.com/raolivei/<repo>`). `raolivei` is a GitHub User, not an Organization, so org-scope ARC is unavailable; each repo needs its own listener. Runner pods right-sized to 250m+100m CPU requests so 4+ schedule concurrently on Pi 5 stable nodes.
- **ARC repo PAT setup** — [`scripts/operations/setup-arc-repo-github-pat.sh`](scripts/operations/setup-arc-repo-github-pat.sh) writes a `repo`+`workflow` token to Vault and verifies repo-scoped registration. `setup-arc-org-github-pat.sh` now delegates to it.
- **ARC load-test scripts** — [`scripts/stress-arc-runners.sh`](scripts/stress-arc-runners.sh) (gated to repos with a deployed scale set via `ARC_REPOS`) and [`scripts/monitor-arc-runners.sh`](scripts/monitor-arc-runners.sh) (live runner/listener/node view).
- **Flux Helm naming guide** — [`docs/FLUX_HELM_NAMING.md`](docs/FLUX_HELM_NAMING.md): require explicit `releaseName` on all HelmReleases; migration map for doubled releases.
- **Control Center public** — `control.eldertree.xyz` Cloudflare Tunnel ingress rule + DNS CNAME; OpenClaw `control-center-public` ingress with `*.eldertree.xyz` origin cert (ExternalSecret).
- **Ollie Helm chart** — Vendor `helm/ollie` from the [ollie](https://github.com/raolivei/ollie) repo so Flux `HelmRelease` path `./helm/ollie` resolves (fixes `InvalidChartReference`).

### Fixed

- **bolao public DNS** — Exclude `bolao.eldertree.xyz` from External-DNS on public ingress so Terraform owns the Cloudflare tunnel CNAME (canopy pattern).

- **Pi-hole Helm upgrade stalled (`loadBalancerClass`)** — HelmRelease used `loadBalancerClass: null` but live Service has immutable `kube-vip.io/kube-vip-class`; align values so exporter disable can roll out.
- **Pi-hole exporter ImagePullBackOff (arm64)** — `ghcr.io/mosher-labs/pihole6-exporter` has no arm64 manifest; pod stayed 2/3 Ready with **empty Service endpoints**, breaking RFC2136 external-dns. Chart adds `exporter.enabled` (off on Eldertree until arm64 image exists).
- **external-dns RFC2136 crash loop** — `EXTERNAL_DNS_RFC2136_HOST` pointed at stale Pi-hole ClusterIP `10.43.117.25`; updated to current `10.43.153.12` (`kubectl get svc -n pi-hole pi-hole`).
- **ExternalSecret Vault path drift** — `ollie`, `personal-website`, and `pitanga` `ghcr-secret` now read `secret/canopy/ghcr-token` (same as swimto/canopy). `ollie-secrets` reads `secret/elder/api-key` and `secret/openclaw/openrouter` instead of missing `secret/pi-fleet/*` paths.
- **Grafana/KEDA Prometheus DNS after Helm naming migration** — Grafana datasource, KEDA `serverAddress`, and pushgateway ingress pointed at removed `observability-monitoring-stack-prometheus-server`; updated to `monitoring-stack-prometheus-server`. monitoring-stack chart **0.2.15**.
- **Ollie training CronJob ImagePullBackOff** — `ghcr.io/raolivei/ollie-training:latest` was never published (not in ollie `build-publish.yaml`). Disable `training.enabled` until the image is built and pushed.
- **ARC runner pods Pending** — Drop `node-tier: stable` nodeSelector (node-1 was ~99% free but excluded while node-2 at 98% CPU requests and node-3 NotReady under load). Lower runner requests to 100m CPU / 512Mi.

### Changed

- **bolao routing** — Align with SwimTO/pitanga: Caddy stanza next to swimto (Traefik VIP), drop custom localdev Caddy file; ingress keys `bolao-web-local` / `bolao-web-public`; `SERVICES_REFERENCE.md` entry.

- **monitoring-stack 0.2.16** — Drop Pi-hole Prometheus scrape mount; Grafana cluster dashboard shows `bind` namespace.
- **`stress-arc-runners.sh`** — include `github-workflows` in default `ARC_REPOS` (repo-scoped scale set deployed in Phase 1).
- **ARC ollie-runners** — Repo-scoped (`githubConfigUrl: https://github.com/raolivei/ollie`); `maxRunners: 1` (serial `build-publish.yaml`). Org scope reverted — requires a GitHub Organization entity.
- **pi-fleet CI** — Terraform and OpenClaw ARM64 build workflows revert to `ubuntu-latest` (pi-fleet has no scale set; terraform needs `~/.kube/config-eldertree` not present in ARC pods).
- **`runs-on` standardized to `['self-hosted']`** for repos with a scale set; Tier 4 repos (`repo-template`, `eldertree-chassis`, `fragment`) moved to `ubuntu-latest` (no scale set).
- **Helm release names (cluster-wide)** — Set `releaseName: <metadata.name>` on all Eldertree HelmReleases so Flux no longer creates doubled releases (`openclaw-openclaw`, `canopy-canopy`, `observability-monitoring-stack`, etc.). See migration table in `FLUX_HELM_NAMING.md`.
- **ARC HelmRepository** — Rename `arc-controller` → `arc-charts` in `flux-system` (serves both controller and scale-set OCI charts).
- **ARC ClusterRole** — Rename `arc-controller-gha-rs-controller-secrets` → `arc-controller-secrets`.
- **ARC manifests** — Rename `ollie-runner-helmrelease.yaml` → `ollie-runners-helmrelease.yaml`, `arc-helm-repository.yaml` → `arc-charts-helmrepository.yaml`.
- **ARC ollie-runners** — `maxRunners: 6` (matches ollie `build-publish.yaml` parallel jobs). Right-size runner + DinD resources (750m CPU / 1.5Gi mem requests per pod, down from 1 CPU / 2Gi) so more pods schedule on Pi 5 nodes; pin to `node-tier: stable` and prefer anti-affinity spread across node-2/node-3. Cap limits to reduce cluster-wide oversubscription (was 3 CPU / 4Gi per runner container).
- **Elder (Control Center)** — Image `ghcr.io/raolivei/elder:v0.3.6` (kube-vip DaemonSet health, topology layout variants).

### Fixed

- **Control Center 502 (`control.eldertree.xyz` / `.local`)** — OpenClaw NetworkPolicies used stale labels (`app: elder`, `name: traefik`) and port 8000 after the `releaseName` migration (`app: openclaw`, `component: elder`, Elder on 8006, Traefik in `kube-system`). Scope `openclaw-ingress-only` to `component: openclaw`; allow Traefik → Elder on 8006.
- **SwimTO 503 during node-1 reboots** — `node-1` watchdog reboots (hang → NotReady, 5× in 8h on 2026-06-07) took down single `swimto-api` pod scheduled on unstable tier. SwimTO API/web: **2 replicas**, **required** `node-tier != unstable`, **podAntiAffinity** across hosts; KEDA `minReplicaCount` 2 (API was 0). Monitoring-stack **0.2.14**: blackbox probes for `swimto.app` and `api.swimto.app/health`, alerts `SwimTOApiReplicasUnavailable`, `SwimTOApiPublicProbeFailing`, `SwimTOApiOnUnstableNode`.
- **ARC HelmRepository namespace** — Move `arc-charts-helmrepository.yaml` to `clusters/eldertree/` root so Kustomize does not rewrite `flux-system` → `arc-controller` (broke `HelmRepository "arc-charts" not found` after #219).
- **ARC runners stuck Pending** — `ollie-runners` HelmRelease `controllerServiceAccount.name` did not match the controller's real ServiceAccount (`arc-controller-gha-rs-controller`). Flux defaulted the controller Helm release name to `arc-controller-arc-controller`, producing SA `arc-controller-arc-controller-gha-rs-controller`. Set `releaseName: arc-controller` on the controller HelmRelease and point runners at `arc-controller-gha-rs-controller`.
- **Pi-hole HelmRelease** — `strategy: Recreate` and 20m upgrade timeout (RollingUpdate dual-pod upgrades caused Helm deadline exceeded).
- **control.eldertree.xyz DNS** — `scripts/cloudflare-reconcile-control-dns.sh` removes stale `control` A records before Terraform apply; runs in `terraform.yml` on apply.
- **Pi-hole (Helm 0.2.2)** — Remove zero-byte `gravity.db` init stub; postStart waits for web UI then runs `pihole -g` when db missing/empty. Metrics sidecar `ghcr.io/mosher-labs/pihole6-exporter` (Pi-hole v6 session auth).
- **Caddy / CoreDNS LAN routing** — `scripts/Caddyfile` proxies to Traefik kube-vip `192.168.2.200:443` (was `192.168.2.101:32474`, which hit Pi-hole on 443). CoreDNS custom hosts add `control.eldertree.local` and `elder.eldertree.local`.
- **Traefik VIP / Pi-hole 403** — Stop exposing HTTPS (443) on the Pi-hole LoadBalancer Service (`exposeHttpsOnLoadBalancer: false`) so K3s `svclb-traefik` can bind hostPort 443 on `192.168.2.200`; fixes all `*.eldertree.local` URLs (including Control Center) returning Pi-hole HTML.
- **Control Center routing** — Add `docs/eldertree-local-services.yaml`, `check-local-routing-registry.sh`, `verify-service-routing.sh`, and `docs/ONBOARDING_APP_ROUTING.md` / `CONTROL_CENTER.md`; sync hosts registry for `control.eldertree.local`.
- **Ollie GitOps** — Vendor `helm/ollie` chart into pi-fleet (Flux `HelmRelease` path `./helm/ollie`); ExternalSecrets `ClusterSecretStore` ref `vault-backend` → `vault` (matches live cluster).
- **Node scheduling tier reconciler** — Replace distroless `rancher/kubectl` (no `/bin/sh`, StartError) with `debian:bookworm-slim` + downloaded `kubectl v1.35.0` arm64; bump job memory for apt/curl install.

### Changed

- **Local routing sync** — `eldertree-local-hosts-block.txt`, `add-services-to-hosts.sh`, and `Caddyfile` aligned with registry (openclaw, alertmanager, docs, dex, audio, canopy, journey, nima).
- **Elder (Control Center)** — Image `ghcr.io/raolivei/elder:v0.3.0` (Control Center SPA + `/api/public/cluster/health`); ImageRepository tracks `elder` instead of legacy `grove`. Ingress `control.eldertree.local` → Elder service.
- **Visage archived (2026-04)** — Detached live monitoring (scrape, dashboards, exporter targets), tunnel/DNS, and hosts/Caddy entries; preserved reference copies under [`docs/archive/visage/`](docs/archive/visage/). See [`workspace-config/docs/PROJECT_DECOMMISSIONING.md`](../workspace-config/docs/PROJECT_DECOMMISSIONING.md).
- **Repo layout** — Moved `NETWORK.md`, `VAULT.md`, and `SERVICES_REFERENCE.md` into `docs/`; blog drafts and one-off session notes into `docs/archive/`; removed duplicate `blog/` tree at repo root. Root now holds README, CHANGELOG, CLAUDE, CONTRIBUTING, and `VERSION` only.

### Added

- **Service routing onboarding** — [`docs/ONBOARDING_APP_ROUTING.md`](docs/ONBOARDING_APP_ROUTING.md): end-to-end LAN checklist; [`docs/eldertree-local-services.yaml`](docs/eldertree-local-services.yaml) registry; [`scripts/check-local-routing-registry.sh`](scripts/check-local-routing-registry.sh) and [`scripts/verify-service-routing.sh`](scripts/verify-service-routing.sh) for cluster + Pi-hole + Mac verification.
- **Observability retention (NVMe)** — [`docs/OBSERVABILITY_RETENTION.md`](docs/OBSERVABILITY_RETENTION.md): 90d Prometheus metrics (64Gi `local-path-nvme`, `retentionSize: 58GB`), 30d Loki logs (48Gi NVMe, extend to 90d after measure), stable-node affinity, Promtail probe/health log drops, PVC migration runbook. monitoring-stack chart **0.2.13**.
- **Control Center ops doc** — [`docs/CONTROL_CENTER.md`](docs/CONTROL_CENTER.md): architecture, URLs, API, troubleshooting for `control.eldertree.local`.
- **Control Center local dev** — `control.eldertree.local` in `scripts/Caddyfile`, `add-services-to-hosts.sh`, `setup-caddy-proxy.sh`, and `docs/eldertree-local-hosts-block.txt` for LAN Caddy testing of the Elder ops console (cluster ingress via OpenClaw HelmRelease).

### Added

- **Node scheduling tiers** — node-1 deprioritized; Flux reconciler CronJob (reads from ConfigMap), ConfigMap auto-synced from Ansible group_vars, Ansible (`configure-node-scheduling-tiers`, `sync-node-scheduling-config`, host_vars, hooks in setup-cluster/watchdog/install-k3s), `eldertree-app` affinity, vault-auto-unseal on stable nodes; [NODE_SCHEDULING.md](docs/NODE_SCHEDULING.md). Node names/tiers configurable via `ansible/group_vars/all.yml` — no hardcoded values in CronJob script.
- **Ollie Grafana dashboard** — `helm/monitoring-stack/dashboards/ollie-dashboard.json` with request rate, latency, ChromaDB hit rate, LLM provider split, error rate, and resource usage panels.

### Fixed

- **Ollie HelmRelease** — remove invalid top-level `spec.imagePullSecrets` (not in `helm.toolkit.fluxcd.io/v2` schema); unblocks `flux-system` kustomization dry-run.
- **Ollie HelmRelease API** — bump `clusters/eldertree/ollie/helmrelease.yaml` from deprecated `helm.toolkit.fluxcd.io/v2beta1` to `v2` so `flux-system` kustomization dry-run succeeds (cluster CRD no longer serves `v2beta1`).
- **ExternalSecret `pi-fleet-terraform-vault-credentials`** — drop optional `pi-user` Vault key so sync succeeds when that secret is absent.

### Changed

- **Grafana (monitoring-stack 0.2.11)** — `hardware-health` and `eldertree-ops-home` panels for watchdog, freeze signal, OOM, and node uptime/reboot (metrics behind `WatchdogServiceDown`, `NodePingableButNotReady`, `NodeUnexpectedReboot`).

### Changed

- **HCP token Vault path** — active secret at `secret/pi-fleet/terraform/eldertree-github-2026` (`token`); loaders and ExternalSecret read this path (fallback: `terraform-cloud-token`).

### Added

- **Vault-first Terraform secrets** — [`docs/VAULT_TERRAFORM_SECRETS.md`](docs/VAULT_TERRAFORM_SECRETS.md); [`scripts/lib/load-terraform-secrets-from-vault.sh`](scripts/lib/load-terraform-secrets-from-vault.sh); [`setup-terraform-cloud-token.sh`](scripts/setup-terraform-cloud-token.sh); ExternalSecret `pi-fleet-terraform-vault-credentials`; `run-terraform.sh` loads HCP token from Vault.
- **Scripts** — [`sync-github-terraform-secrets-from-vault.sh`](scripts/sync-github-terraform-secrets-from-vault.sh) publishes Vault → GitHub Actions/Dependabot (CI cache).
- **ElderTree project hub** — [`docs/ELDERTREE.md`](docs/ELDERTREE.md), [`scripts/operations/eldertree-open.sh`](scripts/operations/eldertree-open.sh), updated [`clusters/eldertree/README.md`](clusters/eldertree/README.md).
- **InfraOPS & o11y standards** — Agent [`eldertree-infraops`](.claude/agents/eldertree-infraops.md); [`docs/ONBOARDING_APP_OBSERVABILITY.md`](docs/ONBOARDING_APP_OBSERVABILITY.md); workspace [`OBSERVABILITY_STANDARDS.md`](../workspace-config/docs/OBSERVABILITY_STANDARDS.md) (DRY monitoring checklist).
- **Hardware** — [`docs/HARDWARE_CHASSIS.md`](docs/HARDWARE_CHASSIS.md) links mechanical CAD to [eldertree-chassis](https://github.com/raolivei/eldertree-chassis); README hardware section updated.

### Changed

- **Docs** — Worker-node and `check-new-pi.sh` switch references updated from legacy TP-Link SG105 to **TL-SG1008MP** (PoE+ cluster switch).

### Fixed

- **Prometheus scrape config files** — Pi-hole, Visage, and Vault fragments use top-level `scrape_configs:` (fixes CrashLoop `cannot unmarshal !!seq into config.ScrapeConfigs`).
- **Hardware watchdog (all nodes)** — Disable Raspberry Pi OS `40-rpi-enable-watchdog.conf` and set `RuntimeWatchdogSec=0` so the watchdog daemon holds `/dev/watchdog`. Add `watchdog-k3s-health.sh` test-binary (k3s, kubelet healthz, API :6443), peer-only ping targets, persistent journald, improved `scripts/verify-watchdog.sh`. Prometheus alerts `WatchdogServiceDown` and `NodePingableButNotReady` (monitoring-stack **0.2.10**). See `docs/NODE-1-HANG-2026-05-26-SECOND.md`.

### Changed

- **Prometheus (monitoring-stack 0.2.9)** — Moved `extraSecretMounts` / `extraConfigmapMounts` scrape config paths from `/etc/config/*.yaml` to `/etc/scrape-configs/*.yaml`. Root cause: the kubelet creates an empty placeholder directory in the `config-volume` backing store for every subPath mount that targets a path inside `/etc/config/`. runc then fails to bind-mount the file over that directory (`MS_BIND|MS_REC` on a file-vs-directory path → `ENOTDIR`), causing Prometheus CrashLoopBackOff (568 restarts, 47 h) with `not a directory` in the containerd shim error. Using a separate `/etc/scrape-configs/` directory avoids the collision entirely; ClusterIP scrape via Prometheus `scrapeConfigFiles` unchanged. `clusters/eldertree/observability/monitoring-stack-helmrelease.yaml` chart `0.2.9`.
- **Traefik (core-infrastructure/traefik-config.yaml)** — `ports.metrics.expose.default: false` (was `true`). k3s ServiceLB creates `svclb-traefik-*` pods with `hostPort` for every port on the LoadBalancer service; exposing Traefik metrics on port 9100 occupied `hostPort 9100` on all 3 nodes, blocking the `prometheus-node-exporter` DaemonSet from scheduling for 47 h. Prometheus continues to scrape Traefik via ClusterIP (`traefik.kube-system.svc.cluster.local:9100`) — no change to metrics collection.
- **Kubeconfig scripts** — [`scripts/setup-kubeconfig-eldertree.sh`](scripts/setup-kubeconfig-eldertree.sh) and [`scripts/update-kubeconfig-ha.sh`](scripts/update-kubeconfig-ha.sh) set the API server to the kube-vip WiFi VIP **`192.168.2.100:6443`** (was node-1 LAN IP in the legacy setup path). [`docs/LENS_CONNECTION_GUIDE.md`](docs/LENS_CONNECTION_GUIDE.md) and [`docs/TAILSCALE.md`](docs/TAILSCALE.md): troubleshooting / script path for `192.168.2.100:6443` timeouts → use `config-eldertree-remote` + Tailscale.
- **Grafana (monitoring-stack)** — Custom provisioned dashboards use **folder paths** via sidecar `folderAnnotation` (`grafana_folder`): **Applications** (`…/SwimTO`, `…/Pitanga`, `…/Visage`) vs **Platform** (Overview, Cluster, Workloads, …). Mapping in [`values.yaml`](helm/monitoring-stack/values.yaml) `grafana.dashboardFolders`; ConfigMaps from [`templates/dashboards.yaml`](helm/monitoring-stack/templates/dashboards.yaml). Chart **0.2.8** ([`monitoring-stack-helmrelease.yaml`](clusters/eldertree/observability/monitoring-stack-helmrelease.yaml)); [`DASHBOARDS.md`](helm/monitoring-stack/DASHBOARDS.md) documents folders.
- **Flux (Eldertree)** — Standardize **`spec.interval` to `30m`** for **GitRepository** / root **Kustomization** ([`gotk-sync.yaml`](clusters/eldertree/flux-system/gotk-sync.yaml)), **app Kustomizations** (`pitanga`, `personal-website`), **HelmReleases** that differed (OpenClaw `5m` → `30m`, Pi-hole `1h` → `30m`, Reloader `12h` → `30m`, cert-manager issuers `10m` → `30m`), and **image automation** / **ImageRepository** resources that were `5m` → `30m`. **Helm `chart.spec.interval`** (e.g. `12h` chart index pulls) unchanged. Less frequent **LAST UPDATED** churn in the UI; Git changes can take up to ~30m to apply unless you `flux reconcile` manually.
- **monitoring-stack (Prometheus)** — **prometheus-community** subchart **28.x**; global **`scrape_interval`** / **`evaluation_interval`** **60s**; static jobs in **`scrapeConfigs`** (postgres, redis, blackbox, traefik) at **60s**; Pi-hole / Visage / Vault via **`scrape_config_files`** and **`server.extraSecretMounts`** / **`extraConfigmapMounts`**; **`kubernetes-nodes-cadvisor`** **`metric_relabel_configs`** **`labeldrop`** on cAdvisor `id` and `image` (lowers TSDB head cardinality; dashboards use `namespace`/`pod`/`container`). [`DASHBOARDS.md`](helm/monitoring-stack/DASHBOARDS.md) documents TSDB head series diagnostics. Chart `0.2.8` ([`monitoring-stack-helmrelease.yaml`](clusters/eldertree/observability/monitoring-stack-helmrelease.yaml)); reconcile Flux.
- **personal-website** — HelmRelease image tag `v0.2.1` (Flux ImagePolicy setter) to match GHCR semver after app release 0.2.1.
- **Terraform / Vault** — Removed `vault_kv_secret_v2.openclaw_openrouter` and `openrouter_api_key` variable; OpenRouter stays in Vault only (CLI/UI/`scripts/setup-openclaw.sh`), not in Terraform state. README documents one-time `terraform state rm` with `TF_TOKEN_app_terraform_io` (Actions only plan/apply). See `terraform/README.md`.
- **Canopy** — API/frontend **`latest`** with **`pullPolicy: Always`** (solo use); removed Flux image automation manifests (`image-automation.yaml` dropped from [`kustomization.yaml`](clusters/eldertree/canopy/kustomization.yaml)). After deploy, delete leftover `ImageRepository` / `ImagePolicy` / `ImageUpdateAutomation` in namespace `canopy` if they remain. [`docs/SERVICES_REFERENCE.md`](docs/SERVICES_REFERENCE.md) image row; [`docs/FLUX_DEPLOY_KEY_SETUP.md`](docs/FLUX_DEPLOY_KEY_SETUP.md) / [`docs/VAULT_SECRETS_BOOTSTRAP.md`](docs/VAULT_SECRETS_BOOTSTRAP.md) use swimto for ImageUpdateAutomation examples. `SERVICES_REFERENCE`: public URL `https://canopy.eldertree.xyz` (Cloudflare Tunnel + Basic Auth); tunnel path order `/v1/*` before `/` in `terraform/cloudflare.tf`. **`CORS_ALLOW_ORIGINS`** on `canopy-api`; frontend no longer sets bogus **`NEXT_PUBLIC_API_URL=http://canopy-api:8000`** (browser must use same-origin `/v1` or a public URL baked at `next build`). **`SERVICES_REFERENCE`**: run **`kubectl … migrate.sh`** after API upgrades (Alembic).
- **OpenClaw RBAC** — Broader workload/service/config/ingress/Flux/cert-manager write access; read-only on PV/CSI/CRDs/webhooks/cluster view; no namespace delete, no node delete (nodes patch allowed for cordon/taints). See `clusters/eldertree/openclaw/rbac.yaml`.
- **Prometheus (Lens)** — `node` label on `kubernetes-nodes` / `kubernetes-nodes-cadvisor` scrapes so Lens node metrics resolve.

### Added

- **Hardware Watchdog Monitoring with Boot Loop Protection** — BCM2835 watchdog enables automatic node recovery from system freezes with safety limits (#153). Ansible playbook `setup-hardware-watchdog.yml` installs watchdog daemon (15s timeout, k3s pidfile monitoring, gigabit network ping checks 10.0.0.1-3), plus boot guard system that tracks consecutive reboots and disables watchdog after 5 attempts to prevent infinite loops. Boot counter automatically resets after 10 minutes of stable uptime. Systemd units: `watchdog-boot-guard.service` (pre-boot check), `watchdog-boot-guard-reset.timer` (counter reset). Documentation: `docs/HARDWARE_WATCHDOG.md` with deployment, boot loop recovery, verification, and troubleshooting. Tested and deployed to node-2; deployment to all nodes automated via Ansible. Addresses Node-1 freeze (Feb 13-17) where kubelet stopped responding but system remained pingable.
- **Operations** — [`scripts/operations/sync-kubeconfig-eldertree-remote.sh`](scripts/operations/sync-kubeconfig-eldertree-remote.sh) builds `~/.kube/config-eldertree-remote` from `~/.kube/config-eldertree` (Tailscale API on node-1; `insecure-skip-tls-verify` per [`docs/TAILSCALE.md`](docs/TAILSCALE.md)). Invoked from [`scripts/setup-kubeconfig-eldertree.sh`](scripts/setup-kubeconfig-eldertree.sh), [`scripts/update-kubeconfig-ha.sh`](scripts/update-kubeconfig-ha.sh), and [`scripts/update-kubeconfig-vip.sh`](scripts/update-kubeconfig-vip.sh) when present.
- **Operations / Lens** — [`scripts/operations/merge-eldertree-kubeconfigs-for-lens.sh`](scripts/operations/merge-eldertree-kubeconfigs-for-lens.sh) writes `~/.kube/config-eldertree-lens` (contexts `eldertree` + `eldertree-remote`, default `eldertree-remote`) so Lens can switch off the VIP when `192.168.2.100:6443` is unreachable. Re-merge preserves an existing `100.x` API IP from `config-eldertree-remote` unless `ELDERTREE_TS_API_IP` is set. Documented in [`docs/LENS_CONNECTION_GUIDE.md`](docs/LENS_CONNECTION_GUIDE.md).
- **Operations** — [`scripts/operations/diagnose-eldertree-tailscale-k8s-api.sh`](scripts/operations/diagnose-eldertree-tailscale-k8s-api.sh) probes node-1/2/3 Tailscale IPs on `:6443`; [`docs/TAILSCALE.md`](docs/TAILSCALE.md) documents failover when node-1’s Tailscale path shows `rx 0` / relay-only (regenerate with `ELDERTREE_TS_API_IP=100.116.185.57` or node-3).
- **Docs** — [`docs/OBSERVABILITY_BLACKBOX_AND_SYNTHETIC.md`](docs/OBSERVABILITY_BLACKBOX_AND_SYNTHETIC.md) (what Blackbox solves, relation to in-cluster metrics and OTel); [`helm/monitoring-stack/DASHBOARDS.md`](helm/monitoring-stack/DASHBOARDS.md) section on Blackbox + link. [`README.md`](README.md) links to both.
- **Grafana** — Sidecar `searchNamespace` was `ALL`, so any `grafana_dashboard: "1"` ConfigMap in *any* namespace (Kong, Veeam, Cosmos charts, etc.) was auto-imported; scoped to `observability` only so third-party dashboards are not loaded into this instance.
- **Observability (Eldertree)** — Traefik metrics on the k3s Traefik `Service` and scraped from **`helm/monitoring-stack/values.yaml`** `prometheus.scrapeConfigs.traefik` (dropped legacy `traefik-scrape-config` from Flux kustomization; blackbox probers are static jobs in the same `scrapeConfigs`); SwimTO `swimto-api` Service annotated for Prometheus app `/metrics`; blackbox exporter + HTTPS probes + `BlackboxProbeFailing` alert; Loki 2.9 + Promtail + Grafana Loki datasource; **Eldertree Ops Home** dashboard (`eldertree-ops-home.json`). See `helm/monitoring-stack/DASHBOARDS.md` (Traefik v3 label source of truth).
- **SwimTO API** — `swimto_db_users_total` gauge (refreshed every 5 minutes) for product depth on `/metrics` (build and push a new image for cluster).
- OpenClaw runbook (eldertree-docs): gateway token, config schema, doctor, `controlUi.allowedOrigins`, “All models failed”.
- LLM keys from env: `models.providers` + `apiKey: "${GOOGLE_API_KEY}"` etc.; Groq fallback `llama-3.3-70b-versatile`; default `OLLAMA_API_KEY` when secret missing.

### Fixed

- **Grafana — Cluster Resource Usage by Namespace** — Network I/O pie and related queries excluded `namespace=\"\"` (cAdvisor node/aggregate network series). That bucket had no `{{namespace}}` label, so the donut legend showed **Value** (Grafana’s default field name) instead of a name. `namespace!=\"\"` matches the time-series network panels. Chart `0.2.6`.
- **Grafana — Eldertree Ops Home** — Provisioned dashboard JSON updated (empty annotations, stat `reduceOptions`, no broken `${datasource}` panels) so the sidecar can import it; chart `0.2.4`. The “Invalid dashboard UID in annotation request” toast is a follow-on when the dashboard ID does not exist.
- **Grafana** — [DASHBOARDS.md](helm/monitoring-stack/DASHBOARDS.md) rewritten: verified inventory (12 custom JSON + 17 gnet), categories, UIDs, overlaps, and removed references to non-existent JSON files. **Visage Training** `visage-training.json` JSON fix (invalid `expr` quoting) ships in chart `0.2.5`.
- **OpenClaw `openclaw.json` EBUSY / stale model on PVC** — `openclaw.json` was mounted as a ConfigMap **subPath** file; the gateway cannot atomically rename onto it when persisting plugin auto-enable changes (`EBUSY`). Mount the ConfigMap at `/etc/openclaw-config` and **copy** `config.json` onto the PVC at container start ([`helmrelease.yaml`](clusters/eldertree/openclaw/helmrelease.yaml)) so the live config is writable and matches Git on each rollout (avoids an old `openclaw.json` on PVC shadowing the ConfigMap). Copy runs only when the ConfigMap **SHA-256** changes or the PVC file is missing, so routine restarts keep OpenClaw’s on-disk metadata and avoid repeated `missing-meta-*` log noise.
- **Terraform CI** (`.github/workflows/terraform.yml`) — [Node 20 on Actions runners is deprecated](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/); set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` and use `hashicorp/setup-terraform@v4` (Node 24). Terraform binary **1.10.0** (1.6.x fails `terraform init` with `openpgp: key expired`); **`terraform_wrapper: false`** so `plan -detailed-exitcode` is not collapsed to **0**. **Job summary** (`$GITHUB_STEP_SUMMARY`): state size, `terraform plan` exit and plan line, root module **output names** only. **Annotations:** `::notice` / `::error` for state, plan, apply; `id: apply`. PRs plan-only; apply on **main** push or `workflow_dispatch` with `apply=true`.
- **OpenClaw** — OpenRouter token/context limits and compaction (`configmap.yaml`: catalog `contextWindow`/`maxTokens`, `agents.defaults.contextTokens`, Groq compaction safeguard); gateway `token` auth (no Traefik `X-Forwarded-User` loopback); lower `maxTokens` for small credits; heap/pod memory for OOM; trusted proxies for loopback; exec-approvals copied to writable path on start.
- **Cloudflared** — Required pod anti-affinity so two replicas never share one node (WiFi outage had taken down both).

---

## [1.3.8] - 2026-01-27

- **Added** — `upgrade-k3s.yml` (rolling k3s-only); VPA (recommend-only) for swimto; Redis native sidecar POC.
- **Changed** — Cluster on k3s v1.35.0+k3s1 (Traefik 3.5, CoreDNS 1.13, containerd 2.1.5, longer cert renewal).
- **Fixed** — Traefik `loadBalancerIP: 192.168.2.200` so kube-vip does not collide with Pi-hole `.201`.
- **Docs** — `NETWORK.md` (Bell hub DNS); `ansible/README.md` (k3s upgrade).

## [1.3.7] - 2026-01-25

- **Fixed** — k3s `bind-address: 0.0.0.0` so API accepts traffic via kube-vip WiFi VIP.
- **Changed** — `configure-k3s-gigabit.yml` writes `/etc/rancher/k3s/config.yaml`; `k3s_bind_address` in `group_vars/all.yml`.
- **Docs** — `docs/NETWORK_ARCHITECTURE.md` (bind address).

## [1.3.6] - 2026-01-20

- **Added** — `security-update.yml` (rolling OS + optional k3s, drain/reboot, health checks).
- **Docs** — Usage examples in playbook / README.

## [1.3.5] - 2026-01-20

- **Changed** — MetalLB replaced by kube-vip for LB services (Traefik `.200`, Pi-hole `.201`, range `/28` on `wlan0`).
- **Removed** — MetalLB manifests and `metallb-system`.
- **Fixed** — Single cert-manager (disabled subchart duplicate).
- **Docs** — `NETWORK.md`, `SERVICES_REFERENCE.md` (kube-vip access).

## [1.3.4] - 2026-01-18

- **Fixed** — MetalLB L2 on `wlan0` so VIP `.200` answers.
- **Changed** — MetalLB speaker security context tweaks.
- **Added** — WireGuard HA plan update (issue #49).
- **Docs** — `NETWORK.md` topology and hosts examples.

## [1.3.3] - 2026-01-18

- **Added** — Terraform Vault provider + `vault.tf` (policies, K8s auth, ESO tokens, projects); tfvars/README updates.
- **Changed** — CI skips Vault; state in Terraform Cloud (`eldertree` / `pi-fleet-terraform`).
- **Deprecated** — `setup-vault-policies.sh` → use Terraform.

## [1.3.2] - 2026-01-07

- Flux image automation for Pitanga; `pitanga.cloud` in external-dns; Cloudflare proxy on public ingress.

## [1.3.1] - 2025-12-28

- Grafana: Pi fleet overview + hardware health dashboards; `DASHBOARDS.md`.

## [1.3.0] - 2025-01-XX

- Vault production (Raft + PVC), unseal/backup scripts, `VAULT_MIGRATION.md`; ESO; WireGuard docs; Canopy manifests; Grafana + kube-state-metrics; External-DNS + Pi-hole BIND TSIG from Vault.
- Pi tuning: lower Flux/KEDA/Journey limits; Ansible matches Raspberry Pi Imager workflow; removed hardcoded secrets (Ansible Vault / env); branch protection + workflow docs; DNS script cleanup.

## [0.2.0] - 2025-11-12

- Helm v4 compatibility for custom charts.

## [0.1.0] - 2025-11-07

- Initial Flux + Traefik + cert-manager + monitoring; `eldertree` naming; `clusters/eldertree/` layout; Terraform kubeconfig rename; Longhorn deferred.
