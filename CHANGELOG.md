# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/). Dates are ISO 8601.

## [Unreleased]

### Changed

- **personal-website** — HelmRelease image tag `v0.2.1` (Flux ImagePolicy setter) to match GHCR semver after app release 0.2.1.
- **Terraform / Vault** — Removed `vault_kv_secret_v2.openclaw_openrouter` and `openrouter_api_key` variable; OpenRouter stays in Vault only (CLI/UI/`scripts/setup-openclaw.sh`), not in Terraform state. README documents one-time `terraform state rm` with `TF_TOKEN_app_terraform_io` (Actions only plan/apply). See `terraform/README.md`.
- **Canopy** — API/frontend **`latest`** with **`pullPolicy: Always`** (solo use); removed Flux image automation manifests (`image-automation.yaml` dropped from [`kustomization.yaml`](clusters/eldertree/canopy/kustomization.yaml)). After deploy, delete leftover `ImageRepository` / `ImagePolicy` / `ImageUpdateAutomation` in namespace `canopy` if they remain. [`SERVICES_REFERENCE.md`](SERVICES_REFERENCE.md) image row; [`docs/FLUX_DEPLOY_KEY_SETUP.md`](docs/FLUX_DEPLOY_KEY_SETUP.md) / [`docs/VAULT_SECRETS_BOOTSTRAP.md`](docs/VAULT_SECRETS_BOOTSTRAP.md) use swimto for ImageUpdateAutomation examples. `SERVICES_REFERENCE`: public URL `https://canopy.eldertree.xyz` (Cloudflare Tunnel + Basic Auth); tunnel path order `/v1/*` before `/` in `terraform/cloudflare.tf`. **`CORS_ALLOW_ORIGINS`** on `canopy-api`; frontend no longer sets bogus **`NEXT_PUBLIC_API_URL=http://canopy-api:8000`** (browser must use same-origin `/v1` or a public URL baked at `next build`). **`SERVICES_REFERENCE`**: run **`kubectl … migrate.sh`** after API upgrades (Alembic).
- **OpenClaw RBAC** — Broader workload/service/config/ingress/Flux/cert-manager write access; read-only on PV/CSI/CRDs/webhooks/cluster view; no namespace delete, no node delete (nodes patch allowed for cordon/taints). See `clusters/eldertree/openclaw/rbac.yaml`.
- **Prometheus (Lens)** — `node` label on `kubernetes-nodes` / `kubernetes-nodes-cadvisor` scrapes so Lens node metrics resolve.

### Added

- OpenClaw runbook (eldertree-docs): gateway token, config schema, doctor, `controlUi.allowedOrigins`, “All models failed”.
- LLM keys from env: `models.providers` + `apiKey: "${GOOGLE_API_KEY}"` etc.; Groq fallback `llama-3.3-70b-versatile`; default `OLLAMA_API_KEY` when secret missing.

### Fixed

- **OpenClaw `openclaw.json` EBUSY / stale model on PVC** — `openclaw.json` was mounted as a ConfigMap **subPath** file; the gateway cannot atomically rename onto it when persisting plugin auto-enable changes (`EBUSY`). Mount the ConfigMap at `/etc/openclaw-config` and **copy** `config.json` onto the PVC at container start ([`helmrelease.yaml`](clusters/eldertree/openclaw/helmrelease.yaml)) so the live config is writable and matches Git on each rollout (avoids an old `openclaw.json` on PVC shadowing the ConfigMap).
- **Terraform CI** — Bump Actions `setup-terraform` to **1.10.0**; **1.6.0** fails `terraform init` with `openpgp: key expired` when installing HashiCorp-signed providers. Lock file refreshed for extra platform hashes. **`terraform_wrapper: false`** so `plan -detailed-exitcode` is not collapsed to **0** (was printing “no changes” when the plan had updates). PRs remain plan-only; apply still runs on **main** push or **workflow_dispatch** with apply.
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
