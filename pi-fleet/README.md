# Pi Fleet

K3s cluster on Raspberry Pi, managed with Terraform.

> **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md) for git workflow and branching strategy.

## Hardware

- Raspberry Pi 5 (8GB, ARM64)
- Debian 12 Bookworm

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
terraform/         # Infrastructure as code
clusters/core/     # Cluster manifests
```

## Add Worker Nodes

```bash
# Get token
cat terraform/k3s-node-token

# On worker node (fleet-worker-01, fleet-worker-02, etc.)
curl -sfL https://get.k3s.io | K3S_URL=https://eldertree:6443 K3S_TOKEN=<token> sh -
```

## Cleanup

```bash
terraform destroy
```
