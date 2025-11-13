# Scripts

Helper scripts for managing pi-fleet.

## sync-vault-to-k8s.sh

Sync secrets from Vault to Kubernetes secrets.

```bash
./scripts/sync-vault-to-k8s.sh
```

## setup-dns.sh

Setup DNS for *.eldertree.local domains (Pi-hole or /etc/hosts).

```bash
./scripts/setup-dns.sh
```

## Adding Secrets to Vault

```bash
kubectl exec -n vault vault-0 -- vault kv put secret/path key=value
```
