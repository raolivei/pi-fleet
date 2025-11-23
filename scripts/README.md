# Scripts

Helper scripts for managing pi-fleet and workspace infrastructure, organized by category.

## Organization

Scripts are organized into subdirectories:

- **`setup/`** - Initial setup and configuration scripts
- **`operations/`** - Day-to-day operational tasks (backups, restores, deployments)
- **`secrets/`** - Secret management (Cloudflare tokens, certificates)
- **`diagnostics/`** - Health checks and troubleshooting tools
- **`utils/`** - Utility scripts and helpers

## Setup Scripts

### setup/setup-eldertree.sh

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
./scripts/setup/setup-eldertree.sh
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

### setup/setup-dns.sh

Setup DNS for \*.eldertree.local domains (Pi-hole or /etc/hosts).

```bash
./scripts/setup/setup-dns.sh
```

### setup/setup-direnv.sh

Setup direnv for the workspace with automatic Python virtual environment activation.

```bash
./scripts/setup/setup-direnv.sh
```

### setup/setup-github-secrets.sh

Setup GitHub Secrets for Terraform workflow. Supports both interactive and non-interactive modes.

**Interactive mode**:
```bash
./scripts/setup/setup-github-secrets.sh
```

**Non-interactive mode**:
```bash
CLOUDFLARE_API_TOKEN='your-token' ./scripts/setup/setup-github-secrets.sh
# OR
./scripts/setup/setup-github-secrets.sh your-api-token-here
```

### setup/setup-backup-cron.sh

Setup automated backup cron jobs.

```bash
./scripts/setup/setup-backup-cron.sh
```

## Operations Scripts

### operations/sync-vault-to-k8s.sh

Sync secrets from Vault to Kubernetes secrets.

```bash
./scripts/operations/sync-vault-to-k8s.sh
```

### operations/backup-all.sh

Comprehensive backup script for eldertree cluster. Backs up PostgreSQL databases, Vault secrets, Kubernetes configs, and PVCs.

```bash
./scripts/operations/backup-all.sh [backup-dir]
```

### operations/backup-vault-secrets.sh

Backup all Vault secrets to JSON file.

```bash
./scripts/operations/backup-vault-secrets.sh > vault-backup-$(date +%Y%m%d).json
```

### operations/restore-all.sh

Restore cluster from backup directory.

```bash
./scripts/operations/restore-all.sh <backup-directory>
```

### operations/restore-vault-secrets.sh

Restore Vault secrets from backup JSON file.

```bash
./scripts/operations/restore-vault-secrets.sh vault-backup-20250115.json
```

### operations/unseal-vault.sh

Unseal Vault using the 3 unseal keys.

```bash
./scripts/operations/unseal-vault.sh
```

### operations/deploy-all-images.sh

Build and deploy all project images to pi-fleet cluster.

```bash
./scripts/operations/deploy-all-images.sh
```

### operations/trigger-all-workflows.sh

Trigger GitHub Actions workflows across all repositories.

```bash
./scripts/operations/trigger-all-workflows.sh
```

## Secrets Scripts

### secrets/get-cloudflare-token.sh

Get Cloudflare API token from Vault for Terraform use.

```bash
source ./scripts/secrets/get-cloudflare-token.sh
# OR
export TF_VAR_cloudflare_api_token=$(./scripts/secrets/get-cloudflare-token.sh)
```

### secrets/store-cloudflare-token.sh

Store Cloudflare API token in Vault for Terraform and External-DNS.

```bash
./scripts/secrets/store-cloudflare-token.sh YOUR_API_TOKEN_HERE
# OR
./scripts/secrets/store-cloudflare-token.sh  # Will prompt for token
```

### secrets/store-cloudflare-origin-cert.sh

Store Cloudflare Origin Certificate in Vault.

```bash
./scripts/secrets/store-cloudflare-origin-cert.sh <certificate-file> <private-key-file> [namespace]
```

## Diagnostics Scripts

### diagnostics/validate-ingress-setup.sh

Validate that ingress setup is correct (Traefik, Cert-Manager, ExternalDNS).

```bash
./scripts/diagnostics/validate-ingress-setup.sh
```

### diagnostics/check-keda.sh

Check KEDA installation and status.

```bash
./scripts/diagnostics/check-keda.sh
```

### diagnostics/check-wireguard-server.sh

Check WireGuard server status and configuration.

```bash
./scripts/diagnostics/check-wireguard-server.sh
```

### diagnostics/diagnose-wireguard.sh

Diagnose WireGuard connection issues.

```bash
./scripts/diagnostics/diagnose-wireguard.sh
```

### diagnostics/test-vpc-dns.sh

Test VPC DNS resolution.

```bash
./scripts/diagnostics/test-vpc-dns.sh [hostname]
```

## Utility Scripts

### utils/new-project.sh

Create a new project with standard structure and conventions.

```bash
./scripts/utils/new-project.sh <project-name>
```

### utils/list-and-open-services.sh

List all services and open them in browser.

```bash
./scripts/utils/list-and-open-services.sh
```

### utils/install-glances.sh

Install Glances system monitoring tool.

```bash
./scripts/utils/install-glances.sh
```

### utils/update-hosts.sh

Update /etc/hosts file with cluster services.

```bash
./scripts/utils/update-hosts.sh
```

## Adding Secrets to Vault

```bash
kubectl exec -n vault vault-0 -- vault kv put secret/path key=value
```
