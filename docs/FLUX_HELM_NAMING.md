# Flux Helm naming conventions (Eldertree)

Flux HelmController defaults Helm **release names** to `{targetNamespace}-{helmReleaseName}` when they differ, and `{namespace}-{name}` when the HelmRelease lives in the same namespace as its target. When **metadata.name equals namespace.name**, releases become doubled (`openclaw-openclaw`, `arc-controller-arc-controller`).

Doubled release names propagate into chart-generated resources (ServiceAccounts, RoleBindings, labels) and make cross-references error-prone — see ARC runners RBAC incident (2026-06).

## Rule: always set `releaseName`

Every `HelmRelease` in `clusters/eldertree/**` must set:

```yaml
spec:
  releaseName: <metadata.name>   # short, stable, matches app identity
  targetNamespace: <app-namespace>
```

Examples:

| HelmRelease | Namespace | `releaseName` | Avoids |
|---|---|---|---|
| `openclaw` | `openclaw` | `openclaw` | `openclaw-openclaw` |
| `monitoring-stack` | `observability` | `monitoring-stack` | `observability-monitoring-stack` |
| `ollie-runners` | `arc-runners` | `ollie-runners` | `arc-runners-ollie-runners` |
| `arc-controller` | `arc-controller` | `arc-controller` | `arc-controller-arc-controller` |

## ARC-specific naming

| Resource | Name | Notes |
|---|---|---|
| HelmRepository (OCI charts) | `arc-charts` | Shared by controller + scale-set charts; in `flux-system` |
| Controller Helm release | `arc-controller` | SA → `arc-controller-gha-rs-controller` |
| Runners Helm release | `ollie-runners` | Scale set name stays `ollie-eldertree` (GitHub identity) |
| ClusterRole (cross-ns secrets) | `arc-controller-secrets` | Binds to controller SA |

## Adding a new app

1. Create namespace + HelmRelease under `clusters/eldertree/<app>/`.
2. Set `releaseName: <metadata.name>` before first deploy.
3. If the chart exposes `controllerServiceAccount` or similar cross-release refs, derive names from **`releaseName`**, not Flux defaults.
4. Document any non-obvious name in the HelmRelease comment block.

## Migrating an existing doubled release

When changing `releaseName` on a live cluster, Helm treats it as a **new** release. One-time steps per app:

```bash
# 1. Suspend Flux management
flux suspend helmrelease <name> -n <namespace>

# 2. Remove old Helm release (keeps CRs/pods until Flux reconciles — verify app)
helm uninstall <old-doubled-name> -n <targetNamespace>

# 3. Resume and reconcile
flux resume helmrelease <name> -n <namespace>
flux reconcile helmrelease <name> -n <namespace> --with-source
```

### Migration map (2026-06 naming cleanup)

| Old Helm release | New `releaseName` | Namespace |
|---|---|---|
| `arc-controller-arc-controller` | `arc-controller` | `arc-controller` |
| `arc-runners-ollie-runners` | `ollie-runners` | `arc-runners` |
| `openclaw-openclaw` | `openclaw` | `openclaw` |
| `canopy-canopy` | `canopy` | `canopy` |
| `swimto-swimto` | `swimto` | `swimto` |
| `pitanga-pitanga` | `pitanga` | `pitanga` |
| `personal-website-personal-website` | `personal-website` | `personal-website` |
| `observability-monitoring-stack` | `monitoring-stack` | `observability` |
| `observability-flux-ui` | `flux-ui` | `observability` |

For ARC only, also delete superseded cluster RBAC and HelmRepository after reconcile:

```bash
kubectl delete clusterrole,clusterrolebinding arc-controller-gha-rs-controller-secrets --ignore-not-found
kubectl delete clusterrole,clusterrolebinding arc-controller-arc-controller-gha-rs-controller --ignore-not-found
kubectl delete helmrepository arc-controller -n flux-system --ignore-not-found
kubectl delete helmrepository arc-charts -n arc-controller --ignore-not-found  # misplaced by old kustomize namespace transform
```

**Note:** `arc-charts-helmrepository.yaml` lives at `clusters/eldertree/` root (not under `arc-controller/`) so Kustomize does not rewrite its namespace to `arc-controller`.

## References

- [ARC_RUNNERS.md](ARC_RUNNERS.md)
- [Flux HelmRelease spec](https://fluxcd.io/flux/components/helm/helmreleases/)
