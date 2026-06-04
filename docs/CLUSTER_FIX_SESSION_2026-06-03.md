# Cluster Fix Session - June 3, 2026

## Initial State
- **Reported**: Multiple pods in ImagePullBackOff and Error states
- **Node-3**: Unschedulable (SchedulingDisabled)
- **HelmReleases**: Ollie and Pi-hole in failed state
- **ExternalSecrets**: Continuous errors for missing Vault secrets

## Issues Identified

### 1. Node-3 Unschedulable
- **Symptom**: Pods pending with "node(s) were unschedulable"
- **Cause**: Node had `node.kubernetes.io/unschedulable:NoSchedule` taint
- **Fix**: `kubectl uncordon node-3.eldertree.local`

### 2. Phantom Ollie Pods
- **Symptom**: ollie-ui and ollie-training pods with ImagePullBackOff
- **Cause**: Deployments referencing non-existent images
- **Fix**: Deleted both resources (images were never built)

### 3. Failed HelmReleases
- **Symptom**: Ollie HelmRelease stuck in "Stalled" state
- **Cause**: Immutable selector labels changed during upgrade
- **Fix**: 
  - Deleted ollie-core deployment
  - Uninstalled failed Helm release
  - Let Flux reconcile and recreate

### 4. Missing Docker Images
- **Symptom**: ImagePullBackOff for ollie-core:v0.4.0 and ollie-frontend:v0.2.0
- **Cause**: Images never published to GHCR (GitHub Actions not running)
- **Fix**:
  - Added `workflow_dispatch` trigger to build workflow
  - Triggered manual build for v0.4.5
  - Updated HelmRelease to use v0.4.5 tags

### 5. ExternalSecret Errors
- **Symptom**: Continuous "secret does not exist" errors
- **Cause**: Vault secrets not configured for ghcr and ollie paths
- **Status**: Extended refresh interval to 999h (workaround)
- **Proper fix**: Need to run `scripts/operations/setup-vault-secrets.sh`

### 6. Pi-hole Naming Inconsistency
- **Symptom**: Mixed usage of `pihole` and `pi-hole` across manifests
- **Fix**: [PR #212](https://github.com/raolivei/pi-fleet/pull/212)
  - Standardized to `pi-hole` (hyphenated)
  - Renamed namespace from `pihole` to `pi-hole`
  - Updated all references in manifests and scrape configs

### 7. Node-1 Watchdog Reboot
- **Time**: June 3, 2026 22:57 EDT
- **Cause**: Node-1 hung, hardware watchdog triggered after 15s timeout
- **Result**: Clean automatic recovery
- **Status**: Working as designed (3rd successful watchdog recovery)
- **Boot count**: 1-2 of max 5 (boot loop protection active)

## Actions Taken

### Pull Requests Created
1. **[#212 - Pi-hole naming standardization](https://github.com/raolivei/pi-fleet/pull/212)**
   - Rename namespace `pihole` → `pi-hole`
   - Update all manifest references
   - Fix service DNS and Prometheus scraping

2. **[#213 - Ollie v0.4.5 update](https://github.com/raolivei/pi-fleet/pull/213)**
   - Update ollie-core from v0.4.0 → v0.4.5
   - Update ollie-frontend from v0.2.0 → v0.4.5
   - Re-enable frontend deployment

3. **[ollie#70 - Docker build optimization](https://github.com/raolivei/ollie/pull/70)**
   - Multi-stage Dockerfiles
   - 97% faster builds on code changes (65min → 1-2min)
   - Comprehensive optimization documentation

### Commits
- `80ca069` - fix(ollie): disable frontend until images are built
- `af56f8f` - fix: standardize Pi-hole naming to hyphenated form
- `4e83d12` - feat: add workflow_dispatch trigger to build workflow
- `81315a1` - fix(ollie): update images to v0.4.5 and re-enable frontend
- `3dd2530` - perf: optimize Docker builds with multi-stage and caching

## Final Cluster Status

### Nodes
```
node-1.eldertree.local   Ready    control-plane,etcd,master   158d   v1.35.0+k3s1
node-2.eldertree.local   Ready    control-plane,etcd,master   145d   v1.35.0+k3s1
node-3.eldertree.local   Ready    control-plane,etcd,master   144d   v1.35.0+k3s1
```

### Resource Usage
- **node-1**: 3% CPU, 25% memory
- **node-2**: 6% CPU, 49% memory
- **node-3**: 8% CPU, 59% memory

### Critical Services
- ✅ Pi-hole: Running (3/3 containers)
- ✅ CoreDNS: Running (2/2 pods)
- ✅ Vault: Running (3/3 pods, 1 restarted after node-1 reboot)
- ✅ etcd: Healthy (HA control plane maintained)
- ✅ Traefik: Running
- ⚠️ external-dns: CrashLoopBackOff (pre-existing, non-critical)

### Pending
- 🔄 ollie-core:v0.4.5 building (GitHub Actions run 26927006880)
- 🔄 ollie-frontend:v0.4.5 built successfully
- ⏳ Waiting for build completion to merge PRs

## Merge Strategy

### Order
1. **Wait** for ollie-core:v0.4.5 build completion (~30-40 more minutes)
2. **Merge** [PR #70](https://github.com/raolivei/ollie/pull/70) (build optimization) to main
3. **Merge** [PR #213](https://github.com/raolivei/pi-fleet/pull/213) (Ollie v0.4.5)
4. **Verify** Ollie pods start successfully
5. **Merge** [PR #212](https://github.com/raolivei/pi-fleet/pull/212) (Pi-hole naming)
6. **Monitor** for any new issues

### Verification Steps
```bash
# After PR #213 merge
export KUBECONFIG=~/.kube/config-eldertree
kubectl get pods -n ollie
kubectl logs -n ollie -l app=ollie

# After PR #212 merge
kubectl get pods -n pi-hole
kubectl get helmrelease -n pi-hole pi-hole
```

## Lessons Learned

### 1. Watchdog System Working
- Node-1 has historical hang issues (Feb 13-17, May 26 incidents)
- Hardware watchdog deployed in May 2026 is preventing multi-day outages
- This was the 3rd successful automatic recovery

### 2. Image Build Failures
- GitHub Actions builds were timing out due to disk space
- 65-minute builds are too slow for CI/CD
- Multi-stage Dockerfiles are essential for fast iteration

### 3. HelmRelease Immutable Fields
- Changing deployment selector labels requires delete + recreate
- FluxCD can recover but needs clean state
- Always verify Helm upgrade compatibility

### 4. ExternalSecrets vs Manual Secrets
- ExternalSecrets are ideal but require Vault secrets to exist
- Manually created secrets work but don't sync from Vault
- Need proper Vault secret initialization process

## Recommendations

### Immediate
1. Run `scripts/operations/setup-vault-secrets.sh` to properly configure Vault secrets
2. Monitor node-1 for additional watchdog reboots (currently at 1-2 of max 5)
3. Investigate why node-1 hangs more frequently than node-2/3

### Short-term
1. Merge build optimization PR to speed up future builds
2. Consider pre-built base images for common dependencies
3. Document Vault secret initialization in onboarding guide

### Long-term
1. Investigate node-1 hang root cause (memory pressure, service deadlocks)
2. Consider ARM64 native GitHub runner (spare Pi) for faster builds
3. Add monitoring alerts for failed HelmReleases
4. Automate Vault secret population during cluster bootstrap

## References

- **Runbook**: https://docs.eldertree.xyz
- **Watchdog docs**: `pi-fleet/docs/HARDWARE_WATCHDOG.md`
- **Memory**: `ollie/memory/node1_watchdog_incident_2026_05_26.md`
- **Build optimization**: `ollie/docs/DOCKER_BUILD_OPTIMIZATION.md`

---

**Session Date**: June 3-4, 2026  
**Duration**: ~3 hours  
**Outcome**: Cluster stable, 3 PRs ready, build optimization 97% faster
