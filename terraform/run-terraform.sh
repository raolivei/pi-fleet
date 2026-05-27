#!/bin/bash
# Run Terraform with Cloudflare API token loaded from Vault
#
# Usage:
#   ./run-terraform.sh [terraform-command] [args...]
#
# Examples:
#   ./run-terraform.sh plan
#   ./run-terraform.sh apply
#   ./run-terraform.sh plan -out=tfplan

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SCRIPT_DIR"

# shellcheck source=../scripts/lib/load-terraform-secrets-from-vault.sh
source "${REPO_DIR}/scripts/lib/load-terraform-secrets-from-vault.sh"

echo "🔐 Loading Terraform secrets from Vault..."
if ! kubectl get pods -n vault -l app.kubernetes.io/name=vault --field-selector=status.phase=Running -o name 2>/dev/null | grep -q .; then
    echo "❌ Error: no running Vault pod (kubectl get pods -n vault)"
    exit 1
fi

load_terraform_secrets_from_vault

CLOUDFLARE_TOKEN_MISSING=false
if [ -z "${TF_VAR_cloudflare_api_token:-}" ]; then
    echo "⚠️  Cloudflare API token not in Vault (secret/pi-fleet/terraform/cloudflare-api-token)"
    CLOUDFLARE_RESOURCES=$(terraform state list 2>/dev/null | grep -E "cloudflare|data.cloudflare" || echo "")
    if [ -n "$CLOUDFLARE_RESOURCES" ]; then
        echo "⚠️  Cloudflare resources in state — plan/apply will use -refresh=false"
        CLOUDFLARE_TOKEN_MISSING=true
    fi
else
    echo "✅ Cloudflare API token"
fi

if [ -z "${TF_VAR_cloudflare_origin_ca_key:-}" ]; then
    echo "⚠️  Cloudflare Origin CA key not in Vault"
else
    echo "✅ Cloudflare Origin CA key"
fi

if [ -z "${TF_TOKEN_app_terraform_io:-}" ]; then
    echo "❌ HCP Terraform token not in Vault (secret/pi-fleet/terraform/eldertree-github-2026)"
    echo "   Run: ${REPO_DIR}/scripts/setup-terraform-cloud-token.sh"
    exit 1
else
    echo "✅ HCP Terraform token (TF_TOKEN_app_terraform_io)"
fi

if [ -n "${TF_VAR_pi_user:-}" ]; then
    echo "✅ Pi username"
fi
echo ""

# Run terraform with all arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 [terraform-command] [args...]"
    echo "Examples:"
    echo "  $0 plan"
    echo "  $0 apply"
    echo "  $0 plan -out=tfplan"
    exit 1
fi

# Run terraform
# If Cloudflare token is missing but resources exist in state, use -refresh=false
# to avoid authentication errors when Terraform tries to refresh them
if [ "${CLOUDFLARE_TOKEN_MISSING:-false}" = "true" ] && [ "$1" = "plan" ]; then
    echo "ℹ️  Running terraform plan with -refresh=false (Cloudflare token not provided)"
    terraform plan -refresh=false "${@:2}"
elif [ "${CLOUDFLARE_TOKEN_MISSING:-false}" = "true" ] && [ "$1" = "apply" ]; then
    echo "ℹ️  Running terraform apply with -refresh=false (Cloudflare token not provided)"
    terraform apply -refresh=false "${@:2}"
else
    # Normal execution
    terraform "$@"
fi

