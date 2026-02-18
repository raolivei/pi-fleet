#!/bin/bash
# Interactive script to add secrets to Vault
# Usage: ./scripts/operations/setup-vault-secrets.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

echo "🔐 Vault Secrets Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$VAULT_POD" ]; then
    echo "❌ Error: Vault pod not found"
    exit 1
fi

# Check if Vault is unsealed
SEAL_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
if [ "$SEAL_STATUS" = "true" ]; then
    echo "❌ Error: Vault is sealed. Please unseal it first:"
    echo "   ./scripts/operations/unseal-vault.sh"
    exit 1
fi

# Check if logged in
if ! kubectl exec -n vault $VAULT_POD -- vault token lookup &>/dev/null; then
    echo "⚠️  Not logged in to Vault. Please login first:"
    echo "   kubectl exec -it -n vault $VAULT_POD -- vault login"
    exit 1
fi

echo "✅ Vault is ready"
echo ""

# Function to get secret path and keys by selection number
get_secret_info() {
    case "$1" in
        1)  echo "secret/pi-fleet/cloudflare-tunnel/token:token" ;;
        2)  echo "secret/pi-fleet/terraform/cloudflare-api-token:api-token" ;;
        3)  echo "secret/pi-fleet/external-dns/cloudflare-api-token:api-token" ;;
        4)  echo "secret/swimto/database:url" ;;
        5)  echo "secret/swimto/postgres:password" ;;
        6)  echo "secret/swimto/redis:url" ;;
        7)  echo "secret/swimto/app:admin-token,secret-key" ;;
        8)  echo "secret/swimto/api-keys:openai-api-key,leonardo-api-key" ;;
        9)  echo "secret/swimto/oauth:google-client-id,google-client-secret" ;;
        10) echo "secret/canopy/postgres:password" ;;
        11) echo "secret/canopy/app:secret-key" ;;
        12) echo "secret/canopy/database:url" ;;
        13) echo "secret/canopy/questrade:refresh-token" ;;
        14) echo "secret/canopy/wise:api-token" ;;
        15) echo "secret/journey/postgres:user,password" ;;
        16) echo "secret/journey/database:url" ;;
        17) echo "secret/monitoring/grafana:adminUser,adminPassword" ;;
        18) echo "secret/pi-fleet/pihole/webpassword:password" ;;
        19) echo "secret/us-law-severity-map/mapbox:api-key" ;;
        20) echo "secret/pi-fleet/flux/git:sshKey" ;;
        21) echo "secret/pi-fleet/external-dns/tsig-secret:secret" ;;
        *)  echo "" ;;
    esac
}

echo "Available secrets to configure:"
echo ""
echo "  1) secret/pi-fleet/cloudflare-tunnel/token (token)"
echo "  2) secret/pi-fleet/terraform/cloudflare-api-token (api-token)"
echo "  3) secret/pi-fleet/external-dns/cloudflare-api-token (api-token)"
echo "  4) secret/swimto/database (url)"
echo "  5) secret/swimto/postgres (password)"
echo "  6) secret/swimto/redis (url)"
echo "  7) secret/swimto/app (admin-token,secret-key)"
echo "  8) secret/swimto/api-keys (openai-api-key,leonardo-api-key)"
echo "  9) secret/swimto/oauth (google-client-id,google-client-secret)"
echo " 10) secret/canopy/postgres (password)"
echo " 11) secret/canopy/app (secret-key)"
echo " 12) secret/canopy/database (url)"
echo " 13) secret/canopy/questrade (refresh-token)"
echo " 14) secret/canopy/wise (api-token)"
echo " 15) secret/journey/postgres (user,password)"
echo " 16) secret/journey/database (url)"
echo " 17) secret/monitoring/grafana (adminUser,adminPassword)"
echo " 18) secret/pi-fleet/pihole/webpassword (password)"
echo " 19) secret/us-law-severity-map/mapbox (api-key)"
echo " 20) secret/pi-fleet/flux/git (sshKey)"
echo " 21) secret/pi-fleet/external-dns/tsig-secret (secret)"
echo "  0) Custom path"
echo ""

read -p "Select secret to configure (number): " SELECTION

if [ -z "$SELECTION" ]; then
    echo "❌ No selection made"
    exit 1
fi

if [ "$SELECTION" = "0" ]; then
    read -p "Enter secret path (e.g., secret/my-app/config): " CUSTOM_PATH
    read -p "Enter key name(s), comma-separated (e.g., key1,key2): " CUSTOM_KEYS
    SECRET_PATH="$CUSTOM_PATH"
    KEYS="$CUSTOM_KEYS"
else
    path_key=$(get_secret_info "$SELECTION")
    if [ -z "$path_key" ]; then
        echo "❌ Invalid selection"
        exit 1
    fi
    SECRET_PATH="${path_key%%:*}"
    KEYS="${path_key##*:}"
fi

echo ""
echo "Configuring: $SECRET_PATH"
echo "Keys needed: $KEYS"
echo ""

# Build vault kv put command
KV_ARGS=""
IFS=',' read -ra KEY_ARRAY <<< "$KEYS"
for key in "${KEY_ARRAY[@]}"; do
    key=$(echo "$key" | xargs) # trim whitespace
    read -p "Enter value for '$key' (will not be displayed): " -s VALUE
    echo ""
    if [ -n "$VALUE" ]; then
        KV_ARGS="$KV_ARGS $key=\"$VALUE\""
    fi
done

if [ -z "$KV_ARGS" ]; then
    echo "❌ No values provided"
    exit 1
fi

# Store secret
echo ""
echo "💾 Storing secret..."
kubectl exec -n vault $VAULT_POD -- vault kv put "$SECRET_PATH" $KV_ARGS

echo ""
echo "✅ Secret stored successfully!"
echo ""
echo "Verification:"
echo "  kubectl exec -n vault $VAULT_POD -- vault kv get $SECRET_PATH"
echo ""
echo "External Secrets Operator will sync this automatically if configured."
