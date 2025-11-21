# Scripts

Helper scripts for managing pi-fleet and workspace infrastructure.

## Setup Scripts

### setup-eldertree.sh

Complete automated setup script for the eldertree Raspberry Pi cluster. This script orchestrates both Ansible (system configuration) and Terraform (k3s infrastructure) to set up the cluster.

**Features**:
- Idempotent (can be run multiple times safely)
- Checks if k3s is already installed before running Terraform
- Verifies each step before proceeding
- Optional FluxCD GitOps bootstrap
- Comprehensive error handling and troubleshooting tips

**Usage**:

```bash
cd pi-fleet
./scripts/setup-eldertree.sh
```

**What it does**:
1. Checks prerequisites (ansible, kubectl, flux CLI)
2. Prompts for Pi IP address and SSH credentials
3. Updates Ansible inventory
4. Runs Ansible system configuration (`setup-system.yml`)
5. Checks if k3s is already installed (idempotency)
6. Runs Ansible to install k3s (if needed)
7. Verifies cluster is ready
8. Optionally bootstraps FluxCD GitOps via Ansible

**Tool Selection**:
- **Ansible**: Used for system configuration, k3s installation, and operational tasks (user setup, hostname, network, FluxCD bootstrap)
- **Terraform**: Used for infrastructure provisioning (Cloudflare DNS/Tunnel only)

**Prerequisites**:
- Ansible installed (`brew install ansible`)
- kubectl installed (`brew install kubectl`)
- Flux CLI installed (`brew install fluxcd/tap/flux`)
- sshpass installed (`brew install hudochenkov/sshpass/sshpass`)

**Troubleshooting**:
- If Ansible fails: Check SSH connectivity and credentials
- If k3s installation fails: Check verbose output: `ansible-playbook playbooks/install-k3s.yml -vvv`
- If k3s not ready: Check k3s service on Pi: `ssh pi@<IP> 'sudo systemctl status k3s'`
- If FluxCD bootstrap fails: Ensure GitHub token is configured

## Infrastructure Scripts

### sync-vault-to-k8s.sh

Sync secrets from Vault to Kubernetes secrets.

```bash
./scripts/sync-vault-to-k8s.sh
```

### setup-dns.sh

Setup DNS for \*.eldertree.local domains (Pi-hole or /etc/hosts).

```bash
./scripts/setup-dns.sh
```

### load-images-manual.sh

Load Docker images into k3s from tar.gz files. Run on the cluster node.

```bash
./scripts/load-images-manual.sh
```

### transfer-images.sh

Transfer Docker images to cluster node and load into k3s.

```bash
./scripts/transfer-images.sh
```

### trigger-all-workflows.sh

Trigger GitHub Actions workflows across all repositories.

```bash
./scripts/trigger-all-workflows.sh
```

## Development Scripts

### setup-direnv.sh

Setup direnv for the workspace with automatic Python virtual environment activation.

```bash
./scripts/setup-direnv.sh
```

### test-direnv-setup.sh

Test that direnv is configured correctly.

```bash
./scripts/test-direnv-setup.sh
```

### new-project.sh

Create a new project with standard structure and conventions.

```bash
./scripts/new-project.sh <project-name>
```

## Adding Secrets to Vault

```bash
kubectl exec -n vault vault-0 -- vault kv put secret/path key=value
```
