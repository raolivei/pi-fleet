# Pi Fleet

K3s cluster on Raspberry Pi, managed with Ansible and Terraform.

> **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md) for git workflow and branching strategy.

## Hardware

- Raspberry Pi 5 (8GB, ARM64)
- Debian 12 Bookworm

## Fleet Naming

**Control Plane:**

- **eldertree** - Main control plane node (192.168.2.83)

**Worker Nodes:**

- **fleet-worker-01**, **fleet-worker-02**, etc. (future)

## Quick Start

### Automated Setup (Recommended)

Use the automated setup script for complete cluster setup:

```bash
# Install prerequisites
brew install ansible terraform kubectl fluxcd/tap/flux hudochenkov/sshpass/sshpass

# Run automated setup
./scripts/setup-eldertree.sh
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

## Helm Charts

Custom charts for cluster components (Helm v4 compatible):

- **cert-manager-issuers**: ClusterIssuers (self-signed, ACME)
- **monitoring-stack**: Prometheus + Grafana

See [helm/README.md](helm/README.md) for details.

## Cluster Status

**Current State:**

- Single-node K3s cluster (eldertree)
- K3s v1.33.5+k3s1, Helm v4.0.0
- Flux GitOps, cert-manager, Pi-hole DNS
- Monitoring: Prometheus + Grafana
- Storage: local-path-provisioner

**Deployed Applications:**

- Grafana: https://grafana.eldertree.local (admin/admin)
- Prometheus: https://prometheus.eldertree.local
- Canopy: https://canopy.eldertree.local
- Pi-hole: https://pihole.eldertree.local

See [NETWORK.md](NETWORK.md) for DNS setup.

## Ingress and SSL Certificates

The cluster uses Traefik as the Ingress Controller (pre-installed with k3s), Cert-Manager for automatic SSL/TLS certificate management, and ExternalDNS for automatic DNS record creation.

**Quick Start:**

```bash
# Validate ingress setup
./scripts/validate-ingress-setup.sh

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

## Secrets

Secrets stored in Vault. See [VAULT.md](VAULT.md).

```bash
./scripts/sync-vault-to-k8s.sh
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
./scripts/validate-ingress-setup.sh
```

## Cleanup

```bash
terraform destroy
```
