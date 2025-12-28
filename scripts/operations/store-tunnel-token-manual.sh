#!/bin/bash
# Manual script to store Cloudflare Tunnel token in Vault
# This script guides you through the process step by step

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

TUNNEL_TOKEN="${1:-eyJhIjoiZGY5ZjRhNjdmYWQ2NTMyMWMyYzVkOWM4NjZkMmYyMzkiLCJ0IjoiOTBkYjNiYTMtNWU4NC00MjNmLTk3NDctMjQ5Yjc1NWE2M2EwIiwicyI6Ik5tVTFaalV3WkRNdE9EWTROeTAwTTJZM0xUbG1ObVF0TWpCbE1EZGlZelZpTTJOaSJ9}"

echo "🔐 Storing Cloudflare Tunnel Token in Vault"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$VAULT_POD" ]; then
    echo "❌ Error: Vault pod not found"
    exit 1
fi

# Check if Vault is unsealed
VAULT_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status 2>&1 | grep "Sealed" | awk '{print $2}' || echo "true")
if [ "$VAULT_STATUS" = "true" ]; then
    echo "❌ Error: Vault is sealed. Please unseal it first:"
    echo "   cd $PI_FLEET_DIR && ./scripts/operations/unseal-vault.sh"
    exit 1
fi

echo "✅ Vault is unsealed"
echo ""

# Method 1: Try with root token from environment or prompt
if [ -n "$VAULT_ROOT_TOKEN" ]; then
    echo "🔑 Using root token from VAULT_ROOT_TOKEN environment variable..."
    kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='$VAULT_ROOT_TOKEN' && vault kv put secret/pi-fleet/cloudflare-tunnel/token token='$TUNNEL_TOKEN'"
    echo "✅ Token stored successfully!"
    exit 0
fi

# Method 2: Interactive login
echo "📋 You need to authenticate to Vault first."
echo ""
echo "Option 1: If you have the root token, set it as an environment variable:"
echo "   export VAULT_ROOT_TOKEN=your-root-token-here"
echo "   $0"
echo ""
echo "Option 2: Login interactively to Vault, then run the store command:"
echo ""
echo "   # Step 1: Login to Vault"
echo "   kubectl exec -it -n vault $VAULT_POD -- vault login"
echo ""
echo "   # Step 2: Store the token (after login, the token will be cached)"
echo "   kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/cloudflare-tunnel/token token='$TUNNEL_TOKEN'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Quick command to run after logging in:"
echo ""
echo "kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/cloudflare-tunnel/token token='$TUNNEL_TOKEN'"
echo ""

