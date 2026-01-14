#!/bin/bash
# Store Cloudflare Origin Certificate from Terraform output in Vault
#
# Usage:
#   ./scripts/store-pitanga-cert-from-terraform.sh
#
# Prerequisites:
#   - Terraform has been applied and created the Origin Certificate
#   - kubectl is configured and pointing to the correct cluster
#   - Vault is deployed and unsealed

set -e

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
VAULT_NAMESPACE="vault"

# Change to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$TERRAFORM_DIR"

# Check if Terraform has been initialized
if [ ! -d ".terraform" ]; then
    echo "Error: Terraform not initialized. Run 'terraform init' first."
    exit 1
fi

# Get certificate and private key from Terraform output
echo "🔐 Retrieving certificate from Terraform..."
CERT=$(terraform output -raw pitanga_cloud_origin_certificate 2>/dev/null || echo "")
KEY=$(terraform output -raw pitanga_cloud_origin_private_key 2>/dev/null || echo "")

if [ -z "$CERT" ] || [ -z "$KEY" ]; then
    echo "❌ Error: Could not retrieve certificate from Terraform output."
    echo "Make sure Terraform has been applied: terraform apply"
    exit 1
fi

# Create temporary files for validation
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "$CERT" > "$TEMP_DIR/cert.pem"
echo "$KEY" > "$TEMP_DIR/key.pem"

# Validate certificate format
echo "✓ Validating certificate format..."
if ! openssl x509 -in "$TEMP_DIR/cert.pem" -text -noout > /dev/null 2>&1; then
    echo "❌ Error: Invalid certificate format"
    exit 1
fi

# Validate private key format
echo "✓ Validating private key format..."
if ! openssl rsa -in "$TEMP_DIR/key.pem" -check > /dev/null 2>&1; then
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
  certificate='$(cat "$TEMP_DIR/cert.pem")' \
  private-key='$(cat "$TEMP_DIR/key.pem")'
"

# Verify certificate was stored
echo ""
echo "✅ Certificate stored successfully in Vault!"
echo ""
echo "Vault path: secret/pitanga/cloudflare-origin-cert"
echo ""
echo "Certificate details:"
openssl x509 -in "$TEMP_DIR/cert.pem" -text -noout | grep -E "(Subject:|Issuer:|Validity|DNS:)" || true
echo ""
echo "Next steps:"
echo "1. The ExternalSecret will automatically sync from Vault to Kubernetes"
echo "2. Verify sync: kubectl get externalsecret pitanga-cloudflare-origin-cert -n pitanga"
echo "3. Check secret: kubectl get secret pitanga-cloudflare-origin-tls -n pitanga"
echo "4. Ensure Cloudflare SSL/TLS mode is set to 'Full (strict)'"
echo "5. Verify proxy is enabled (orange cloud) for DNS records"



