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
| Listener | 100m / 200m | 64Mi / 128Mi |
| Runner | 1000m / 3000m | 2Gi / 4Gi |

## Node Placement

**Controller:**
- Uses `nodeSelector: eldertree.xyz/node-tier: stable`
- Runs on node-2 or node-3 only

**Runners:**
- No placement constraints
- Kubernetes scheduler decides (natural spread across nodes)
- Ephemeral workload, no affinity needed

## Adding More Repos

1. Create ExternalSecret in `clusters/eldertree/arc-runners/`:
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: <repo>-runner-github-secret
     namespace: arc-runners
   spec:
     secretStoreRef:
       kind: ClusterSecretStore
       name: vault
     target:
       name: <repo>-runner-github-secret
     data:
       - secretKey: github_token
         remoteRef:
           key: secret/eldertree/arc-runners/<repo>
           property: github_token
   ```

2. Create HelmRelease in `clusters/eldertree/arc-runners/<repo>-runners-helmrelease.yaml`:
   ```yaml
   apiVersion: helm.toolkit.fluxcd.io/v2
   kind: HelmRelease
   metadata:
     name: <repo>-runners
     namespace: arc-runners
   spec:
     chart:
       spec:
         chart: gha-runner-scale-set
         version: "0.14.2"
     values:
       githubConfigUrl: "https://github.com/raolivei/<repo>"
       githubConfigSecret: <repo>-runner-github-secret
       minRunners: 0
       maxRunners: 6   # match parallel jobs in the repo workflow
   ```

   **Resource sizing (Pi 5 cluster):** Each runner pod is runner + DinD sidecar. Default chart requests (1 CPU / 2Gi per runner) saturate a 3×4-core cluster before all runners schedule. Ollie uses ~750m CPU / 1.5Gi requests per pod (500m+250m runner/dind) with limits 2.5 CPU / 3.5Gi so up to 6 parallel `build-publish` jobs can schedule on node-2 and node-3 (`node-tier: stable`). Builds may be slower under contention; raise limits only if nodes have headroom.

3. Update `clusters/eldertree/arc-runners/kustomization.yaml`
4. Commit and push — Flux deploys automatically

## References

- [ARC GitHub](https://github.com/actions/actions-runner-controller)
- [ARC Helm Charts](https://github.com/actions/actions-runner-controller/tree/master/charts)
- Issue: [ollie#71](https://github.com/raolivei/ollie/issues/71)

---

**Deployed:** 2026-06-04  
**Maintained By:** [@raolivei](https://github.com/raolivei)
