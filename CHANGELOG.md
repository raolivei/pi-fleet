# Changelog

## [Unreleased]

### Added

- External Secrets Operator for automatic Vault to Kubernetes secret syncing
- External-DNS with RFC2136 support for automated DNS record management
- Vault secrets management sync script (legacy, now automated)
- Grafana dashboards: 9 comprehensive K8s dashboards
- kube-state-metrics for detailed Kubernetes object metrics
- DASHBOARDS.md guide with PromQL queries

### Removed

- Consolidated DNS scripts: removed 8 redundant scripts
- Redundant Canopy Vault documentation and migration guides
- Unused Canopy sync-secrets.sh script

### Changed

- NETWORK.md: External-DNS as recommended DNS approach
- Pi-hole deployment: BIND sidecar for RFC2136 support
- Grafana: use Kubernetes secret from Vault instead of hardcoded password

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
