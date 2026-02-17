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
    echo "   cd $SCRIPT_DIR/.. && ./scripts/operations/unseal-vault.sh"
    exit 1
fi

# Get Cloudflare API token from Vault (optional - Cloudflare resources are optional)
export TF_VAR_cloudflare_api_token=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=api-token secret/pi-fleet/terraform/cloudflare-api-token 2>/dev/null || echo "")

if [ -z "$TF_VAR_cloudflare_api_token" ]; then
    echo "⚠️  Cloudflare API token not found in Vault"
    echo "   Cloudflare resources will be skipped (tunnel, DNS records)"
    
    # Check if Cloudflare resources exist in state
    CLOUDFLARE_RESOURCES=$(terraform state list 2>/dev/null | grep -E "cloudflare|data.cloudflare" || echo "")
    
    if [ -n "$CLOUDFLARE_RESOURCES" ]; then
        echo ""
        echo "⚠️  WARNING: Cloudflare resources exist in Terraform state but token is missing"
        echo "   Using -refresh=false to skip refreshing Cloudflare resources (avoids auth errors)"
        echo "   Cloudflare resources will be removed from state on next apply."
        echo ""
        CLOUDFLARE_TOKEN_MISSING=true
    fi
    
    echo "   To enable Cloudflare:"
    echo "     1. Store token: kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token='YOUR_TOKEN'"
    echo "     2. Re-run: $0 $@"
    echo ""
    export TF_VAR_cloudflare_api_token=""
else
    echo "✅ Cloudflare API token loaded from Vault"
fi

# Get Cloudflare Origin CA Key from Vault (required for Origin CA certificates)
export TF_VAR_cloudflare_origin_ca_key=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=origin-ca-key secret/pi-fleet/terraform/cloudflare-origin-ca-key 2>/dev/null || echo "")

if [ -z "$TF_VAR_cloudflare_origin_ca_key" ]; then
    echo "⚠️  Cloudflare Origin CA Key not found in Vault"
    echo "   Origin CA certificate resources will be skipped"
    export TF_VAR_cloudflare_origin_ca_key=""
else
    echo "✅ Cloudflare Origin CA Key loaded from Vault"
fi

# Get pi_user from Vault (optional, falls back to default "pi")
export TF_VAR_pi_user=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=pi-user secret/pi-fleet/terraform/pi-user 2>/dev/null || echo "")
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

