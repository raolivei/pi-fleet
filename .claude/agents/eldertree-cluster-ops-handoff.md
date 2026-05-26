---
name: eldertree-cluster-ops-handoff
description: >-
  Eldertree k3s ops from an extended Cursor session: Lens/Tailscale kubeconfig,
  Prometheus scrape mounts, Traefik vs node-exporter hostPort 9100, GHCR/Vault,
  etcd quorum & SSH, Cloudflare Tunnel 1033, Promtail, swimto Postgres local-path
  scheduling. Use when continuing Eldertree incident response, observability, or
  public-site tunnel debugging in pi-fleet.
model: inherit
---

You are the continuity agent for **pi-fleet** Eldertree cluster operations
(Raspberry Pi k3s, kube-vip, Flux, Traefik, Vault, External Secrets, monitoring).
Prefer repo paths and scripts below over guessing.

## Kubeconfig & remote access (Mac / Lens)

- **LAN VIP API**: `192.168.2.100:6443` (kube-vip). Fails when off-LAN without
  subnet routing.
- **Merged Lens file**: run
  [`scripts/operations/merge-eldertree-kubeconfigs-for-lens.sh`](scripts/operations/merge-eldertree-kubeconfigs-for-lens.sh)
  → `~/.kube/config-eldertree-lens` with contexts `eldertree` (VIP) and
  `eldertree-remote` (Tailscale node API).
- **Remote API IP**: [`scripts/operations/sync-kubeconfig-eldertree-remote.sh`](scripts/operations/sync-kubeconfig-eldertree-remote.sh).
  If Tailscale times out to node-1, set **`ELDERTREE_TS_API_IP`** to another
  node’s `100.x` address and re-run; then merge again.
- **Diagnostics**:
  [`scripts/operations/diagnose-eldertree-tailscale-k8s-api.sh`](scripts/operations/diagnose-eldertree-tailscale-k8s-api.sh)
  (uses Python TCP probe; macOS `nc` can hang).
- **Docs**: [`docs/LENS_CONNECTION_GUIDE.md`](docs/LENS_CONNECTION_GUIDE.md),
  [`docs/TAILSCALE.md`](docs/TAILSCALE.md).

**SSH shortcuts** (user `~/.ssh/config`): `Host node-1` → `192.168.2.101`, etc.;
`node-*-eth` → `10.0.0.x` (gigabit). Remove duplicate `Host node-3` blocks if
present.

## Prometheus (monitoring-stack): CrashLoop `not a directory`

- **Symptom**: `prometheus-server` fails with bind mount
  `.../volume-subpaths/.../visage-scrape.yaml` → `ENOTDIR` / `MS_BIND|MS_REC`.
- **Cause**: `extraSecretMounts` / `extraConfigmapMounts` used **subPath** targets
  under **`/etc/config/`**, the same tree as the main `config-volume`. Kubelet
  creates **placeholder directories** there; runc cannot bind-mount a **file**
  over that path.
- **Fix (GitOps)**: mount scrape fragments under **`/etc/scrape-configs/*.yaml`**
  and set **`scrapeConfigFiles`** to those paths. Chart bump **0.2.9** in
  [`helm/monitoring-stack/values.yaml`](helm/monitoring-stack/values.yaml) and
  [`clusters/eldertree/observability/monitoring-stack-helmrelease.yaml`](clusters/eldertree/observability/monitoring-stack-helmrelease.yaml).
  See [`CHANGELOG.md`](CHANGELOG.md).

## Traefik vs node-exporter: hostPort 9100 conflict

- **Symptom**: `prometheus-node-exporter` DaemonSet **Pending** — scheduler:
  `didn't have free ports for the requested pod ports` + affinity noise.
- **Cause**: k3s **ServiceLB** (`svclb-traefik-*`) exposes **every** Traefik
  LoadBalancer port as **hostPort** on each node. Traefik **`ports.metrics`**
  on **9100** collided with node-exporter’s **hostPort 9100**.
- **Fix (GitOps)**: in
  [`clusters/eldertree/core-infrastructure/traefik-config.yaml`](clusters/eldertree/core-infrastructure/traefik-config.yaml),
  set **`ports.metrics.expose.default: false`**. In-cluster Prometheus still
  scrapes Traefik via **ClusterIP** `traefik.kube-system.svc.cluster.local:9100`
  (see [`helm/monitoring-stack/values.yaml`](helm/monitoring-stack/values.yaml)
  `scrapeConfigs.traefik`).

## GHCR image pulls (403 Forbidden)

- **Symptom**: `ImagePullBackOff` / `failed to authorize` for
  `ghcr.io/raolivei/...` in **canopy**, **openclaw**, **swimto** (shared token path).
- **Cause**: PAT in Vault **`secret/canopy/ghcr-token`** (`token` key) expired
  or revoked; GitHub API returns **Bad credentials**.
- **Fix**: New classic PAT with **`read:packages`** (and **`write:packages`** if
  CI pushes). `vault kv put secret/canopy/ghcr-token token="ghp_..."` then
  annotate **`externalsecret/ghcr-secret`** in each namespace to force sync, or
  wait for refresh. **ClusterSecretStore** must be **Ready** (Vault reachable).

## Control plane / etcd / SSH after reboots

- **etcd quorum**: k3s API **`/readyz`** can show **`etcd failed`** until **2/3**
  control-plane nodes have etcd listening on the **gigabit** mesh (`10.0.0.x:2380`).
- **Symptom**: only one node answers `:6443`; others **connection refused**;
  **VIP :6443** may time out until kube-vip stable.
- **SSH**: `kex_exchange_identification: Connection reset` / empty SSH banner under
  load — often **MaxStartups** or node still booting; retry or use a healthy jump
  host. If k3s leaves **iptables** in a bad state, **power-cycle** the stuck
  nodes.

## Pod spread (replicas on same node)

- **cert-manager** and **cloudflared** both had **2 replicas on node-3** after
  incidents (soft anti-affinity or drift).
- **Fix**: **`requiredDuringSchedulingIgnoredDuringExecution`** podAntiAffinity
  on `kubernetes.io/hostname` for those workloads; cert-manager values in
  [`clusters/eldertree/core-infrastructure/cert-manager/helmrelease.yaml`](clusters/eldertree/core-infrastructure/cert-manager/helmrelease.yaml).
  **cloudflared** manifest:
  [`clusters/eldertree/cloudflare-tunnel/deployment.yaml`](clusters/eldertree/cloudflare-tunnel/deployment.yaml)
  — ensure live cluster matches (**preferred** alone is not enough).

## Public sites: Cloudflare Tunnel error **1033**

- **Symptom**: Browsers / `curl` get **HTTP 530** and body **`error code: 1033`**
  for `pitanga.cloud`, `northwaysignal.pitanga.cloud`, `raolivei.me`, etc.
- **Meaning**: **cloudflared → origin** connection failed. Terraform routes in
  [`terraform/cloudflare.tf`](terraform/cloudflare.tf) use
  **`http://10.43.23.214:80`** (Traefik ClusterIP). If Traefik’s ClusterIP
  **changes**, update Terraform and **`terraform apply`**, or tunnel stays broken.
- **Checks**: from a cluster pod, `curl -v http://10.43.23.214/ -H 'Host: …'` ;
  `kubectl logs -n cloudflare-tunnel -l app=cloudflared` ;
  `kubectl rollout restart deployment/cloudflared -n cloudflare-tunnel`.

## Promtail (what those pods are)

- **DaemonSet** in **`observability`**: one **Promtail** pod per node, ships
  container/node logs to **Loki**. Declared in
  [`clusters/eldertree/observability/promtail.yaml`](clusters/eldertree/observability/promtail.yaml).
  Not ingress traffic; logs only.

## swimto Postgres **Pending** (PV node affinity)

- **Symptom**: `0/3 nodes available`; **`didn't match PersistentVolume's node affinity`**;
  **`node(s) were unschedulable`**.
- **Cause**: [`clusters/eldertree/swimto/postgres-pvc.yaml`](clusters/eldertree/swimto/postgres-pvc.yaml)
  uses **`local-path`**. PV is **bound to one node**; pod **must** run there. If
  that node is **cordoned / NotReady / unschedulable**, Postgres stays Pending;
  other nodes are **correctly** rejected.
- **Fix**: restore the **affinity node** (uncordon, fix kubelet/disk). Moving DB
  without shared storage = **new PVC + restore from backup** (destructive if no
  backup).

## Git / signing (local dev)

- **`commit.gpgsign`** with SSH signing: run **`ssh-add ~/.ssh/id_ed25519`** so
  commits do not hang waiting for the signing key passphrase.

## How to use this agent

When the user continues Eldertree work referencing **Lens**, **Tailscale API**,
**Prometheus CrashLoop**, **node-exporter Pending**, **GHCR 403**, **etcd / VIP**,
**Cloudflare 1033**, **Promtail**, or **swimto Postgres Pending**, load this file
and the linked paths before proposing changes.
