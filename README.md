# Pi Fleet

K3s cluster on Raspberry Pi, managed with Terraform.

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

```bash
# Install sshpass
brew install hudochenkov/sshpass/sshpass

# Configure
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your credentials

# Deploy
terraform init
terraform apply

# Use cluster
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
```

## Structure

```
terraform/         # Infrastructure as code (K3s setup)
clusters/eldertree/     # FluxCD manifests (GitOps)
helm/              # Custom Helm charts
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

## Secrets

Secrets stored in Vault. See [VAULT.md](VAULT.md).

```bash
./scripts/sync-vault-to-k8s.sh
```

## Add Worker Nodes

```bash
# Get token
cat terraform/k3s-node-token

# On worker node (fleet-worker-01, fleet-worker-02, etc.)
curl -sfL https://get.k3s.io | K3S_URL=https://eldertree:6443 K3S_TOKEN=<token> sh -
```

## Validation

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
kubectl get pods -A
kubectl get helmreleases -A
```

## Cleanup

```bash
terraform destroy
```
