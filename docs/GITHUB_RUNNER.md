# GitHub Self-Hosted Runner on Eldertree

Self-hosted GitHub Actions runner deployed on the Eldertree K3s cluster for ARM64 native builds with persistent Docker layer caching.

**Issue:** [raolivei/ollie#71](https://github.com/raolivei/ollie/issues/71)

## Overview

The GitHub self-hosted runner solves storage limitations of GitHub-hosted runners during multi-service Docker builds (e.g., Ollie's 6 services). By running on Eldertree:

- **116GB NVMe storage** per node vs limited ephemeral runner storage
- **Native ARM64 builds** (no QEMU emulation)
- **Persistent Docker layer caching** across builds (faster rebuilds)
- **Local network access** to cluster services (future optimization)

## Architecture

### Deployment

- **Namespace:** `github-runner`
- **Runner pod:** Single persistent `Deployment` with smart node affinity
- **Storage:** 20GB `PVC` for runner workspace (`/runner/_work`, local-path storage)
- **Docker:** Docker-in-Docker (DinD) sidecar for native ARM64 builds
- **Secrets:** Runner token from Vault via `ExternalSecret`

### Node Selection Strategy

The deployment uses **node affinity + tolerations** for intelligent placement with automatic failover:

**Preference order (weighted):**
1. **node-2** (weight: 100) — Moderate load (52% memory, 42 pods), no taints, stable
2. **node-1** (weight: 50) — Light load (27% memory, 8 pods), has `PreferNoSchedule` taint
3. **node-3** (weight: 30) — Heavier load (62% memory, 36 pods), critical workloads (Vault, Postgres)

**Actual scheduling:**
- Runner will follow **PVC node affinity** first (local-path storage is node-bound)
- If PVC is on node-1, runner stays on node-1 for storage locality
- On fresh deployment or PVC recreation, scheduler uses preference weights

**Tolerations:**
- Tolerates `eldertree.xyz/prefer-stable-nodes=true:PreferNoSchedule` (node-1's taint)
- CI/CD workloads can handle occasional node instability

**Failover behavior:**
- If current node becomes NotReady, pod reschedules to next available node
- PVC rebinds to new node (data persists, but Docker cache rebuilds)
- Runner auto-registers with same name on new node

### Resource Allocation

```yaml
Requests:
  CPU: 1 core
  Memory: 2GB

Limits:
  CPU: 3 cores
  Memory: 4GB
```

## Manifests Location

All manifests are in `clusters/eldertree/github-runner/`:

```
github-runner/
├── namespace.yaml          # github-runner namespace
├── pvc.yaml                # 20GB workspace storage (local-path, node-affine)
├── external-secret.yaml    # Vault integration for runner token
├── deployment.yaml         # Runner pod with affinity, tolerations, DinD
└── kustomization.yaml      # FluxCD bundle
```

**Key manifest features:**
- **Node affinity:** Weighted preference (node-2 > node-1 > node-3)
- **Tolerations:** `eldertree.xyz/prefer-stable-nodes=true:PreferNoSchedule`
- **Labels:** `app=github-runner`, `workload-type=ci-cd`
- **Strategy:** `Recreate` (no rolling update, runner must deregister cleanly)

## Vault Configuration

The runner token is stored in Vault at `secret/eldertree/github-runner`:

```bash
# View current secret (requires Vault auth)
kubectl exec -n vault vault-0 -- sh -c "export VAULT_TOKEN=\$(kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.ROOT_TOKEN}' | base64 -d) && vault kv get secret/eldertree/github-runner"
```

### Regenerating Runner Token

Runner tokens expire after 1 hour but the runner automatically exchanges them for a permanent token on first registration. To generate a new token (e.g., for adding more runners):

```bash
# Generate new token
cd /path/to/repo
TOKEN=$(gh api -X POST repos/raolivei/ollie/actions/runners/registration-token --jq '.token')

# Update Vault
kubectl exec -n vault vault-0 -- sh -c "export VAULT_TOKEN=hvs.YOUR_ROOT_TOKEN && vault kv put secret/eldertree/github-runner token='${TOKEN}' repo-url='https://github.com/raolivei/ollie'"
```

## Using the Self-Hosted Runner

### In GitHub Workflows

Update your workflow to use the `runs-on` parameter (requires [raolivei/github-workflows](https://github.com/raolivei/github-workflows) reusable workflow):

```yaml
jobs:
  build:
    uses: raolivei/github-workflows/.github/workflows/docker-build.yml@main
    with:
      runs-on: '["self-hosted", "Linux", "ARM64", "eldertree"]'
      image-name: my-app
      dockerfile: Dockerfile
    secrets:
      REGISTRY_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Runner Labels

The runner is configured with these labels:
- `self-hosted` — Indicates non-GitHub-hosted runner
- `Linux` — OS type
- `ARM64` — Architecture
- `eldertree` — Cluster-specific label

## Monitoring

### Check Runner Status

```bash
# Runner pod logs
kubectl logs -n github-runner -l app=github-runner -f

# Runner pod status
kubectl get pods -n github-runner

# PVC usage
kubectl get pvc -n github-runner

# Resource usage on node-1
kubectl top node node-1.eldertree.local
kubectl top pod -n github-runner
```

### GitHub UI

Check runner status in the repository:
1. Go to repo Settings → Actions → Runners
2. Look for `eldertree-runner-1` with green status
3. Verify labels: `self-hosted`, `Linux`, `ARM64`, `eldertree`

### Common Issues

**Runner offline:**
```bash
# Check pod status
kubectl describe pod -n github-runner -l app=github-runner

# Check external secret sync
kubectl get externalsecret -n github-runner github-runner-token
kubectl describe externalsecret -n github-runner github-runner-token

# Check Vault connectivity
kubectl exec -n github-runner -it $(kubectl get pod -n github-runner -l app=github-runner -o name) -- env | grep -E "REPO_URL|RUNNER_TOKEN"
```

**Builds failing with storage errors:**
```bash
# Check PVC size
kubectl get pvc -n github-runner runner-workspace -o jsonpath='{.status.capacity.storage}'

# Check node disk usage
kubectl exec -n github-runner $(kubectl get pod -n github-runner -l app=github-runner -o name) -- df -h /runner/_work

# Increase PVC size (requires storage class support)
kubectl patch pvc runner-workspace -n github-runner -p '{"spec":{"resources":{"requests":{"storage":"40Gi"}}}}'
```

**Docker layer cache not persisting:**
- Verify PVC is bound and mounted at `/runner/_work`
- Check Docker buildx cache config in workflow
- Inspect build logs for cache hit/miss rates

### Testing Failover

To verify automatic failover to another node:

**Option 1: Cordon current node (safe, no downtime)**
```bash
# Find current node
NODE=$(kubectl get pod -n github-runner -l app=github-runner -o jsonpath='{.items[0].spec.nodeName}')

# Cordon node (prevent new scheduling)
kubectl cordon $NODE

# Delete runner pod (triggers reschedule)
kubectl delete pod -n github-runner -l app=github-runner

# Wait for pod to reschedule
kubectl get pods -n github-runner -o wide -w

# Uncordon when done
kubectl uncordon $NODE
```

**Expected behavior:**
- Pod reschedules to next preferred node based on affinity weights
- PVC may need to rebind (local-path storage recreates on new node)
- Runner re-registers automatically with same name
- Docker cache rebuilds (first build after failover is slower)

**Option 2: Drain node (production-like, planned maintenance)**
```bash
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data --timeout=5m
# ... perform maintenance ...
kubectl uncordon $NODE
```

## Scaling

### Adding More Runners

To add additional runners (e.g., for parallel builds):

1. Generate a new runner token (see "Regenerating Runner Token" above)
2. Create additional Deployment manifests:
   ```bash
   cp clusters/eldertree/github-runner/deployment.yaml \
      clusters/eldertree/github-runner/deployment-2.yaml
   ```
3. Update runner name: `RUNNER_NAME: "eldertree-runner-2"`
4. Update node selector if distributing across nodes:
   ```yaml
   nodeSelector:
     kubernetes.io/hostname: node-2.eldertree.local
   ```
5. Add to `kustomization.yaml` resources

### Actions Runner Controller (ARC)

For dynamic auto-scaling (future enhancement):

**Pros:**
- Ephemeral runners (clean state per job)
- Auto-scale based on queue depth
- Better resource utilization

**Cons:**
- No persistent Docker cache (slower builds)
- More complex setup (requires ARC operator)
- Higher API request volume to GitHub

**Recommendation:** Stick with persistent runner unless build queue length becomes a bottleneck.

## Security Considerations

### Current Mitigations

- **Non-root pod:** Runner runs as UID 1000/GID 1000
- **Token rotation:** Runner token managed via Vault (not in Git)
- **Namespace isolation:** Dedicated `github-runner` namespace
- **Resource limits:** CPU/memory limits prevent noisy neighbor issues

### Future Enhancements

1. **NetworkPolicy:** Restrict egress to GitHub API/GHCR only:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: github-runner-egress
     namespace: github-runner
   spec:
     podSelector:
       matchLabels:
         app: github-runner
     policyTypes:
       - Egress
     egress:
       - to:
           - namespaceSelector: {}
         ports:
           - protocol: TCP
             port: 53  # DNS
       - to:
           - cidrBlock: 0.0.0.0/0
         ports:
           - protocol: TCP
             port: 443  # GitHub API/GHCR
   ```

2. **Rootless Docker:** Replace host Docker socket with rootless Docker-in-Docker
3. **Dedicated node:** Use `nodeAffinity` to isolate runner on a specific node

## Cost & Performance

### Build Time Comparison

| Build Type | GitHub-Hosted (ARM64 emulated) | Eldertree Self-Hosted |
|------------|--------------------------------|-----------------------|
| Ollie core (cold) | ~25 min | ~8 min (native ARM64) |
| Ollie core (warm cache) | ~25 min | ~3 min (layer cache hit) |
| All 6 services (parallel) | 120 min timeout risk | ~30 min total |

### Storage Usage

- **Runner workspace:** 20GB PVC
- **Docker layers:** Shared host storage (~10-15GB over time)
- **Build artifacts:** Cleaned after each job
- **Total impact:** ~30-35GB on node-1 NVMe

## Maintenance

### Regular Tasks

**Weekly:**
- Check runner logs for errors
- Verify PVC storage usage trend
- Review build times for cache effectiveness

**Monthly:**
- Update runner image: `ghcr.io/actions/actions-runner:latest`
- Clean up old Docker layers on host: `docker system prune -a -f`
- Review resource usage and adjust limits if needed

**Quarterly:**
- Evaluate Actions Runner Controller adoption
- Assess scaling to additional nodes

### Updating Runner Image

The runner uses the official GitHub Actions image:

```yaml
image: ghcr.io/actions/actions-runner:latest
```

To update:
1. Edit `clusters/eldertree/github-runner/deployment.yaml`
2. Change tag to specific version (e.g., `ghcr.io/actions/actions-runner:2.317.0`)
3. Commit and push (FluxCD auto-deploys)
4. Verify: `kubectl get pods -n github-runner -o wide`

## References

- [GitHub Self-Hosted Runners Docs](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller)
- [Pi-fleet commit d2e3419](https://github.com/raolivei/pi-fleet/commit/d2e3419) — Native ARM64 runners mention
- [Eldertree cluster specs](CLUSTER_SPECS.md)
- [Vault integration](VAULT.md)

## Changelog

### 2026-06-04 - Initial Deployment
- Single persistent runner on node-1
- 20GB PVC for workspace
- Vault-backed token management
- Deployed for raolivei/ollie builds

---

**Last Updated:** 2026-06-04  
**Maintained By:** [@raolivei](https://github.com/raolivei)
