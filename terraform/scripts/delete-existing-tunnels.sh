#!/bin/bash
# Delete existing Cloudflare Tunnels with name "eldertree"
# This allows Terraform to create a fresh tunnel

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$TERRAFORM_DIR"

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

# Get Cloudflare API token from Vault
echo "🔐 Loading Cloudflare API token from Vault..."
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$VAULT_POD" ]; then
    echo "❌ Error: Vault pod not found"
    exit 1
fi

API_TOKEN=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=api-token secret/terraform/cloudflare-api-token 2>/dev/null || echo "")

if [ -z "$API_TOKEN" ]; then
    echo "❌ Error: Could not retrieve Cloudflare API token from Vault"
    exit 1
fi

ACCOUNT_ID="${1:-df9f4a67fad65321c2c5d9c866d2f239}"

echo "📋 Listing existing tunnels..."
TUNNELS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json")

TUNNEL_COUNT=$(echo "$TUNNELS" | jq -r '.result | length')
echo "Found $TUNNEL_COUNT tunnel(s)"

if [ "$TUNNEL_COUNT" -eq 0 ]; then
    echo "✅ No tunnels found. You can proceed with terraform apply."
    exit 0
fi

echo ""
echo "Existing tunnels:"
echo "$TUNNELS" | jq -r '.result[] | "  - \(.name) (ID: \(.id)) - Created: \(.created_at)"'

echo ""
read -p "Delete all tunnels named 'eldertree'? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Delete each tunnel
echo "$TUNNELS" | jq -r '.result[] | select(.name == "eldertree") | .id' | while read TUNNEL_ID; do
    if [ -n "$TUNNEL_ID" ]; then
        echo "🗑️  Deleting tunnel: $TUNNEL_ID"
        RESPONSE=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID" \
          -H "Authorization: Bearer $API_TOKEN" \
          -H "Content-Type: application/json")
        
        SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
        if [ "$SUCCESS" = "true" ]; then
            echo "  ✅ Deleted successfully"
        else
            ERRORS=$(echo "$RESPONSE" | jq -r '.errors[]?.message' | tr '\n' ' ')
            echo "  ❌ Failed: $ERRORS"
        fi
    fi
done

echo ""
echo "✅ Done! You can now run: ./run-terraform.sh apply"

