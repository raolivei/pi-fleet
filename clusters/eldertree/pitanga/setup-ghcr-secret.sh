#!/bin/bash
# Setup GHCR secret for pitanga namespace
#
# This script helps create the GHCR secret needed for pulling images.
# You can either:
# 1. Create it manually (quick fix)
# 2. Store token in Vault (proper fix, requires Vault connection working)
#
# Usage:
#   ./setup-ghcr-secret.sh [github-token]
#   OR
#   ./setup-ghcr-secret.sh  # Will prompt for token

set -e

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
NAMESPACE="pitanga"

# Get token from argument or prompt
if [ -n "$1" ]; then
    GITHUB_TOKEN="$1"
else
    echo "Enter your GitHub Personal Access Token (with 'read:packages' permission):"
    echo "Create one at: https://github.com/settings/tokens"
    read -s GITHUB_TOKEN
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GitHub token is required"
    exit 1
fi

echo ""
echo "🔐 Setting up GHCR secret for pitanga namespace..."
echo ""

# Option 1: Create secret directly (quick fix)
echo "📝 Creating GHCR secret directly in Kubernetes..."
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password="$GITHUB_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f - -n "$NAMESPACE"

echo "✅ GHCR secret created in Kubernetes"
echo ""

# Option 2: Also store in Vault (for future ExternalSecret sync)
read -p "Store token in Vault for ExternalSecret sync? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$VAULT_POD" ]; then
        echo "⚠️  Vault pod not found. Skipping Vault storage."
        echo "   You can store it later when Vault is accessible:"
        echo "   kubectl exec -n vault \$VAULT_POD -- vault kv put secret/pitanga/ghcr-token token='$GITHUB_TOKEN'"
    else
        echo "💾 Storing token in Vault..."
        kubectl exec -n vault $VAULT_POD -- vault kv put secret/pitanga/ghcr-token token="$GITHUB_TOKEN"
        echo "✅ Token stored in Vault at secret/pitanga/ghcr-token"
    fi
fi

echo ""
echo "🔄 Restarting deployments to pull images..."
kubectl rollout restart deployment/pitanga-website -n "$NAMESPACE"
kubectl rollout restart deployment/northwaysignal-website -n "$NAMESPACE"

echo ""
echo "✅ Setup complete!"
echo ""
echo "📊 Check deployment status:"
echo "   kubectl get pods -n $NAMESPACE -w"
echo ""
echo "🔍 Verify secret:"
echo "   kubectl get secret ghcr-secret -n $NAMESPACE"



