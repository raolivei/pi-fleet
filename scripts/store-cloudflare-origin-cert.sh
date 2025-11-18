#!/bin/bash
# Store Cloudflare Origin Certificate in Kubernetes secret
#
# Usage:
#   ./scripts/store-cloudflare-origin-cert.sh <certificate-file> <private-key-file> [namespace]
#
# Example:
#   ./scripts/store-cloudflare-origin-cert.sh origin.pem origin.key swimto

set -e

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <certificate-file> <private-key-file> [namespace]"
    echo ""
    echo "Example:"
    echo "  $0 origin.pem origin.key swimto"
    echo ""
    echo "This script creates a Kubernetes TLS secret from Cloudflare Origin Certificate files."
    exit 1
fi

CERT_FILE="$1"
KEY_FILE="$2"
NAMESPACE="${3:-swimto}"
SECRET_NAME="swimto-cloudflare-origin-tls"

# Validate files exist
if [ ! -f "$CERT_FILE" ]; then
    echo "Error: Certificate file not found: $CERT_FILE"
    exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
    echo "Error: Private key file not found: $KEY_FILE"
    exit 1
fi

# Validate certificate format
echo "Validating certificate format..."
if ! openssl x509 -in "$CERT_FILE" -text -noout > /dev/null 2>&1; then
    echo "Error: Invalid certificate format in $CERT_FILE"
    exit 1
fi

# Validate private key format
echo "Validating private key format..."
if ! openssl rsa -in "$KEY_FILE" -check > /dev/null 2>&1; then
    echo "Error: Invalid private key format in $KEY_FILE"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
    echo "Error: Namespace '$NAMESPACE' does not exist"
    echo "Create it first: kubectl create namespace $NAMESPACE"
    exit 1
fi

# Create or update secret
echo "Creating TLS secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
kubectl create secret tls "$SECRET_NAME" \
    --cert="$CERT_FILE" \
    --key="$KEY_FILE" \
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
echo "2. Enable proxy (orange cloud) for swimto.eldertree.xyz DNS record"
echo "3. Verify ingress is using this secret: kubectl describe ingress swimto-web-public -n $NAMESPACE"

