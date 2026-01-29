# Changelog

## [Unreleased]

### Changed

- **Prometheus scrape config for Lens IDE**
  - Added `node` label to `kubernetes-nodes` and `kubernetes-nodes-cadvisor` scrape jobs
  - Lens matches node metrics by Kubernetes node name; without this label, node metrics in Lens stay loading
  - Use Prometheus address in Lens: `observability/observability-monitoring-stack-prometheus-server:80`

## [1.3.8] - 2026-01-27

### Added

- **k3s Upgrade Playbook** (`ansible/playbooks/upgrade-k3s.yml`)
  - Rolling k3s-only upgrades (no OS updates, no reboot required)
  - One node at a time via `serial: 1` for cluster availability
  - Kubernetes drain/uncordon for graceful workload migration
  - Uses `k3s_version` from `group_vars/all.yml` as target
  - Pre-flight version checks (skips nodes already at target)
  - Respects PodDisruptionBudgets during drain
  - Post-upgrade cluster health verification
  - Complements `security-update.yml` for K8s version upgrades between maintenance windows

- **Vertical Pod Autoscaler (VPA)** (`clusters/eldertree/autoscaling/vpa/`)
  - Fairwinds VPA Helm chart deployment
  - Recommender enabled (provides resource recommendations)
  - Updater and AdmissionController disabled (recommendation-only mode)
  - VPA resources for swimto-api and swimto-web workloads
  - Helps optimize resource utilization on limited Raspberry Pi hardware

- **Native Sidecar Container POC** (`clusters/eldertree/swimto/redis-deployment.yaml`)
  - Demonstrates Kubernetes 1.33+ native sidecar pattern
  - Redis-exporter as native sidecar using `restartPolicy: Always` in initContainers
  - Proper lifecycle management (starts before main container, terminates with it)
  - Local Redis monitoring with metrics exposed on port 9121

### Changed

- **k3s cluster upgraded** to v1.35.0+k3s1 across all nodes (Kubernetes 1.35)
  - Traefik v3.5.1
  - CoreDNS v1.13.1
  - Containerd 2.1.5
  - Extended certificate renewal (90 → 120 days)
  - All K8s 1.34 features now GA

### Fixed

- **Traefik LoadBalancer IP configuration**
  - Added `loadBalancerIP: 192.168.2.200` to Traefik HelmChartConfig
  - Prevents kube-vip from assigning wrong IP (was conflicting with Pi-hole's 192.168.2.201)
  - Traefik ingress VIP is now correctly pinned via IaC

### Documentation

- Updated `NETWORK.md` with Bell Giga Hub DNS limitations
- Added macOS terminal commands for direct Pi-hole DNS configuration
- Added `upgrade-k3s.yml` documentation to `ansible/README.md`

## [1.3.7] - 2026-01-25

### Fixed

- **k3s API server binding for kube-vip compatibility**
  - Changed `bind-address` from `10.0.0.1` to `0.0.0.0` on all control plane nodes
  - This allows the API server to accept connections from the kube-vip VIP (192.168.2.100)
  - Previously, the API server only listened on the gigabit network, making VIP inaccessible

### Changed

- **Updated `configure-k3s-gigabit.yml` playbook**
  - Refactored to use `/etc/rancher/k3s/config.yaml` instead of modifying the service file
  - Cleaner and more maintainable configuration management
  - Sets `bind-address: 0.0.0.0` for kube-vip compatibility

- **New variable in `group_vars/all.yml`**
  - `k3s_bind_address: "0.0.0.0"` - API server bind address for kube-vip

### Documentation

- Updated `docs/NETWORK_ARCHITECTURE.md` with k3s API server binding configuration

## [1.3.6] - 2026-01-20

### Added

- **Security Update Playbook** (`ansible/playbooks/security-update.yml`)
  - Rolling updates - one node at a time to maintain cluster availability
  - Full OS upgrade with `apt dist-upgrade`
  - Raspberry Pi EEPROM firmware updates
  - k3s upgrade to latest stable version
  - Kubernetes drain/uncordon for graceful workload migration
  - Pre-flight checks (disk space, node health)
  - Safe reboot with connectivity verification
  - Post-update cluster health verification

### Usage

```bash
# Full rolling update (all nodes)
ansible-playbook playbooks/security-update.yml

# Single node only
ansible-playbook playbooks/security-update.yml --limit node-3

# Skip k3s upgrade
ansible-playbook playbooks/security-update.yml -e skip_k3s_upgrade=true
```

## [1.3.5] - 2026-01-20

### Changed

- **Replaced MetalLB with kube-vip for LoadBalancer services**
  - kube-vip now provides both control plane HA and service LoadBalancer
  - VIPs bind directly to `wlan0` interface (kernel handles ARP)
  - Eliminates userspace ARP issues with Bell Giga Hub router
  - Traefik: 192.168.2.200, Pi-hole: 192.168.2.201
  - kube-vip services IP range: 192.168.2.200/28

### Removed

- **MetalLB** - Fully removed from cluster
  - HelmRelease, HelmRepository, IPAddressPool, L2Advertisement deleted
  - Namespace `metallb-system` removed
  - PodDisruptionBudget for metallb-controller removed
  - Saves ~8 pods worth of resources

### Fixed

- **Duplicate cert-manager installation** - Disabled cert-manager subchart in `cert-manager-issuers`
  - Only one cert-manager instance now runs in the cluster

### Documentation

- Updated NETWORK.md with kube-vip LoadBalancer documentation
- Updated SERVICES_REFERENCE.md with new access methods
- Removed Wi-Fi client isolation workarounds (no longer needed)

## [1.3.4] - 2026-01-18

### Fixed

- **MetalLB VIP not responding** - Fixed L2Advertisement to use `wlan0` interface
  - MetalLB speakers were not announcing VIPs on the physical network
  - Added `interfaces: [wlan0]` to L2Advertisement config
  - VIP 192.168.2.200 now correctly responds via Traefik ingress
  - All `*.eldertree.local` services accessible via VIP

### Changed

- **MetalLB HelmRelease** - Updated speaker security context
  - Added `NET_ADMIN` capability for L2 interface binding (note: not actually needed, keeping for reference)
  - Speakers now properly announce on `wlan0` interface

### Added

- **WireGuard HA Plan Update** (Issue #49)
  - Updated with new cluster topology (nodes 101-103)
  - Added kube-vip VIP strategy (192.168.2.202 for WireGuard)
  - DaemonSet deployment approach with shared keys
  - Helm chart structure for WireGuard deployment

### Documentation

- Updated `NETWORK.md` with current cluster topology
- Added VIP table and k3s network information
- Updated `/etc/hosts` examples with correct VIP

## [1.3.3] - 2026-01-18

### Added

- **Terraform Vault Provider Configuration** (Issue #23):
  - Added HashiCorp Vault provider (~> 4.0) to Terraform
  - Created `vault.tf` for declarative Vault configuration management
  - Manages Vault policies, Kubernetes auth method, and service tokens via Terraform
  - Project-specific policies for canopy, swimto, journey, nima, us-law-severity-map, monitoring, ollie
  - Infrastructure policy for pi-fleet, pihole, flux, external-dns, terraform, cloudflare-tunnel, pitanga
  - ESO read-only policy for External Secrets Operator
  - Kubernetes auth roles bound to project namespaces
  - Service tokens for External Secrets Operator integration
- **Vault Configuration Variables**:
  - `vault_address`: Vault server URL (default: http://127.0.0.1:8200)
  - `vault_token`: Authentication token (sensitive)
  - `vault_skip_tls_verify`: Skip TLS verification flag
  - `skip_vault_resources`: Skip Vault management in CI
  - `kubernetes_host`: Kubernetes API URL for auth method
  - `vault_projects`: Configurable list of projects with policies
- Updated `terraform.tfvars.example` with Vault configuration examples
- Updated `terraform/README.md` with comprehensive Vault documentation

### Changed

- GitHub Actions workflow now sets `skip_vault_resources=true` for CI (Vault not accessible in CI)
- Remote state persisted in Terraform Cloud (organization: eldertree, workspace: pi-fleet-terraform)

### Deprecated

- Shell script `scripts/operations/setup-vault-policies.sh` - use Terraform for Vault configuration

## [1.3.2] - 2026-01-07

### Added
- **Flux Image Automation for Pitanga Website**:
  - `ImageRepository` for scanning GHCR for new images
  - `ImagePolicy` with semver range (`>=0.1.0 <0.2.0`)
  - `ImageUpdateAutomation` to automatically update the deployment image tag in Git
- Enabled automatic deployment for `pitanga-website` via GitOps setters
- Added `pitanga.cloud` to `external-dns` Cloudflare domain filters
- Enabled Cloudflare Proxy (orange cloud) for Pitanga public ingress via annotations

## [1.3.1] - 2025-12-28

### Added

- **Comprehensive Grafana Dashboards for Pi Cluster Management**:
  - `Pi Fleet Overview`: Unified view of cluster health, resource utilization, and hardware status.
  - `Hardware Health`: Specialized dashboard for Raspberry Pi hardware metrics (temperature, frequency, throttling).
- Updated `DASHBOARDS.md` with new dashboard information.

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

### Changed

- **Optimized resource limits for Raspberry Pi nodes**:
  - Reduced FluxCD components limits from 1000m/1Gi to 500m/512Mi
  - Reduced KEDA components limits from 1000m/1000Mi to 500m/512Mi
  - Reduced Journey API limits from 1000m/1Gi to 500m/512Mi
  - Fixes "Specified limits are higher than node capacity!" error on smaller nodes
- **Ansible playbooks updated for Raspberry Pi Imager workflow**:
  - User creation removed from playbooks (handled by Raspberry Pi Imager)
  - SSH key configuration removed from playbooks (handled by Raspberry Pi Imager)
  - Hostname auto-detection: Converts generic "node-x" hostname from SD cards to proper `node-X.eldertree.local`
  - Automatic cleanup of diagnostic files after successful playbook runs
  - Removed password management from playbooks (user created via Imager)
- **Cleanup automation**: All playbooks now automatically remove diagnostic log files and old backup files (>7 days)
- Updated documentation to reflect Raspberry Pi Imager workflow

### Security

- **CRITICAL:** Removed all hardcoded passwords from codebase
  - Ansible playbooks now use Ansible Vault or environment variables
  - Scripts require `PI_PASSWORD` environment variable (no default)
  - Inventory file uses `ANSIBLE_PASSWORD` environment variable
  - Terraform example file uses placeholder instead of real password
  - All documentation updated to remove password references
  - Added `.gitignore` entries for Ansible Vault files
  - Created `vault.yml.example` template for secure password management
  - **Note:** Password was previously committed to git history - consider rotating it

### Added

- Standard repository configuration following workspace conventions:
  - `VERSION` file for tracking project version (1.3.0)
  - `github/branch-protection-config.json` with Terraform workflow status check
  - `github/setup-branch-protection.sh` script for enabling branch protection
  - `.github/workflows/README.md` documenting Terraform workflow and versioning strategy
- External Secrets Operator for automatic Vault to Kubernetes secret syncing
- Ansible Vault template (`ansible/group_vars/raspberry_pi/vault.yml.example`)
- Security fix summary documentation (`SECURITY_FIX_SUMMARY.md`)
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
