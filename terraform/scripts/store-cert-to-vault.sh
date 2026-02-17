#!/bin/bash
# Store Cloudflare Origin Certificate in Vault from Terraform Cloud state
#
# Usage:
#   ./scripts/store-cert-to-vault.sh <domain> <vault-path>
#
# Examples:
#   ./scripts/store-cert-to-vault.sh raolivei_com personal-website
#   ./scripts/store-cert-to-vault.sh pitanga_cloud pitanga
#
# Reads Terraform Cloud state outputs via API (no terraform CLI needed)
# and stores the certificate in Vault via kubectl exec.
#
# Prerequisites:
#   - ~/.terraform.d/credentials.tfrc.json (Terraform Cloud API token)
#   - kubectl configured with cluster access
#   - Vault deployed and unsealed

set -e

DOMAIN="${1:?Usage: $0 <domain> <vault-path>  (e.g., raolivei_com personal-website)}"
VAULT_PATH="${2:?Usage: $0 <domain> <vault-path>  (e.g., raolivei_com personal-website)}"

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
VAULT_NAMESPACE="vault"

TF_CLOUD_ORG="eldertree"
TF_CLOUD_WORKSPACE="pi-fleet-terraform"
TF_CREDS_FILE="$HOME/.terraform.d/credentials.tfrc.json"

if [ ! -f "$TF_CREDS_FILE" ]; then
    echo "Error: Terraform Cloud credentials not found at $TF_CREDS_FILE"
    exit 1
fi

TF_TOKEN=$(python3 -c "
import json
with open('$TF_CREDS_FILE') as f:
    creds = json.load(f)
print(creds.get('credentials', {}).get('app.terraform.io', {}).get('token', ''))
")

if [ -z "$TF_TOKEN" ]; then
    echo "Error: Could not extract Terraform Cloud token"
    exit 1
fi

echo "Fetching outputs from Terraform Cloud..."

WORKSPACE_ID=$(curl -sf \
    -H "Authorization: Bearer $TF_TOKEN" \
    -H "Content-Type: application/vnd.api+json" \
    "https://app.terraform.io/api/v2/organizations/$TF_CLOUD_ORG/workspaces/$TF_CLOUD_WORKSPACE" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['id'])")

echo "Workspace ID: $WORKSPACE_ID"

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

curl -sf \
    -H "Authorization: Bearer $TF_TOKEN" \
    -H "Content-Type: application/vnd.api+json" \
    "https://app.terraform.io/api/v2/workspaces/$WORKSPACE_ID/current-state-version?include=outputs" \
    | python3 -c "
import json, sys, os
data = json.load(sys.stdin)
outputs = data.get('included', [])
cert_val = key_val = ''
for o in outputs:
    attrs = o.get('attributes', {})
    name = attrs.get('name', '')
    if name == '${DOMAIN}_origin_cert':
        cert_val = attrs.get('value', '')
    elif name == '${DOMAIN}_origin_key':
        key_val = attrs.get('value', '')
if not cert_val or not key_val:
    print('ERROR: outputs not found', file=sys.stderr)
    sys.exit(1)
with open('$TEMP_DIR/cert.pem', 'w') as f:
    f.write(cert_val)
with open('$TEMP_DIR/key.pem', 'w') as f:
    f.write(key_val)
print('OK')
"

echo "Validating certificate..."
openssl x509 -in "$TEMP_DIR/cert.pem" -noout -subject -dates 2>/dev/null || {
    echo "Error: Invalid certificate"; exit 1
}

echo "Finding Vault pod..."
VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault \
    --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

if [ -z "$VAULT_POD" ]; then
    echo "Error: No running Vault pod found"
    exit 1
fi

echo "Storing in Vault at secret/$VAULT_PATH/cloudflare-origin-cert..."
kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
vault kv put secret/$VAULT_PATH/cloudflare-origin-cert \
  certificate='$(cat "$TEMP_DIR/cert.pem")' \
  private-key='$(cat "$TEMP_DIR/key.pem")'
"

echo ""
echo "Done! Certificate stored at secret/$VAULT_PATH/cloudflare-origin-cert"
echo ""
openssl x509 -in "$TEMP_DIR/cert.pem" -noout -subject -dates -ext subjectAltName 2>/dev/null || true
echo ""
echo "ExternalSecret will auto-sync to Kubernetes."
