#!/bin/bash
# Get Cloudflare Zone ID for pitanga.cloud
#
# This script retrieves the Zone ID for pitanga.cloud from Cloudflare API
# using the API token stored in Vault.

set -e

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
VAULT_NAMESPACE="vault"
DOMAIN="pitanga.cloud"

echo "🔍 Getting Cloudflare Zone ID for $DOMAIN..."
echo ""

# Get Vault pod
VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

if [ -z "$VAULT_POD" ]; then
    echo "❌ Error: Vault pod not found in namespace '$VAULT_NAMESPACE'"
    exit 1
fi

# Get API token from Vault
echo "📥 Retrieving Cloudflare API token from Vault..."
API_TOKEN=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
    vault kv get -field=api-token secret/pi-fleet/terraform/cloudflare-api-token 2>/dev/null || echo "")

if [ -z "$API_TOKEN" ]; then
    echo "❌ Error: Cloudflare API token not found in Vault"
    echo ""
    echo "Store it first:"
    echo "  kubectl exec -n vault \$VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token='YOUR_TOKEN'"
    exit 1
fi

echo "✓ API token retrieved"
echo ""

# Get zone ID from Cloudflare API
echo "🌐 Querying Cloudflare API..."
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" | \
    jq -r '.result[0].id // empty')

if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
    echo "❌ Error: Could not find zone ID for $DOMAIN"
    echo ""
    echo "Possible reasons:"
    echo "  1. Domain not added to Cloudflare account"
    echo "  2. API token doesn't have permission to read zones"
    echo "  3. Domain name is incorrect"
    exit 1
fi

echo "✅ Zone ID found!"
echo ""
echo "Zone ID for $DOMAIN: $ZONE_ID"
echo ""
echo "Add this to your terraform.tfvars:"
echo "  pitanga_cloud_zone_id = \"$ZONE_ID\""
echo ""
echo "Or set as environment variable:"
echo "  export TF_VAR_pitanga_cloud_zone_id=\"$ZONE_ID\""
echo ""



