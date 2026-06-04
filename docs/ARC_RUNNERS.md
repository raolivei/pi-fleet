# Actions Runner Controller (ARC) - GitHub Self-Hosted Runners

Auto-scaling GitHub Actions runners on Eldertree K3s using Actions Runner Controller.

**Issue:** [raolivei/ollie#71](https://github.com/raolivei/ollie/issues/71)

## Architecture

```
┌─────────────────────────────────────────┐
│ arc-system namespace                    │
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

Controller and runner scale set installed via Helm:

```bash
# Controller
helm install arc-controller \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --namespace arc-system \
  --version 0.14.2

# Runner scale set (per repo/org)
helm install ollie-runners \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace arc-runners \
  --version 0.14.2 \
  --set githubConfigUrl="https://github.com/raolivei/ollie" \
  --set githubConfigSecret="ollie-runner-github-secret" \
  --set minRunners=0 \
  --set maxRunners=3
```

## Secrets

**GitHub PAT** stored in Vault:
```
Path: secret/eldertree/arc-runners/ollie
Key: github_token
```

Create Kubernetes secret:
```bash
kubectl create secret generic ollie-runner-github-secret \
  --namespace arc-runners \
  --from-literal=github_token="ghp_..."
```

## Monitoring

```bash
# Controller
kubectl get pods -n arc-system

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
kubectl logs -n arc-system -l app.kubernetes.io/name=gha-rs-controller
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

Runners prefer node-2, tolerate node-1:
- node-2: Moderate load, stable
- node-1: Light load, has stability taint

## Adding More Repos

```bash
helm install <repo-name>-runners \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace arc-runners \
  --version 0.14.2 \
  --set githubConfigUrl="https://github.com/raolivei/<repo>" \
  --set githubConfigSecret="<repo>-runner-github-secret"
```

## References

- [ARC GitHub](https://github.com/actions/actions-runner-controller)
- [ARC Helm Charts](https://github.com/actions/actions-runner-controller/tree/master/charts)
- Issue: [ollie#71](https://github.com/raolivei/ollie/issues/71)

---

**Deployed:** 2026-06-04  
**Maintained By:** [@raolivei](https://github.com/raolivei)
