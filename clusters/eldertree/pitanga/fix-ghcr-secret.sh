#!/bin/bash
# Fix GHCR secret for pitanga namespace
# Run this script directly: ./fix-ghcr-secret.sh
# 
# This script reads the GitHub token from Vault instead of hardcoding it.
# Make sure the token is stored in Vault at: secret/canopy/ghcr-token (key: token)

set -e

export KUBECONFIG=~/.kube/config-eldertree
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

# Get GitHub token from Vault
# Try to read from Vault, fallback to environment variable if set
if [ -z "$GITHUB_TOKEN" ]; then
    if [ -f "$REPO_ROOT/scripts/get-vault-secret.sh" ]; then
        GITHUB_TOKEN=$("$REPO_ROOT/scripts/get-vault-secret.sh" secret/canopy/ghcr-token token 2>/dev/null || echo "")
    fi
fi

# If still not set, try direct Vault access
if [ -z "$GITHUB_TOKEN" ]; then
    VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$VAULT_POD" ]; then
        GITHUB_TOKEN=$(kubectl exec -n vault "$VAULT_POD" -- \
            sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && \
            export VAULT_TOKEN=\$(cat /tmp/vault-init.json 2>/dev/null | jq -r '.root_token' || echo '') && \
            vault kv get -format=json secret/canopy/ghcr-token 2>/dev/null | jq -r '.data.data.token' || echo ''" 2>/dev/null || echo "")
    fi
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: Could not get GitHub token from Vault"
    echo ""
    echo "Please either:"
    echo "  1. Store the token in Vault:"
    echo "     kubectl exec -n vault \$VAULT_POD -- vault kv put secret/canopy/ghcr-token token='YOUR_TOKEN'"
    echo ""
    echo "  2. Or set GITHUB_TOKEN environment variable:"
    echo "     export GITHUB_TOKEN='your-token'"
    echo "     ./fix-ghcr-secret.sh"
    exit 1
fi

NAMESPACE="pitanga"

echo "🔐 Creating GHCR secret..."

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password="$GITHUB_TOKEN" \
  -n "$NAMESPACE" 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Secret created"
else
    echo "⚠️  Secret may already exist, trying to update..."
    kubectl delete secret ghcr-secret -n "$NAMESPACE" 2>/dev/null
    kubectl create secret docker-registry ghcr-secret \
      --docker-server=ghcr.io \
      --docker-username=raolivei \
      --docker-password="$GITHUB_TOKEN" \
      -n "$NAMESPACE"
fi

echo ""
echo "🔄 Restarting deployments..."
kubectl rollout restart deployment/pitanga-website -n "$NAMESPACE"
kubectl rollout restart deployment/northwaysignal-website -n "$NAMESPACE"

echo ""
echo "✅ Done! Check status:"
echo "   kubectl get pods -n $NAMESPACE"


