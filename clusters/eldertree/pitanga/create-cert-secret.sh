#!/bin/bash
# Create Cloudflare Origin Certificate TLS secret from Terraform output
# This is a workaround when ExternalSecret can't sync from Vault

set -e

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
NAMESPACE="pitanga"
SECRET_NAME="pitanga-cloudflare-origin-tls"

# Change to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "$SCRIPT_DIR/../../terraform" && pwd)"

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

# Create temporary files
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

# Create or update secret
echo "📝 Creating TLS secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
kubectl create secret tls "$SECRET_NAME" \
    --cert="$TEMP_DIR/cert.pem" \
    --key="$TEMP_DIR/key.pem" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Verify secret
echo ""
echo "✅ Secret created successfully!"
echo ""
echo "Secret details:"
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE"

echo ""
echo "Certificate details:"
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.tls\.crt}' | \
    base64 -d | openssl x509 -text -noout | grep -E "(Subject:|Issuer:|Validity|DNS:)" | head -5

echo ""
echo "🔄 Restarting Traefik to pick up the new certificate..."
kubectl rollout restart deployment/traefik -n kube-system 2>/dev/null || \
    kubectl delete pod -n kube-system -l app.kubernetes.io/name=traefik 2>/dev/null || \
    echo "   (Traefik will pick up the secret automatically)"

echo ""
echo "✅ Done! The certificate should now be available for ingress resources."
echo ""
echo "Next steps:"
echo "1. Wait 30-60 seconds for Traefik to reload"
echo "2. Test: curl -I https://pitanga.cloud"
echo "3. Verify in Cloudflare Dashboard: SSL/TLS → Overview → Set to 'Full (strict)'"


