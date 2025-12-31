# Deployment Order for Eldertree Cluster

This document describes the deployment order and dependencies for HelmReleases in the eldertree cluster.

## Deployment Sequence

### Phase 1: Core Infrastructure (No Dependencies)
1. **cert-manager** - TLS certificate management
   - No dependencies
   - Installs CRDs for Certificate, ClusterIssuer, etc.

2. **longhorn** - Distributed block storage
   - No dependencies
   - Provides persistent volumes for applications
   - Requires nodes to have `/mnt/longhorn` prepared

### Phase 2: Certificate Issuers (Depends on cert-manager)
2. **cert-manager-issuers** - ClusterIssuer resources
   - Depends on: `cert-manager` (cert-manager namespace)
   - Creates self-signed and Let's Encrypt issuers

### Phase 3: Secrets Management (Can deploy in parallel with cert-manager)
3. **external-secrets** - External Secrets Operator
   - No dependencies (installs CRDs first)
   - Can sync from Vault once Vault is ready

4. **vault** - HashiCorp Vault
   - Depends on: `cert-manager-issuers` (for ingress TLS)
   - Note: Can be deployed manually before FluxCD bootstrap to break circular dependency

### Phase 4: DNS Services (Depends on secrets and certificates)
5. **external-dns** - External DNS controller
   - Depends on: `external-secrets` (for TSIG secret), `cert-manager-issuers` (for TLS)
   - Needs secrets synced from Vault

6. **pihole** - Pi-hole DNS server
   - Depends on: `external-secrets` (for web password), `cert-manager-issuers` (for ingress TLS)
   - Deployed via Deployment (not HelmRelease), but should wait for secrets

### Phase 5: Applications (Depends on infrastructure)
7. **swimto** - Toronto pool schedules
   - Depends on: `external-secrets` (for database secrets), `cert-manager-issuers` (for TLS)

8. **keda** - KEDA autoscaling
   - No critical dependencies, can deploy anytime

## Implementation

Dependencies are enforced using `dependsOn` in HelmRelease specs:

```yaml
spec:
  dependsOn:
    - name: dependency-name
      namespace: dependency-namespace
```

## Notes

- **Vault First**: Vault should be deployed manually before FluxCD bootstrap to avoid circular dependency (FluxCD needs GitHub token from Vault)
- **External Secrets**: Should be deployed early to sync secrets from Vault to Kubernetes
- **Cert-manager**: Should be deployed early for TLS certificate management
- **Applications**: All depend on secrets and certificates being available
