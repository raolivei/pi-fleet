# Terraform K3s Setup

Automates k3s control plane installation on Raspberry Pi.

## What It Does

1. Verifies system and installs prerequisites
2. Installs k3s with `--cluster-init` (HA-ready)
3. Downloads kubeconfig locally
4. Saves node token for workers

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars

terraform init
terraform plan
terraform apply
```

## Post-Install

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
```

## Cleanup

```bash
terraform destroy
```
