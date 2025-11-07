# Terraform K3s Setup

Automates k3s control plane installation on Raspberry Pi.

## Cluster Name

The cluster is named **eldertree** (matching the control plane hostname). Kubeconfig contexts are automatically configured with this name.

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
kubectl config use-context eldertree
kubectl get nodes
```

## Update Existing Kubeconfig

If you have an existing kubeconfig with default names:

```bash
./update-kubeconfig.sh ~/.kube/config-eldertree
```

## Cleanup

```bash
terraform destroy
```
