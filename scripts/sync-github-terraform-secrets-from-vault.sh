#!/usr/bin/env bash
# Sync Terraform workflow secrets from Vault to GitHub (Actions + Dependabot).
#
# Vault paths (KV v2):
#   secret/pi-fleet/terraform/cloudflare-api-token     -> api-token
#   secret/pi-fleet/terraform/cloudflare-origin-ca-key -> origin-ca-key
#   secret/pi-fleet/terraform/terraform-cloud-token    -> token  (optional; not always in Vault)
#
# Usage:
#   ./scripts/sync-github-terraform-secrets-from-vault.sh
#   ./scripts/sync-github-terraform-secrets-from-vault.sh --app dependabot
#   ./scripts/sync-github-terraform-secrets-from-vault.sh --app actions --app dependabot
#
# TF_API_TOKEN: read from Vault when present; else skip (Actions may already have it).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$REPO_DIR/terraform"

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

APPS=(actions)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APPS=()
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do
        APPS+=("$1")
        shift
      done
      ;;
    -h|--help)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI required" >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh auth login required" >&2
  exit 1
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')
if [[ -z "$VAULT_POD" ]]; then
  echo "Error: no running Vault pod" >&2
  exit 1
fi

if kubectl exec -n vault "$VAULT_POD" -- vault status -format=json 2>/dev/null | grep -q '"sealed":true'; then
  echo "Error: Vault is sealed. Run: ./scripts/operations/unseal-vault.sh" >&2
  exit 1
fi

VAULT_TOKEN=$(kubectl get secret vault-token -n external-secrets -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)
if [[ -z "$VAULT_TOKEN" ]]; then
  echo "Error: secret/external-secrets/vault-token not found" >&2
  exit 1
fi

vault_field() {
  local path="$1" field="$2"
  kubectl exec -n vault "$VAULT_POD" -- \
    env VAULT_ADDR=http://127.0.0.1:8200 "VAULT_TOKEN=${VAULT_TOKEN}" \
    vault kv get "-field=${field}" "$path" 2>/dev/null || true
}

set_gh_secret() {
  local name="$1" value="$2" app="$3"
  if [[ -z "$value" ]]; then
    echo "  skip $name ($app): empty"
    return 0
  fi
  printf '%s' "$value" | gh secret set "$name" --repo "$REPO" --app "$app"
  echo "  set $name ($app)"
}

echo "Repository: $REPO"
echo "Vault pod: $VAULT_POD"
echo "Targets: ${APPS[*]}"
echo ""

CF_API=$(vault_field secret/pi-fleet/terraform/cloudflare-api-token api-token)
CF_ORIGIN=$(vault_field secret/pi-fleet/terraform/cloudflare-origin-ca-key origin-ca-key)
TF_CLOUD=$(vault_field secret/pi-fleet/terraform/terraform-cloud-token token)
PI_USER_VAL=$(vault_field secret/pi-fleet/terraform/pi-user pi-user)

CLOUDFLARE_ZONE_ID=""
CLOUDFLARE_ACCOUNT_ID=""
PUBLIC_IP=""
if [[ -f "$TERRAFORM_DIR/terraform.tfvars" ]]; then
  CLOUDFLARE_ZONE_ID=$(grep '^cloudflare_zone_id' "$TERRAFORM_DIR/terraform.tfvars" 2>/dev/null | sed -n 's/.*= *"\([^"]*\)".*/\1/p' | head -1 || true)
  CLOUDFLARE_ACCOUNT_ID=$(grep '^cloudflare_account_id' "$TERRAFORM_DIR/terraform.tfvars" 2>/dev/null | sed -n 's/.*= *"\([^"]*\)".*/\1/p' | head -1 || true)
  PUBLIC_IP=$(grep '^public_ip' "$TERRAFORM_DIR/terraform.tfvars" 2>/dev/null | sed -n 's/.*= *"\([^"]*\)".*/\1/p' | head -1 || true)
fi

if [[ -z "$TF_CLOUD" ]]; then
  TF_CLOUD="${TF_API_TOKEN:-${TF_TOKEN_app_terraform_io:-}}"
fi

# Optional: persist Terraform Cloud token in Vault when provided via env
if [[ -n "$TF_CLOUD" ]]; then
  kubectl exec -n vault "$VAULT_POD" -- \
    env VAULT_ADDR=http://127.0.0.1:8200 "VAULT_TOKEN=${VAULT_TOKEN}" \
    vault kv put secret/pi-fleet/terraform/terraform-cloud-token token="${TF_CLOUD}" >/dev/null 2>&1 \
    && echo "Stored TF token in Vault (secret/pi-fleet/terraform/terraform-cloud-token)" || true
fi

if [[ -z "$CF_API" ]]; then
  echo "Error: secret/pi-fleet/terraform/cloudflare-api-token not in Vault" >&2
  exit 1
fi

for app in "${APPS[@]}"; do
  echo "Syncing ($app)..."
  set_gh_secret CLOUDFLARE_API_TOKEN "$CF_API" "$app"
  set_gh_secret CLOUDFLARE_ORIGIN_CA_KEY "$CF_ORIGIN" "$app"
  set_gh_secret TF_API_TOKEN "$TF_CLOUD" "$app"
  set_gh_secret CLOUDFLARE_ZONE_ID "$CLOUDFLARE_ZONE_ID" "$app"
  set_gh_secret CLOUDFLARE_ACCOUNT_ID "$CLOUDFLARE_ACCOUNT_ID" "$app"
  set_gh_secret PUBLIC_IP "$PUBLIC_IP" "$app"
  set_gh_secret PI_USER "$PI_USER_VAL" "$app"
  echo ""
done

if [[ -z "$TF_CLOUD" ]]; then
  echo "Note: TF_API_TOKEN not in Vault (secret/pi-fleet/terraform/terraform-cloud-token)."
  echo "      Export TF_API_TOKEN (or TF_TOKEN_app_terraform_io) and re-run this script to sync + store in Vault."
  echo "      GitHub Actions already has TF_API_TOKEN; Dependabot needs a separate copy:"
  echo "        TF_API_TOKEN='…' $0 --app dependabot"
else
  echo "TF_API_TOKEN synced from Vault."
fi

echo "Done."
