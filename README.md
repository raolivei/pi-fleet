# Pi Fleet

![K3s](https://img.shields.io/badge/K3s-1.33+-326CE5.svg?logo=kubernetes)
![Ansible](https://img.shields.io/badge/Ansible-2.14+-EE0000.svg?logo=ansible)
![Terraform](https://img.shields.io/badge/Terraform-1.5+-7B42BC.svg?logo=terraform)
![ARM64](https://img.shields.io/badge/arch-ARM64-orange.svg)
![Terraform](https://github.com/raolivei/pi-fleet/actions/workflows/terraform.yml/badge.svg)

K3s cluster on Raspberry Pi, managed with Ansible and Terraform.

> **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md) for git workflow and branching strategy.

**Key docs** (repo root stays minimal): [docs/NETWORK.md](docs/NETWORK.md) · [docs/VAULT.md](docs/VAULT.md) · [docs/SERVICES_REFERENCE.md](docs/SERVICES_REFERENCE.md) · [docs/ELDERTREE.md](docs/ELDERTREE.md) · published runbook [docs.eldertree.xyz](https://docs.eldertree.xyz)

## Hardware

- Raspberry Pi 5 (8GB, ARM64)
- Debian 12 Bookworm
- Physical tower (CAD / BOM): [**eldertree-chassis**](https://github.com/raolivei/eldertree-chassis) — [docs/HARDWARE_CHASSIS.md](docs/HARDWARE_CHASSIS.md)
- **Project hub:** [docs/ELDERTREE.md](docs/ELDERTREE.md) · Grafana [ops home](https://grafana.eldertree.local/d/eldertree-ops-home) · `./scripts/operations/eldertree-open.sh`

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
2. **Ansible** - k3s cluster installation
3. **Ansible** - FluxCD GitOps bootstrap (optional)

The script is idempotent and can be run multiple times safely.

### Manual Setup

For manual control:

```bash
# 1. System configuration and k3s installation (Ansible)
cd ansible
ansible-playbook playbooks/setup-eldertree.yml --ask-pass --ask-become-pass

# Or run separately:
ansible-playbook playbooks/setup-system.yml --ask-pass --ask-become-pass
ansible-playbook playbooks/install-k3s.yml --ask-pass --ask-become-pass

# 2. Bootstrap FluxCD (Ansible, optional)
ansible-playbook playbooks/bootstrap-flux.yml -e bootstrap_flux=true

# Use cluster
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
```

## Tool Selection

This project uses a hybrid approach with clear separation of concerns:

- **Ansible**: System configuration and operational tasks

  - User management, hostname, network configuration
  - Package installation
  - k3s cluster installation
  - FluxCD GitOps bootstrap
  - DNS configuration (local /etc/hosts)
  - Secret management (Vault operations)
  - Idempotent configuration management

- **Terraform**: Infrastructure provisioning

  - Cloudflare DNS records (A, CNAME)
  - Cloudflare Tunnel creation and configuration
  - Infrastructure state management
  - **Note**: TLS certificates are managed by cert-manager via Helm, not Terraform

- **Helm**: Kubernetes application deployment
  - Custom Helm charts for cluster components
  - cert-manager issuers (TLS certificate management)
  - Monitoring stack (Prometheus + Grafana)
  - KEDA scaled objects
  - Application configuration via values.yaml

See [ansible/README.md](ansible/README.md) for Ansible playbook documentation.

## Structure

```
ansible/           # Ansible playbooks (system configuration, k3s installation, FluxCD bootstrap)
terraform/         # Infrastructure as code (Cloudflare DNS/Tunnel)
clusters/eldertree/     # FluxCD manifests (GitOps)
helm/              # Custom Helm charts
scripts/           # Helper scripts (setup-eldertree.sh, etc.)
```

## Documentation

- **Synthetic / Blackbox HTTP monitoring (why and how on Eldertree):** [docs/OBSERVABILITY_BLACKBOX_AND_SYNTHETIC.md](docs/OBSERVABILITY_BLACKBOX_AND_SYNTHETIC.md)
- **Retention & NVMe sizing (90d metrics, 30d logs):** [docs/OBSERVABILITY_RETENTION.md](docs/OBSERVABILITY_RETENTION.md)
- **Control Center (live topology + health):** [docs/CONTROL_CENTER.md](docs/CONTROL_CENTER.md)
- **New app routing (LAN end-to-end):** [docs/ONBOARDING_APP_ROUTING.md](docs/ONBOARDING_APP_ROUTING.md)
- **Grafana dashboard inventory and PromQL source of truth:** [helm/monitoring-stack/DASHBOARDS.md](helm/monitoring-stack/DASHBOARDS.md)

## Helm Charts

Custom charts for cluster components (Helm v4 compatible):

- **cert-manager-issuers**: ClusterIssuers (self-signed, ACME)
- **monitoring-stack**: Prometheus + Grafana

See [helm/README.md](helm/README.md) for details.

## Cluster Status

**Current State:**

- 3-node HA K3s cluster (node-1, node-2, node-3)
- K3s v1.33.6+k3s1 / v1.34.3+k3s1
- Flux GitOps, cert-manager, Pi-hole DNS
- Monitoring: Prometheus + Grafana
- Storage: Longhorn (distributed)
- Secrets: HashiCorp Vault (HA)

**Deployed Applications:**

- Grafana: https://grafana.eldertree.local (admin/admin)
- Prometheus: https://prometheus.eldertree.local
- Canopy: https://canopy.eldertree.local
- Pi-hole: https://pihole.eldertree.local

See [docs/NETWORK.md](docs/NETWORK.md) for DNS setup.

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

- Secrets are stored in Vault. See [docs/VAULT.md](docs/VAULT.md).
- To manage passwords for scripts and Ansible, see [PASSWORD_MANAGEMENT.md](docs/PASSWORD_MANAGEMENT.md).

```bash
./scripts/operations/sync-vault-to-k8s.sh
```

## Add Worker Nodes

```bash
# Get token (saved by Ansible install-k3s.yml playbook)
cat ansible/k3s-node-token

# On worker node (fleet-worker-01, fleet-worker-02, etc.)
curl -sfL https://get.k3s.io | K3S_URL=https://eldertree:6443 K3S_TOKEN=<token> sh -
```

## Validation

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Basic cluster validation
kubectl get nodes
kubectl get pods -A
kubectl get helmreleases -A

# Validate ingress setup
./scripts/diagnostics/validate-ingress-setup.sh
```

## Cleanup

```bash
terraform destroy
```
