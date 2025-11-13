# Scripts

Helper scripts for managing pi-fleet.

## populate-vault-secrets.sh

Populate Vault with project secrets (interactive).

```bash
./scripts/populate-vault-secrets.sh
```

## migrate-all-secrets-to-vault.sh

Migrate all existing Kubernetes secrets to Vault automatically.

```bash
./scripts/migrate-all-secrets-to-vault.sh
```

## sync-vault-to-k8s.sh

Sync secrets from Vault to Kubernetes secrets.

```bash
./scripts/sync-vault-to-k8s.sh
```

