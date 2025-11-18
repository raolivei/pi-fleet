# Changelog

## [1.3.0] - 2025-01-XX

### Added
- WireGuard VPN infrastructure setup and documentation
- External Secrets Operator configurations for multiple services:
  - NIMA secrets
  - Pi-hole secrets
  - SwimTO secrets
  - US Law Severity Map secrets
- WireGuard quickstart and setup guides
- **Vault production mode with persistent storage** - secrets now survive restarts
- Vault management scripts:
  - `scripts/unseal-vault.sh` - Convenient unsealing after restarts
  - `scripts/backup-vault-secrets.sh` - Backup all secrets to JSON
  - `scripts/restore-vault-secrets.sh` - Restore secrets from backup
- Comprehensive Vault migration guide (`docs/VAULT_MIGRATION.md`)

### Changed
- **BREAKING:** Vault migrated from dev mode to production mode with persistence
  - Requires manual unsealing after each restart (3 of 5 unseal keys)
  - Root token and unseal keys must be stored securely
  - See VAULT_MIGRATION.md for migration steps
- Updated .cursorrules for project conventions
- Updated NETWORK.md documentation
- Updated VAULT.md documentation with production setup instructions
- Updated AI_SETUP_PROMPT.md to reflect production Vault configuration
- Updated Canopy deployment manifests (deploy.yaml, middleware.yaml, service.yaml)
- Updated External Secrets kustomization configuration
- Vault HelmRelease now uses file storage backend with 10Gi PVC

## [Unreleased]

### Added

- External Secrets Operator for automatic Vault to Kubernetes secret syncing
- External-DNS with RFC2136 support for automated DNS record management
- Vault secrets management sync script (legacy, now automated)
- Grafana dashboards: 9 comprehensive K8s dashboards
- kube-state-metrics for detailed Kubernetes object metrics
- DASHBOARDS.md guide with PromQL queries
- ExternalSecret for BIND TSIG secret in pihole namespace (pihole-bind-tsig-secret)

### Removed

- Consolidated DNS scripts: removed 8 redundant scripts
- Redundant Canopy Vault documentation and migration guides
- Unused Canopy sync-secrets.sh script
- Hardcoded TSIG secret from BIND ConfigMap (now uses Vault)

### Changed

- NETWORK.md: External-DNS as recommended DNS approach
- Pi-hole deployment: BIND sidecar for RFC2136 support
- Grafana: use Kubernetes secret from Vault instead of hardcoded password
- Pi-hole BIND configuration: TSIG secret now injected from Vault via External Secrets Operator
- Pi-hole deployment: bind-init container now injects TSIG secret from mounted secret volume
- Fixed missing pihole-upstream-dns ConfigMap in kustomization.yaml

### Fixed

- Pi-hole pod initialization failure due to missing pihole-upstream-dns ConfigMap
- External-DNS pod CrashLoopBackOff due to BIND service not being available
- External-DNS Cloudflare pod CrashLoopBackOff when Vault is sealed or secret missing
  - Suspended HelmRelease until Vault is unsealed and Cloudflare API token exists
  - Made secret reference optional in HelmRelease
  - Added helper script `fix-vault-and-cloudflare.sh` to automate setup

## [0.2.0] - 2025-11-12

### Added

- **Helm v4 Compatibility**: All custom charts (`cert-manager-issuers`, `monitoring-stack`) tested and working with Helm v4.0.0

## [0.1.0] - 2025-11-07

### Added

- Network configuration documentation (NETWORK.md)
- Updated FLEET.md with current IP addresses and service domains
- Flux GitOps installation and configuration
- cert-manager with self-signed ClusterIssuer for local TLS
- Prometheus monitoring with persistent storage
- Grafana with Kubernetes dashboards and ingress
- Infrastructure directory structure for cluster components
- All services configured with Traefik ingress and TLS
- Custom Helm charts directory (`helm/`)
- `cert-manager-issuers` Helm chart for managing ClusterIssuers
- `monitoring-stack` Helm chart bundling Prometheus and Grafana
- `update-kubeconfig.sh` script to rename cluster and context to "eldertree"
- Cluster name output in Terraform configuration

### Changed

- Cluster name standardized to "eldertree" across all kubeconfig contexts and clusters
- Terraform now automatically renames kubeconfig cluster/context to "eldertree"
- Updated Terraform README with cluster naming documentation
- Marked eldertree as single-node cluster in documentation
- Separated ClusterIssuer from cert-manager manifests for proper dependency ordering
- Converted cert-manager issuers to custom Helm chart
- Consolidated Prometheus and Grafana into monitoring-stack Helm chart
- Updated FluxCD HelmReleases to reference custom charts from git repository
- Renamed `clusters/core/` to `clusters/eldertree/` to match cluster name and support multi-cluster structure

### Removed

- Longhorn storage provisioner (deferred until specific use case emerges)
