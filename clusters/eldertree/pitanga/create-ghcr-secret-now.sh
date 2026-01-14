#!/bin/bash
# Quick script to create GHCR secret with the provided token
# Run this when the cluster is accessible

set -e

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

# Get GitHub token from Vault (preferred) or environment variable
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
    echo "     ./create-ghcr-secret-now.sh"
    exit 1
fi

NAMESPACE="pitanga"

echo "🔐 Creating GHCR secret for pitanga namespace..."
echo ""

# Check if cluster is accessible
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ Error: Cannot connect to Kubernetes cluster"
    echo "   Please check:"
    echo "   1. Cluster nodes are running"
    echo "   2. Network connectivity to 192.168.2.101:6443"
    echo "   3. KUBECONFIG is set correctly"
    exit 1
fi

echo "✅ Cluster is accessible"
echo ""

# Create or update secret
echo "📝 Creating/updating GHCR secret..."
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password="$GITHUB_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f - -n "$NAMESPACE"

echo "✅ GHCR secret created/updated"
echo ""

# Restart deployments
echo "🔄 Restarting deployments to pull images..."
kubectl rollout restart deployment/pitanga-website -n "$NAMESPACE" || echo "⚠️  pitanga-website deployment not found"
kubectl rollout restart deployment/northwaysignal-website -n "$NAMESPACE" || echo "⚠️  northwaysignal-website deployment not found"

echo ""
echo "✅ Deployments restarted"
echo ""
echo "📊 Check status:"
echo "   kubectl get pods -n $NAMESPACE -w"
echo ""
echo "🔍 Verify secret:"
echo "   kubectl get secret ghcr-secret -n $NAMESPACE"


