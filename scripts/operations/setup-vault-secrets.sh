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

# Secret categories
declare -A SECRET_PATHS=(
    ["1"]="secret/pi-fleet/cloudflare-tunnel/token:token"
    ["2"]="secret/pi-fleet/terraform/cloudflare-api-token:api-token"
    ["3"]="secret/pi-fleet/external-dns/cloudflare-api-token:api-token"
    ["4"]="secret/swimto/database:url"
    ["5"]="secret/swimto/postgres:password"
    ["6"]="secret/swimto/redis:url"
    ["7"]="secret/swimto/app:admin-token,secret-key"
    ["8"]="secret/swimto/api-keys:openai-api-key,leonardo-api-key"
    ["9"]="secret/swimto/oauth:google-client-id,google-client-secret"
    ["10"]="secret/canopy/postgres:password"
    ["11"]="secret/canopy/app:secret-key"
    ["12"]="secret/canopy/database:url"
    ["13"]="secret/journey/postgres:user,password"
    ["14"]="secret/journey/database:url"
    ["15"]="secret/monitoring/grafana:adminUser,adminPassword"
    ["16"]="secret/pihole/webpassword:password"
    ["17"]="secret/us-law-severity-map/mapbox:api-key"
    ["18"]="secret/flux/git:sshKey"
    ["19"]="secret/external-dns/tsig-secret:secret"
)

echo "Available secrets to configure:"
echo ""
for key in $(printf '%s\n' "${!SECRET_PATHS[@]}" | sort -n); do
    path_key="${SECRET_PATHS[$key]}"
    path="${path_key%%:*}"
    keys="${path_key##*:}"
    echo "  $key) $path ($keys)"
done
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
    path_key="${SECRET_PATHS[$SELECTION]}"
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

