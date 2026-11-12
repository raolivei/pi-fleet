# Actions Runner Controller (ARC) - GitHub Self-Hosted Runners

Auto-scaling GitHub Actions runners on Eldertree K3s using Actions Runner Controller.

**Issue:** [raolivei/ollie#71](https://github.com/raolivei/ollie/issues/71)

## Architecture

```
┌─────────────────────────────────────────┐
│ arc-controller namespace                │
├─────────────────────────────────────────┤
│ • gha-runner-scale-set-controller       │ ← Watches GitHub job queue
│   - Helm: v0.14.2                       │
│   - OCI: ghcr.io/actions/...            │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ arc-runners namespace                   │
├─────────────────────────────────────────┤
│ • Listener pod (ollie-eldertree)        │ ← Watches for queued jobs
│ • Runner pods (ephemeral)               │ ← Auto-provision per job
│   - Scale: 0→3 on demand               │
│   - DinD for Docker builds              │
│   - Auto-cleanup after completion       │
└─────────────────────────────────────────┘
```

## Key Features

**Auto-Scaling:**
- Min: 0 runners (idle = zero cost)
- Max: 3 runners (parallel builds)
- Listener watches GitHub queue
- Runners provision in ~30s

**Ephemeral:**
- Fresh pod per job
- No state persistence
- Auto-cleanup after job
- No mount conflicts

## Installation

Deployed via **FluxCD GitOps** (not manual Helm):

**Manifests:**
- Controller: `clusters/eldertree/arc-controller/`
- Runners: `clusters/eldertree/arc-runners/`

**Naming:** See [FLUX_HELM_NAMING.md](FLUX_HELM_NAMING.md). Summary: set `releaseName: arc-controller` and `releaseName: ollie-runners` so chart ServiceAccount is `arc-controller-gha-rs-controller` (matches `controllerServiceAccount.name` in runners and `arc-controller-secrets` ClusterRole). HelmRepository for OCI charts is `arc-charts` in `flux-system`.

**Deployment:**
```bash
# Commit manifests to git, Flux reconciles automatically
git push origin main
flux reconcile kustomization eldertree --with-source
```

**Manual Helm (reference only, DO NOT USE):**
```bash
# Controller
helm install arc-controller \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --namespace arc-controller \
  --version 0.14.2

# Runner scale set
helm install ollie-runners \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace arc-runners \
  --version 0.14.2 \
  --set githubConfigUrl="https://github.com/raolivei/ollie" \
  --set githubConfigSecret="ollie-runner-github-secret"
```

## Secrets

**GitHub PAT** stored in Vault and synced via ExternalSecret:

```
Vault Path: secret/eldertree/arc-runners/ollie
Key: github_token
ExternalSecret: clusters/eldertree/arc-runners/ollie-external-secret.yaml
```

Vault manages the secret, ExternalSecrets operator syncs to Kubernetes automatically.

## Monitoring

```bash
# Controller
kubectl get pods -n arc-controller

# Listener
kubectl get pods -n arc-runners

# Active runners (during builds)
kubectl get pods -n arc-runners -l actions.github.com/scale-set-name=ollie-eldertree

# GitHub API
gh api repos/raolivei/ollie/actions/runners
```

## Scaling Behavior

**Idle state:**
- Controller: running
- Listener: running
- Runners: 0 pods

**Build triggered:**
- Listener detects queued job
- Provisions runner pod (~30s)
- Runner executes job
- Pod auto-deletes after completion

## Troubleshooting

**No runner pods created:**
```bash
kubectl logs -n arc-runners -l app.kubernetes.io/component=runner-scale-set-listener
```

**Controller issues:**
```bash
kubectl logs -n arc-controller -l app.kubernetes.io/name=gha-rs-controller
```

**Runner pod stuck:**
```bash
kubectl describe pod -n arc-runners <pod-name>
kubectl logs -n arc-runners <pod-name>
```

## Resource Usage

| Component | CPU (req/limit) | Memory (req/limit) |
|-----------|-----------------|-------------------|
| Controller | 100m / 500m | 64Mi / 256Mi |
| Listener (namespace defaults) | 50m / 200m | 64Mi / 128Mi |
| Runner (explicit Helm values) | 100m / 1500m | 512Mi / 2Gi |
| DinD (namespace defaults) | 50m / 2000m | 256Mi / 3Gi |

The live HelmRelease values are authoritative for explicit controller and runner
resources. On Kubernetes 1.29+, ARC's built-in DinD mode injects Docker as a
restartable init container; `template.spec.containers[name=dind].resources`
does not customize that generated container. Namespace `LimitRange` defaults
cover generated containers while preserving explicit resources:

| Namespace / generated container | CPU request / limit | Memory request / limit |
| --- | --- | --- |
| `arc-runners` / DinD and external-files init | 50m / 2000m | 256Mi / 3Gi |
| `arc-controller` / listener | 50m / 200m | 64Mi / 128Mi |

Defaults apply when a pod is created; running jobs are not restarted to apply
them. Explicit runner limits remain separate from the Docker daemon's limit.
The DinD ceiling preserves headroom documented for Elder's npm/TypeScript
builds. Limits are ceilings, not reserved capacity. Per-repository `maxRunners`
values do not enforce a cluster-wide concurrency budget.

## Node Placement

**Controller:**
- Uses `nodeSelector: eldertree.xyz/node-tier: stable`
- Runs on node-2 or node-3 only

**Listeners:**
- Prefer stable nodes and spread softly across hostnames, using the shared
  `listener-placement.yaml` Kustomize patch on the active HelmReleases.
- Both rules are preferences: node-1 remains an overflow/recovery option.
- Namespace resource defaults reserve capacity for every newly created listener.

**Runners:**
- Prefer stable nodes (node-2, node-3) via cluster scheduling; **no hard nodeSelector** — when stable nodes are saturated, runners may schedule on node-1 (unstable tier, `PreferNoSchedule` taint).
- Pod anti-affinity spreads runners across hosts when possible.
- Requests: **100m CPU + 512Mi** per runner container, plus **50m CPU + 256Mi**
  for the DinD sidecar through namespace defaults. The external-files init
  container uses the same defaults temporarily; it is not another long-running
  Docker daemon.

## Adding More Repos

**Default (2026-06):** `raolivei` is a **GitHub User** account, not an Organization. Org-level ARC (`githubConfigUrl: https://github.com/raolivei`) is not available — use **one scale set per repo**.

Each repo gets a HelmRelease with `githubConfigUrl: https://github.com/raolivei/<repo>`. Workflows use `runs-on: self-hosted`; jobs route only to that repo's listener.

**PAT requirement:** Vault path `secret/eldertree/arc-runners/ollie` — classic PAT with `repo` + `workflow` scopes (shared across all user-owned repos). Sync via [`scripts/operations/setup-arc-repo-github-pat.sh`](../scripts/operations/setup-arc-repo-github-pat.sh).

**Org scope (future):** Requires a real GitHub Organization entity (free tier works). Transfer repos, then a single org-scoped scale set can serve all repos.

**Per-repo scale set:**

1. Reuse `ollie-runner-github-secret` (shared PAT) or add a repo-specific ExternalSecret.

2. Create HelmRelease in `clusters/eldertree/arc-runners/<slug>-runners-helmrelease.yaml` — copy an existing release and set unique `metadata.name`, `releaseName`, `runnerScaleSetName`, `githubConfigUrl`, and `maxRunners` (default `1`; `2` for repos with parallel docker-build jobs).

   **Resource sizing (Pi 5 cluster):** Runner + DinD reserve **150m CPU + 768Mi**
   through explicit runner resources and namespace defaults. No hard node-tier
   selector — node-1 absorbs overflow when node-2/3 are full. The
   operational target of **4–6 concurrent DinD runners** is not a global limit
   enforced by ARC; avoid firing all scale sets at once (stress script).

**DinD + npm/pnpm builds:** If Docker build fails with `getaddrinfo EAI_AGAIN registry.npmjs.org`, configure **both** (1) pod `dnsConfig` with CoreDNS (`10.43.0.10`) plus `8.8.8.8` fallback on `template.spec`, and (2) mount a `daemon.json` on the **dind** sidecar with the same DNS servers — buildx containers use the Docker daemon resolver, not the pod's `resolv.conf`. See `bolao-dind-daemon-configmap.yaml` + `bolao-runners-helmrelease.yaml`.

3. Update `clusters/eldertree/arc-runners/kustomization.yaml`
4. Commit and push — Flux deploys automatically

**Load testing:** `scripts/stress-arc-runners.sh` (dispatch workflows) + `scripts/monitor-arc-runners.sh` (live cluster view). Set `ARC_REPOS` to repos with deployed scale sets.

## References

- [ARC GitHub](https://github.com/actions/actions-runner-controller)
- [ARC Helm Charts](https://github.com/actions/actions-runner-controller/tree/master/charts)
- Issue: [ollie#71](https://github.com/raolivei/ollie/issues/71)

---

**Deployed:** 2026-06-04  
**Maintained By:** [@raolivei](https://github.com/raolivei)
