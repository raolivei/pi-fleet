# Scripts

Helper scripts for managing pi-fleet and workspace infrastructure.

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
