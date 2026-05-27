# Pi Fleet

![K3s](https://img.shields.io/badge/K3s-1.35+-326CE5.svg?logo=kubernetes)
![Ansible](https://img.shields.io/badge/Ansible-2.14+-EE0000.svg?logo=ansible)
![Terraform](https://img.shields.io/badge/Terraform-1.10+-7B42BC.svg?logo=terraform)
![ARM64](https://img.shields.io/badge/arch-ARM64-orange.svg)
![Terraform](https://github.com/raolivei/pi-fleet/actions/workflows/terraform.yml/badge.svg)

Production-grade K3s cluster on Raspberry Pi 5 hardware, managed with Ansible, Terraform, and FluxCD. Features high availability, automatic node recovery, comprehensive monitoring, and GitOps deployment.

> **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md) for git workflow and branching strategy.

## Features

- **High Availability**: 3-node control plane with kube-vip VIP (192.168.2.100)
- **Automatic Recovery**: Hardware watchdog with boot loop protection prevents extended outages
- **GitOps**: FluxCD automatically syncs cluster state from git
- **Comprehensive Monitoring**: Prometheus, Grafana, Loki, Promtail, and Blackbox synthetic probes
- **Secure by Default**: HashiCorp Vault for secrets, cert-manager for SSL, Traefik ingress
- **Fast Storage**: NVMe SSD boot via PCIe HAT (vs slow SD cards)
- **Infrastructure as Code**: Ansible for system config, Terraform for cloud resources
- **Production Apps**: Canopy (personal finance), swimTO (pool schedules), Pi-hole (DNS)

## Hardware

- **Raspberry Pi 5** (8GB RAM, ARM64)
- **Debian 12 Bookworm** (64-bit)
- **NVMe SSD Boot** (via PCIe HAT)
- **BCM2835 Hardware Watchdog** (automatic node recovery)

## Cluster Nodes

The eldertree cluster consists of 3 identical Raspberry Pi 5 nodes in a fully HA configuration:

| Node | WiFi IP | Gigabit IP | Role |
|------|---------|------------|------|
| node-1 | 192.168.2.101 | 10.0.0.1 | control-plane, etcd, master |
| node-2 | 192.168.2.102 | 10.0.0.2 | control-plane, etcd, master |
| node-3 | 192.168.2.103 | 10.0.0.3 | control-plane, etcd, master |

**kube-vip VIP**: 192.168.2.100 (HA API server access)

## Quick Start

### Automated Setup (Recommended)

Use the automated setup script for complete cluster setup:

```bash
# Install prerequisites
brew install ansible terraform kubectl fluxcd/tap/flux hudochenkov/sshpass/sshpass

# Run automated setup
./scripts/setup/setup-eldertree.sh
```

This script orchestrates:

1. **Ansible** - System configuration (user, hostname, network, packages)
2. **Ansible** - K3s cluster installation (with HA control plane)
3. **Ansible** - Hardware watchdog setup (automatic node recovery)
4. **Ansible** - FluxCD GitOps bootstrap (optional)

The script is idempotent and can be run multiple times safely. See [ansible/README.md](ansible/README.md) for detailed playbook documentation.

### Manual Setup

For manual control or step-by-step deployment:

```bash
cd ansible

# 1. System configuration
ansible-playbook playbooks/setup-system.yml --ask-pass --ask-become-pass

# 2. K3s cluster installation (HA control plane)
ansible-playbook playbooks/install-k3s.yml --ask-pass --ask-become-pass

# 3. Hardware watchdog (automatic node recovery)
ansible-playbook playbooks/setup-hardware-watchdog.yml

# 4. Bootstrap FluxCD (optional, for GitOps)
ansible-playbook playbooks/bootstrap-flux.yml -e bootstrap_flux=true

# 5. Use cluster
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
kubectl get pods -A

# 6. Verify watchdog
../scripts/verify-watchdog.sh
```

See [ansible/README.md](ansible/README.md) for detailed playbook options and variables.

## Tool Selection

This project uses a hybrid approach with clear separation of concerns:

- **Ansible**: System configuration and operational tasks

  - User management, hostname, network configuration
  - Package installation (system tools, monitoring)
  - K3s cluster installation (HA control plane)
  - Hardware watchdog setup (BCM2835 with boot loop protection)
  - FluxCD GitOps bootstrap
  - NVMe boot configuration (PCIe HAT setup)
  - DNS configuration (local /etc/hosts)
  - Secret management (Vault operations)
  - Idempotent configuration management
  
  **Key Playbooks**: `setup-eldertree.yml`, `install-k3s.yml`, `setup-hardware-watchdog.yml`, `setup-nvme-boot.yml`

- **Terraform**: Infrastructure provisioning

  - Cloudflare DNS records (A, CNAME)
  - Cloudflare Tunnel creation and configuration
  - Infrastructure state management
  - **Note**: TLS certificates are managed by cert-manager via Helm, not Terraform

- **Helm**: Kubernetes application deployment
  - Custom Helm charts for cluster components
  - cert-manager issuers (TLS certificate management)
  - Monitoring stack (Prometheus + Grafana + Loki + Promtail)
  - Blackbox exporter (synthetic monitoring)
  - KEDA scaled objects
  - Application configuration via values.yaml
  
  **Custom Charts**: `monitoring-stack`, `cert-manager-issuers` (see [helm/README.md](helm/README.md))

See [ansible/README.md](ansible/README.md) and [helm/README.md](helm/README.md) for detailed documentation.

## Structure

```
ansible/                # Ansible playbooks (system config, K3s install, watchdog)
  ├── inventory/        # Host inventory (node-1, node-2, node-3)
  ├── playbooks/        # System setup, K3s, NVMe boot, hardware watchdog
  └── group_vars/       # Centralized variables (network, IPs, K3s version)
terraform/              # Infrastructure as code (Cloudflare DNS/Tunnel)
clusters/eldertree/     # FluxCD manifests (GitOps)
  ├── core-infrastructure/   # Traefik, cert-manager, external-dns
  ├── observability/         # Monitoring stack, Loki
  ├── flux-system/           # FluxCD bootstrap
  └── <apps>/                # Application deployments
helm/                   # Custom Helm charts (monitoring-stack, cert-manager-issuers)
scripts/                # Utility scripts
  ├── setup/            # Cluster setup automation
  ├── operations/       # Vault, secrets, backups, kubeconfig
  ├── diagnostics/      # Validation and troubleshooting
  └── verify-watchdog.sh # Hardware watchdog verification
docs/                   # 90+ documentation files (setup, troubleshooting, runbooks)
```

## Documentation

### Key Documentation
- **Hardware Watchdog**: [docs/HARDWARE_WATCHDOG.md](docs/HARDWARE_WATCHDOG.md) - Automatic node recovery with boot loop protection
- **Network Architecture**: [NETWORK.md](NETWORK.md) - DNS, network topology, access patterns
- **Vault & Secrets**: [VAULT.md](VAULT.md) - HashiCorp Vault setup and management
- **Ingress Setup**: [docs/INGRESS.md](docs/INGRESS.md) - Traefik, cert-manager, SSL certificates
- **Contributing**: [CONTRIBUTING.md](CONTRIBUTING.md) - Git workflow and branching strategy

### Monitoring & Observability
- **Blackbox Monitoring**: [docs/OBSERVABILITY_BLACKBOX_AND_SYNTHETIC.md](docs/OBSERVABILITY_BLACKBOX_AND_SYNTHETIC.md)
- **Grafana Dashboards**: [helm/monitoring-stack/DASHBOARDS.md](helm/monitoring-stack/DASHBOARDS.md)

### Troubleshooting
- **Runbook** (check first for issues): https://docs.eldertree.xyz
- **Ansible Playbooks**: [ansible/README.md](ansible/README.md)
- **Password Management**: [docs/PASSWORD_MANAGEMENT.md](docs/PASSWORD_MANAGEMENT.md)

## Helm Charts

Custom charts for cluster components (Helm v4 compatible):

- **cert-manager-issuers**: ClusterIssuers (self-signed, ACME)
- **monitoring-stack**: Prometheus + Grafana

See [helm/README.md](helm/README.md) for details.

## Cluster Status

**Current State:**

- **Cluster**: 3-node HA control plane (node-1, node-2, node-3)
- **K3s**: v1.35.0+k3s1
- **GitOps**: FluxCD (30m reconciliation interval)
- **Ingress**: Traefik 3.5 (pre-installed with K3s)
- **SSL**: cert-manager with ClusterIssuer
- **DNS**: Pi-hole, ExternalDNS (*.eldertree.local)
- **Monitoring**: Prometheus + Grafana + Loki + Promtail
- **Alerting**: Blackbox exporter, synthetic probes, boot loop protection
- **Storage**: Longhorn (distributed block storage)
- **Secrets**: HashiCorp Vault (HA mode)

**Recent Additions:**

- **Hardware Watchdog** (May 2026) - BCM2835 watchdog with boot loop protection for automatic node recovery
- **Monitoring Alerts** - Blackbox synthetic probes, alert rules, boot failure detection
- **Verification Scripts** - Automated validation for watchdog, ingress, and cluster health
- **FluxCD Standardization** - 30-minute reconciliation intervals across all resources
- **Grafana Dashboard Folders** - Organized dashboards by Application vs Platform categories

**Deployed Applications:**

- Grafana: https://grafana.eldertree.local
- Prometheus: https://prometheus.eldertree.local
- Canopy: https://canopy.eldertree.local
- Pi-hole: https://pihole.eldertree.local

See [NETWORK.md](NETWORK.md) for DNS setup and [SERVICES_REFERENCE.md](SERVICES_REFERENCE.md) for complete service inventory.

## Ingress and SSL Certificates

The cluster uses Traefik as the Ingress Controller (pre-installed with k3s), Cert-Manager for automatic SSL/TLS certificate management, and ExternalDNS for automatic DNS record creation.

**Quick Start:**

```bash
# Validate ingress setup
./scripts/diagnostics/validate-ingress-setup.sh

# Check ingress resources
kubectl get ingress -A

# Check certificates
kubectl get certificates -A
```

**Components:**

- **Traefik**: Ingress Controller (IngressClass: `traefik`)
- **Cert-Manager**: SSL certificate management (ClusterIssuer: `selfsigned-cluster-issuer`)
- **ExternalDNS**: Automatic DNS records for `*.eldertree.local` domains

See [docs/INGRESS.md](docs/INGRESS.md) for complete documentation on creating ingress resources with automatic SSL certificates and DNS.

## Secrets and Password Management

- Secrets are stored in Vault. See [VAULT.md](VAULT.md).
- To manage passwords for scripts and Ansible, see [PASSWORD_MANAGEMENT.md](docs/PASSWORD_MANAGEMENT.md).

```bash
./scripts/operations/sync-vault-to-k8s.sh
```

## Add Worker Nodes

The eldertree cluster currently runs as a 3-node HA control plane. To add worker nodes:

```bash
# Get token (saved by Ansible install-k3s.yml playbook)
cat ansible/k3s-node-token

# On worker node (fleet-worker-01, fleet-worker-02, etc.)
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.100:6443 K3S_TOKEN=<token> sh -

# Deploy hardware watchdog to new node (recommended)
cd ansible
ansible-playbook playbooks/setup-hardware-watchdog.yml --limit <node-name>
```

For detailed worker node setup, see [docs/ADD_WORKER_NODE.md](docs/ADD_WORKER_NODE.md).

## Validation & Verification

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Basic cluster validation
kubectl get nodes
kubectl get pods -A
kubectl get helmreleases -A

# Validate ingress setup
./scripts/diagnostics/validate-ingress-setup.sh

# Verify hardware watchdog
./scripts/verify-watchdog.sh

# Check FluxCD sync status
flux get kustomizations
flux get helmreleases -A
```

## Troubleshooting

**IMPORTANT**: Always check the runbook first when encountering issues:
- **Public**: https://docs.eldertree.xyz
- **Local**: https://docs.eldertree.local (within cluster network)

The runbook contains searchable documentation for common issues, with exact error messages and resolution steps. See the 90+ documentation files in `docs/` for setup guides, troubleshooting, and operational procedures.

### Common Issues
- Node freezes → Hardware watchdog automatically recovers
- DNS issues → Check Pi-hole status and ExternalDNS logs
- SSL certificate problems → Check cert-manager and ClusterIssuer status
- FluxCD not syncing → Run `flux reconcile kustomization flux-system`
- Vault sealed → See [VAULT.md](VAULT.md) for unseal procedures

## Cleanup

```bash
# Destroy Terraform-managed resources (Cloudflare DNS/Tunnel)
cd terraform
terraform destroy

# Remove K3s from nodes (if decommissioning)
/usr/local/bin/k3s-uninstall.sh  # On each node
```
