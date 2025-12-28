#!/bin/bash
# Store Cloudflare Tunnel token in Vault
#
# Usage:
#   ./scripts/store-tunnel-token.sh [token]
#   OR
#   ./scripts/store-tunnel-token.sh  # Will prompt for token

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$TERRAFORM_DIR"

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

# Get token from argument or prompt
if [ -z "$1" ]; then
    echo "📋 Get the tunnel token from Cloudflare Dashboard:"
    echo ""
    echo "   1. Go to: https://dash.cloudflare.com"
    echo "   2. Zero Trust → Networks → Tunnels"
    echo "   3. Click on 'eldertree' tunnel"
    echo "   4. Click 'Configure' next to connector"
    echo "   5. Copy the Tunnel Token (starts with eyJ...)"
    echo ""
    echo "Enter the tunnel token (will not be displayed):"
    read -s TUNNEL_TOKEN
else
    TUNNEL_TOKEN="$1"
fi

if [ -z "$TUNNEL_TOKEN" ]; then
    echo "❌ Error: Tunnel token is required"
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
    echo "   cd $TERRAFORM_DIR/.. && ./scripts/operations/unseal-vault.sh"
    exit 1
fi

# Store token in Vault
echo "💾 Storing tunnel token in Vault..."
kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/cloudflare-tunnel/token token="$TUNNEL_TOKEN"

echo ""
echo "✅ Tunnel token stored successfully in Vault!"
echo ""
echo "The External Secrets Operator will sync this to Kubernetes automatically."
echo "The cloudflared pod should pick it up and start within a few minutes."
echo ""
echo "Check status:"
echo "  kubectl get pods -n cloudflare-tunnel"
echo "  kubectl get externalsecrets -n cloudflare-tunnel"

