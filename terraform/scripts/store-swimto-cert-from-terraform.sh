#!/bin/bash
# Store Cloudflare Origin Certificate from Terraform output in Kubernetes secret
#
# Usage:
#   ./scripts/store-swimto-cert-from-terraform.sh [namespace]
#
# Prerequisites:
#   - Terraform has been applied and created the Origin Certificate
#   - kubectl is configured and pointing to the correct cluster

set -e

NAMESPACE="${1:-swimto}"
SECRET_NAME="swimto-cloudflare-origin-tls"

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

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
echo "Retrieving certificate from Terraform..."
CERT=$(terraform output -raw swimto_origin_certificate 2>/dev/null || echo "")
KEY=$(terraform output -raw swimto_origin_private_key 2>/dev/null || echo "")

if [ -z "$CERT" ] || [ -z "$KEY" ]; then
    echo "Error: Could not retrieve certificate from Terraform output."
    echo "Make sure Terraform has been applied: terraform apply"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
    echo "Error: Namespace '$NAMESPACE' does not exist"
    echo "Create it first: kubectl create namespace $NAMESPACE"
    exit 1
fi

# Create temporary files for certificate and key
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "$CERT" > "$TEMP_DIR/cert.pem"
echo "$KEY" > "$TEMP_DIR/key.pem"

# Validate certificate format
echo "Validating certificate format..."
if ! openssl x509 -in "$TEMP_DIR/cert.pem" -text -noout > /dev/null 2>&1; then
    echo "Error: Invalid certificate format"
    exit 1
fi

# Validate private key format
echo "Validating private key format..."
if ! openssl rsa -in "$TEMP_DIR/key.pem" -check > /dev/null 2>&1; then
    echo "Error: Invalid private key format"
    exit 1
fi

# Create or update secret
echo "Creating TLS secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
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
    base64 -d | openssl x509 -text -noout | grep -E "(Subject:|Issuer:|Validity|DNS:)"

echo ""
echo "Next steps:"
echo "1. Ensure Cloudflare SSL/TLS mode is set to 'Full (strict)'"
echo "2. Verify proxy is enabled (orange cloud) for swimto.eldertree.xyz DNS record"
echo "3. Verify ingress is using this secret: kubectl describe ingress swimto-web-public -n $NAMESPACE"

