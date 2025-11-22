# Emergency Deployment Strategy

## Overview

All projects in the eldertree cluster follow a **Flux-First with Emergency Override** deployment strategy. This document explains the approach and provides links to project-specific guides.

## Strategy

### Normal Operations (99% of time)

```
Git Commit → FluxCD → Cluster
```

- All deployments managed via GitOps
- Changes committed to `pi-fleet` repository
- Flux automatically reconciles every 5-10 minutes
- Drift is automatically corrected
- Full audit trail in Git history

### Emergency Operations (1% of time)

```
kubectl apply → Cluster (bypassing Flux)
```

- Used **ONLY** when Flux is completely unavailable
- Direct application of manifests to cluster
- Immediate deployment without waiting for Git sync
- Requires manual resumption of Flux afterward

## Architecture

Each project maintains **two copies** of Kubernetes manifests:

1. **Project Repository** (`<project>/k8s/`)

   - Owned by project team
   - Used for emergency deployments
   - Version controlled with project code

2. **Fleet Repository** (`pi-fleet/clusters/eldertree/<project>/`)
   - Managed by FluxCD
   - Source of truth for GitOps
   - Includes Flux-specific files (kustomization.yaml)

### Why Two Copies?

✅ **Emergency access**: Deploy without FluxCD dependency  
✅ **Project autonomy**: Each project owns its manifests  
✅ **Git history**: Changes tracked in project repos  
✅ **Disaster recovery**: Manifests available if pi-fleet is unavailable

## Project Emergency Scripts

Each project has three scripts in `scripts/`:

### 1. `emergency-deploy.sh`

- Suspends Flux reconciliation
- Applies manifests directly to cluster
- Shows deployment status

### 2. `resume-flux.sh`

- Resumes Flux reconciliation
- Forces immediate sync
- Restores GitOps control

### 3. `validate-k8s-sync.sh`

- Compares project manifests with pi-fleet
- Detects drift between copies
- Prevents deployment of stale manifests

## Projects Using This Strategy

| Project | Status              | Emergency Scripts | Documentation                                                    |
| ------- | ------------------- | ----------------- | ---------------------------------------------------------------- |
| swimTO  | ✅ Active in Flux   | ✅ Installed      | [EMERGENCY_DEPLOYMENT.md](../../swimTO/EMERGENCY_DEPLOYMENT.md)  |
| canopy  | 💤 Disabled in Flux | ✅ Installed      | [EMERGENCY_DEPLOYMENT.md](../../canopy/EMERGENCY_DEPLOYMENT.md)  |
| journey | 💤 Disabled in Flux | ✅ Installed      | [EMERGENCY_DEPLOYMENT.md](../../journey/EMERGENCY_DEPLOYMENT.md) |
| nima    | 💤 Disabled in Flux | ✅ Installed      | [EMERGENCY_DEPLOYMENT.md](../../nima/EMERGENCY_DEPLOYMENT.md)    |

## When to Use Emergency Deployment

### ✅ Valid Use Cases

- FluxCD is completely down (controller crashed)
- Critical production outage requiring immediate fix
- Cluster-wide GitOps failure
- pi-fleet repository is inaccessible
- You need to test a fix before committing to Git (rare!)

### ❌ Invalid Use Cases

- "Flux is too slow" - wait for the reconciliation
- "I don't want to commit yet" - use a feature branch
- Testing changes - commit to Git and let Flux deploy
- Convenience - GitOps is the correct process

## Emergency Deployment Procedure

### Standard Process

1. **Confirm Emergency**

   ```bash
   # Check if Flux is actually down
   flux get kustomizations -A
   kubectl get pods -n flux-system
   ```

2. **Navigate to Project**

   ```bash
   cd /Users/roliveira/WORKSPACE/raolivei/<project>
   ```

3. **Validate Manifests**

   ```bash
   ./scripts/validate-k8s-sync.sh
   ```

4. **Deploy**

   ```bash
   ./scripts/emergency-deploy.sh
   ```

5. **Verify**

   ```bash
   kubectl get pods -n <project>
   kubectl logs -n <project> -l app=<component>
   ```

6. **Document**

   - Note what was deployed
   - Why emergency deployment was needed
   - Timestamp and outcome

7. **Resume Flux**

   ```bash
   ./scripts/resume-flux.sh
   ```

8. **Commit Changes**

   ```bash
   # If you made changes to manifests
   cd pi-fleet
   git add clusters/eldertree/<project>/
   git commit -m "Emergency update: <description>"
   git push

   cd ../<project>
   git add k8s/
   git commit -m "Emergency update: <description>"
   git push
   ```

## Maintaining Manifest Sync

### Best Practices

1. **Always update both locations** when changing manifests
2. **Run validation script** before committing
3. **Commit to both repos** in the same session
4. **Use descriptive commit messages** referencing both changes

### Sync Workflow

```bash
# Make changes in project
vim <project>/k8s/deployment.yaml

# Copy to pi-fleet
cp <project>/k8s/*.yaml pi-fleet/clusters/eldertree/<project>/

# Validate
cd <project>
./scripts/validate-k8s-sync.sh

# Commit both
cd ../pi-fleet
git add .
git commit -m "Update <project> deployment"
git push

cd ../<project>
git add .
git commit -m "Update deployment manifests"
git push
```

## Troubleshooting

### Manifests Out of Sync

```bash
# Check differences
cd <project>
./scripts/validate-k8s-sync.sh

# Manual comparison
diff -r k8s/ ../pi-fleet/clusters/eldertree/<project>/

# Sync from project to pi-fleet
cp k8s/*.yaml ../pi-fleet/clusters/eldertree/<project>/

# Or sync from pi-fleet to project
cp ../pi-fleet/clusters/eldertree/<project>/*.yaml k8s/
```

### Flux Won't Suspend

```bash
# Check Flux status
flux check
kubectl get pods -n flux-system

# If Flux is already down, skip suspension
kubectl apply -f k8s/
```

### Can't Resume Flux

```bash
# Force reconcile without flux CLI
kubectl annotate -n flux-system \
  kustomization/flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" \
  --overwrite

# Restart Flux controllers
kubectl rollout restart -n flux-system deployment/kustomize-controller
kubectl rollout restart -n flux-system deployment/source-controller
```

### Emergency Changes Not Persisting

**Symptom**: Flux reverts your emergency changes

**Cause**: Changes not committed to Git

**Solution**:

```bash
# 1. Suspend Flux again
flux suspend kustomization flux-system --namespace flux-system

# 2. Update pi-fleet manifests to match cluster
kubectl get deployment <name> -n <namespace> -o yaml > temp.yaml
# Edit temp.yaml to remove cluster-specific fields
cp temp.yaml ../pi-fleet/clusters/eldertree/<project>/deployment.yaml

# 3. Commit to Git
cd ../pi-fleet
git add .
git commit -m "Persist emergency changes"
git push

# 4. Resume Flux
flux resume kustomization flux-system --namespace flux-system
```

## Monitoring and Alerts

### Regular Health Checks

```bash
# Check Flux status (daily)
flux get kustomizations -A

# Check for manifest drift (weekly)
for project in swimTO canopy journey nima; do
  echo "=== $project ==="
  cd /Users/roliveira/WORKSPACE/raolivei/$project
  ./scripts/validate-k8s-sync.sh
done
```

### Alert Conditions

Consider setting up alerts for:

- Flux controller crashes
- Reconciliation failures
- Manifest drift detection
- Extended periods without Git sync

## Philosophy

> **GitOps is the way, emergency deployment is the exception.**

This strategy acknowledges that:

1. **GitOps is superior** for production operations
2. **Emergencies happen** and require quick action
3. **Safety nets are valuable** when systems fail
4. **Process must be clear** to avoid misuse

The goal is **NOT** to bypass GitOps regularly, but to have a well-documented escape hatch when absolutely necessary.

## See Also

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [GitOps Principles](https://opengitops.dev/)
- [Cluster README](../clusters/eldertree/README.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)





