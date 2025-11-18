#!/bin/bash
# Get Cloudflare API token from Vault for Terraform use
#
# Usage:
#   source ./scripts/get-cloudflare-token.sh
#   OR
#   export TF_VAR_cloudflare_api_token=$(./scripts/get-cloudflare-token.sh)

set -e

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

# Get Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

if [ -z "$VAULT_POD" ]; then
    echo "Error: Vault pod not found" >&2
    exit 1
fi

# Check if Vault is unsealed
VAULT_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status 2>&1 | grep "Sealed" | awk '{print $2}')

if [ "$VAULT_STATUS" = "true" ]; then
    echo "Error: Vault is sealed. Please unseal it first:" >&2
    echo "  ./scripts/unseal-vault.sh" >&2
    exit 1
fi

# Get token from Vault
TOKEN=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=api-token secret/terraform/cloudflare-api-token 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "Error: Could not retrieve Cloudflare API token from Vault" >&2
    exit 1
fi

# Output token (for use with export or command substitution)
echo "$TOKEN"

