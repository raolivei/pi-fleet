#!/bin/bash
# Store Cloudflare API token in Vault for Terraform and External-DNS
#
# Usage:
#   ./scripts/store-cloudflare-token.sh YOUR_API_TOKEN_HERE
#   OR
#   ./scripts/store-cloudflare-token.sh  # Will prompt for token

set -e

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

# Get API token from argument or prompt
if [ -z "$1" ]; then
    echo "Enter your Cloudflare API token (will not be displayed):"
    read -s CLOUDFLARE_API_TOKEN
else
    CLOUDFLARE_API_TOKEN="$1"
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "Error: Cloudflare API token is required"
    exit 1
fi

# Get Vault pod
echo "Getting Vault pod..."
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

if [ -z "$VAULT_POD" ]; then
    echo "Error: Vault pod not found"
    exit 1
fi

# Check if Vault is unsealed
echo "Checking Vault status..."
VAULT_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status 2>&1 | grep "Sealed" | awk '{print $2}')

if [ "$VAULT_STATUS" = "true" ]; then
    echo "Error: Vault is sealed. Please unseal it first:"
    echo "  ./scripts/unseal-vault.sh"
    exit 1
fi

# Store token for Terraform use
echo "Storing Cloudflare API token for Terraform..."
kubectl exec -n vault $VAULT_POD -- vault kv put secret/terraform/cloudflare-api-token api-token="$CLOUDFLARE_API_TOKEN"

# Store token for External-DNS use
echo "Storing Cloudflare API token for External-DNS..."
kubectl exec -n vault $VAULT_POD -- vault kv put secret/external-dns/cloudflare-api-token api-token="$CLOUDFLARE_API_TOKEN"

echo ""
echo "✅ Cloudflare API token stored successfully in Vault!"
echo ""
echo "Vault paths:"
echo "  - secret/terraform/cloudflare-api-token"
echo "  - secret/external-dns/cloudflare-api-token"
echo ""
echo "External Secrets Operator will sync these to Kubernetes automatically."

