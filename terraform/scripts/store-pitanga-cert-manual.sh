#!/bin/bash
# Store manually created Cloudflare Origin Certificate in Vault
#
# Usage:
#   ./scripts/store-pitanga-cert-manual.sh <certificate-file> <private-key-file>
#
# Or paste certificate directly:
#   ./scripts/store-pitanga-cert-manual.sh <(echo "CERT_CONTENT") <(echo "KEY_CONTENT")

set -e

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
VAULT_NAMESPACE="vault"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <certificate-file> <private-key-file>"
    echo ""
    echo "Example:"
    echo "  $0 pitanga.crt pitanga.key"
    echo ""
    echo "Or paste directly:"
    echo "  $0 <(echo 'CERT') <(echo 'KEY')"
    exit 1
fi

CERT_FILE="$1"
KEY_FILE="$2"

# Read certificate and key
CERT=$(cat "$CERT_FILE")
KEY=$(cat "$KEY_FILE")

# Validate certificate format
echo "Validating certificate format..."
if ! echo "$CERT" | openssl x509 -text -noout > /dev/null 2>&1; then
    echo "❌ Error: Invalid certificate format"
    exit 1
fi

# Validate private key format
echo "Validating private key format..."
if ! echo "$KEY" | openssl rsa -check > /dev/null 2>&1; then
    echo "❌ Error: Invalid private key format"
    exit 1
fi

# Get Vault pod
echo "🔍 Finding Vault pod..."
VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

if [ -z "$VAULT_POD" ]; then
    echo "❌ Error: Vault pod not found in namespace '$VAULT_NAMESPACE'"
    exit 1
fi

echo "✓ Found Vault pod: $VAULT_POD"

# Store certificate in Vault
echo "💾 Storing certificate in Vault..."
kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
vault kv put secret/pitanga/cloudflare-origin-cert \
  certificate='$(echo "$CERT" | sed "s/'/''/g")' \
  private-key='$(echo "$KEY" | sed "s/'/''/g")'
"

echo ""
echo "✅ Certificate stored successfully in Vault!"
echo ""
echo "Vault path: secret/pitanga/cloudflare-origin-cert"
echo ""
echo "Certificate details:"
echo "$CERT" | openssl x509 -text -noout | grep -E "(Subject:|Issuer:|Validity|DNS:)" || true
echo ""
echo "Next steps:"
echo "1. The ExternalSecret will automatically sync from Vault to Kubernetes"
echo "2. Verify sync: kubectl get externalsecret pitanga-cloudflare-origin-cert -n pitanga"
echo "3. Check secret: kubectl get secret pitanga-cloudflare-origin-tls -n pitanga"
echo "4. Ensure Cloudflare SSL mode is set to 'Full (strict)'"



