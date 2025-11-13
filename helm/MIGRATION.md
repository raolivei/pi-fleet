# Helm Chart Migration

## Summary

Converted infrastructure components to custom Helm charts for better management and reusability.

## Created Charts

### 1. cert-manager-issuers

**Location:** `helm/cert-manager-issuers/`
**Purpose:** Manages ClusterIssuers (self-signed, ACME)
**Deployed via:** `clusters/eldertree/infrastructure/issuers/helmrelease.yaml`

### 2. monitoring-stack

**Location:** `helm/monitoring-stack/`
**Purpose:** Bundles Prometheus + Grafana with coordinated config
**Deployed via:** `clusters/eldertree/monitoring/helmrelease.yaml`

## Files to Clean Up (Old)

These files are superseded by Helm charts but kept for reference:

```
clusters/eldertree/infrastructure/issuers/selfsigned-issuer.yaml
clusters/eldertree/monitoring/namespace.yaml
clusters/eldertree/monitoring/helmrepository.yaml
clusters/eldertree/monitoring/prometheus/helmrelease.yaml
clusters/eldertree/monitoring/grafana/helmrelease.yaml
```

## Benefits

- **Templating**: Values can be easily customized
- **Versioning**: Charts have explicit versions
- **Dependencies**: Managed via Chart.yaml
- **Reusability**: Charts can be packaged and shared
- **GitOps**: FluxCD deploys directly from git repository

## Deployment

FluxCD automatically syncs charts from the git repository:

```yaml
sourceRef:
  kind: GitRepository
  name: flux-system
  namespace: flux-system
```
