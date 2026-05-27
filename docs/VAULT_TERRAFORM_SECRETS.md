# Terraform secrets in Vault

Vault is the **source of truth** for Terraform and HCP Terraform credentials. Applications read from Vault; GitHub Actions and Dependabot use **synced copies** in repository secrets.

## Paths (KV v2)

| Vault path | Key | Used for |
|------------|-----|----------|
| `secret/pi-fleet/terraform/terraform-cloud-token` | `token` | HCP Terraform (`TF_TOKEN_app_terraform_io` / `TF_API_TOKEN`) |
| `secret/pi-fleet/terraform/cloudflare-api-token` | `api-token` | Cloudflare provider |
| `secret/pi-fleet/terraform/cloudflare-origin-ca-key` | `origin-ca-key` | Origin CA certificates |
| `secret/pi-fleet/terraform/pi-user` | `pi-user` | Optional SSH user for k3s resources |

## Who reads Vault directly

| Consumer | How |
|----------|-----|
| **Local Terraform** | `./terraform/run-terraform.sh` or `source scripts/lib/load-terraform-secrets-from-vault.sh` |
| **Scripts** | `./scripts/get-vault-secret.sh secret/pi-fleet/terraform/...` |
| **Kubernetes** | ExternalSecret `pi-fleet-terraform-vault-credentials` in `external-secrets` namespace |
| **External-DNS** | Separate path `secret/pi-fleet/external-dns/cloudflare-api-token` (may match terraform token) |

## GitHub Actions and Dependabot

Runners on `ubuntu-latest` **cannot** reach `https://vault.eldertree.local`. After any Vault change:

```bash
./scripts/sync-github-terraform-secrets-from-vault.sh --app actions --app dependabot
```

Requires `kubectl` + unsealed Vault + `gh auth login`.

## Bootstrap a new HCP token

You cannot read an existing token back from HCP or GitHub. Create a new user token at [app.terraform.io/app/settings/tokens](https://app.terraform.io/app/settings/tokens), then:

```bash
./scripts/setup-terraform-cloud-token.sh --sync-github
```

That stores in Vault, updates `~/.terraform.d/credentials.tfrc.json`, and publishes to GitHub.

## Verify

```bash
./scripts/lib/load-terraform-secrets-from-vault.sh
cd terraform && ./run-terraform.sh plan
```
