#!/bin/bash
# Store Cloudflare API token in Vault
# Usage: ./store-cloudflare-token.sh [token]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

# Get token from argument or prompt
if [ -n "$1" ]; then
    CLOUDFLARE_TOKEN="$1"
else
    echo "Enter Cloudflare API token:"
    read -s CLOUDFLARE_TOKEN
fi

if [ -z "$CLOUDFLARE_TOKEN" ]; then
    echo "❌ Error: Cloudflare API token is required"
    exit 1
fi

# Get Vault pod
echo "🔐 Connecting to Vault..."
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
    echo "   cd $SCRIPT_DIR/../.. && ./scripts/unseal-vault.sh"
    exit 1
fi

# Store token for Terraform
echo "📦 Storing Cloudflare API token in Vault..."
kubectl exec -n vault $VAULT_POD -- vault kv put secret/terraform/cloudflare-api-token api-token="$CLOUDFLARE_TOKEN"

# Store token for External-DNS (same token)
echo "📦 Storing Cloudflare API token for External-DNS..."
kubectl exec -n vault $VAULT_POD -- vault kv put secret/external-dns/cloudflare-api-token api-token="$CLOUDFLARE_TOKEN"

echo "✅ Cloudflare API token stored successfully!"
echo ""
echo "You can now run Terraform:"
echo "  cd terraform && ./run-terraform.sh plan"

