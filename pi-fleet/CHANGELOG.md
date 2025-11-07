# Changelog

## [Unreleased]

### Added

- Network configuration documentation (NETWORK.md)
- Updated FLEET.md with current IP addresses and service domains
- Flux GitOps installation and configuration
- Longhorn storage provisioner manifests (single-node config)
- cert-manager with self-signed ClusterIssuer for local TLS
- Prometheus monitoring with persistent storage
- Grafana with Kubernetes dashboards and ingress
- Infrastructure directory structure for cluster components
- All services configured with Traefik ingress and TLS

### Changed

- Marked eldertree as single-node cluster in documentation
- Separated ClusterIssuer from cert-manager manifests for proper dependency ordering

### Fixed

- Installed open-iscsi on eldertree for Longhorn storage requirements
