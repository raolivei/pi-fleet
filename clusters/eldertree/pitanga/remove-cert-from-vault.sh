#!/bin/bash
# Remove Cloudflare Origin Certificate from Vault
#
# This script removes the old certificate from Vault that was manually created
# and has been revoked.

set -e

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
VAULT_NAMESPACE="vault"
VAULT_PATH="secret/pitanga/cloudflare-origin-cert"

echo "🗑️  Removing Cloudflare Origin Certificate from Vault..."
echo ""

# Get Vault pod
VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

if [ -z "$VAULT_POD" ]; then
    echo "❌ Error: Vault pod not found in namespace '$VAULT_NAMESPACE'"
    exit 1
fi

echo "✓ Found Vault pod: $VAULT_POD"
echo ""

# Check if secret exists
echo "Checking if secret exists..."
SECRET_EXISTS=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
    vault kv get "$VAULT_PATH" > /dev/null 2>&1 && echo "yes" || echo "no")

if [ "$SECRET_EXISTS" = "no" ]; then
    echo "ℹ️  Secret does not exist at $VAULT_PATH"
    echo "   Nothing to remove."
    exit 0
fi

echo "✓ Secret found at $VAULT_PATH"
echo ""

# Delete the secret
echo "Deleting secret from Vault..."
kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
    vault kv delete "$VAULT_PATH"

echo ""
echo "✅ Certificate removed from Vault!"
echo ""
echo "Next steps:"
echo "1. Create new certificate via Terraform: cd terraform && ./run-terraform.sh apply"
echo "2. Store new certificate: ./scripts/store-pitanga-cert-from-terraform.sh"
echo "3. The ExternalSecret will automatically sync the new certificate to Kubernetes"



