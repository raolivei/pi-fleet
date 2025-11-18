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
cd "$SCRIPT_DIR"

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

# Get Cloudflare API token from Vault
echo "🔐 Loading Cloudflare API token from Vault..."
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$VAULT_POD" ]; then
    echo "❌ Error: Vault pod not found"
    echo "   Make sure Vault is running: kubectl get pods -n vault"
    exit 1
fi

# Check if Vault is unsealed
VAULT_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status 2>&1 | grep "Sealed" | awk '{print $2}' || echo "true")

if [ "$VAULT_STATUS" = "true" ]; then
    echo "❌ Error: Vault is sealed. Please unseal it first:"
    echo "   cd $SCRIPT_DIR/.. && ./scripts/unseal-vault.sh"
    exit 1
fi

# Get token from Vault
export TF_VAR_cloudflare_api_token=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=api-token secret/terraform/cloudflare-api-token 2>/dev/null || echo "")

if [ -z "$TF_VAR_cloudflare_api_token" ]; then
    echo "❌ Error: Could not retrieve Cloudflare API token from Vault"
    echo "   Make sure the token is stored: kubectl exec -n vault $VAULT_POD -- vault kv get secret/terraform/cloudflare-api-token"
    exit 1
fi

echo "✅ Cloudflare API token loaded from Vault"

# Get pi_user from Vault (optional, falls back to default "pi")
export TF_VAR_pi_user=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=pi-user secret/terraform/pi-user 2>/dev/null || echo "")
if [ -n "$TF_VAR_pi_user" ]; then
    echo "✅ Pi username loaded from Vault"
else
    echo "ℹ️  Pi username not found in Vault, will use default or terraform.tfvars"
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

terraform "$@"

