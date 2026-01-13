#!/bin/bash
# Remove Cloudflare Origin Certificate from Kubernetes
#
# This script removes the old certificate secret from Kubernetes
# that was synced from Vault via External Secrets Operator.

set -e

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
NAMESPACE="pitanga"
SECRET_NAME="pitanga-cloudflare-origin-tls"
EXTERNAL_SECRET_NAME="pitanga-cloudflare-origin-cert"

echo "🗑️  Removing Cloudflare Origin Certificate from Kubernetes..."
echo ""

# Check if ExternalSecret exists
if kubectl get externalsecret "$EXTERNAL_SECRET_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "⚠️  ExternalSecret '$EXTERNAL_SECRET_NAME' exists"
    echo "   This will recreate the secret. Deleting it first..."
    kubectl delete externalsecret "$EXTERNAL_SECRET_NAME" -n "$NAMESPACE"
    echo "✓ ExternalSecret deleted"
    echo ""
fi

# Check if secret exists
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "✓ Secret '$SECRET_NAME' found"
    echo "   Deleting..."
    kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
    echo "✓ Secret deleted"
else
    echo "ℹ️  Secret '$SECRET_NAME' does not exist"
    echo "   Nothing to remove."
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Next steps:"
echo "1. Create new certificate via Terraform: cd terraform && ./run-terraform.sh apply"
echo "2. Store new certificate in Vault: ./scripts/store-pitanga-cert-from-terraform.sh"
echo "3. Re-apply ExternalSecret: kubectl apply -f cloudflare-origin-cert-external.yaml"
echo "   (Or let GitOps/FluxCD sync it automatically)"



