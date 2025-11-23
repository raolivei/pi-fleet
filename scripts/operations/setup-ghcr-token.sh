#!/bin/bash
set -e

# Setup GHCR token in Vault for swimTO
# This script helps you create a GitHub Personal Access Token and store it in Vault

echo "=== GitHub Container Registry (GHCR) Token Setup ==="
echo ""

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    echo "⚠️  KUBECONFIG not set. Setting to eldertree cluster..."
    export KUBECONFIG=~/.kube/config-eldertree
fi

# Check if vault pod exists
echo "Checking Vault pod status..."
if ! kubectl get pod vault-0 -n vault &>/dev/null; then
    echo "❌ Vault pod not found!"
    echo "   Make sure Vault is deployed: kubectl get pods -n vault"
    exit 1
fi

# Check if Vault is unsealed
SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
if [ "$SEAL_STATUS" = "true" ]; then
    echo "❌ Vault is sealed!"
    echo "   Please unseal Vault first: ./scripts/operations/unseal-vault.sh"
    exit 1
fi

echo "✅ Vault is unsealed"
echo ""

# Check if token already exists
EXISTING_TOKEN=$(kubectl exec -n vault vault-0 -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && vault kv get -field=token secret/swimto/ghcr-token 2>/dev/null" || echo "")
if [ -n "$EXISTING_TOKEN" ]; then
    echo "⚠️  Token already exists in Vault at secret/swimto/ghcr-token"
    read -p "Do you want to update it? (y/n): " UPDATE_TOKEN
    if [ "$UPDATE_TOKEN" != "y" ]; then
        echo "Keeping existing token."
        exit 0
    fi
fi

echo "📋 Step 1: Create GitHub Personal Access Token"
echo ""
echo "Go to: https://github.com/settings/tokens/new"
echo ""
echo "Settings:"
echo "  - Note: SwimTO GHCR Push"
echo "  - Expiration: 90 days (or custom)"
echo "  - Scopes (check these):"
echo "    ✅ write:packages"
echo "    ✅ read:packages"
echo "    ✅ delete:packages (optional)"
echo ""
echo "Click 'Generate token' and COPY IT IMMEDIATELY!"
echo ""
read -p "Press Enter when you have the token ready..."

echo ""
echo "📋 Step 2: Enter your GitHub Personal Access Token"
read -s -p "Enter token (ghp_...): " GHCR_TOKEN
echo ""

if [ -z "$GHCR_TOKEN" ]; then
    echo "❌ No token provided. Exiting."
    exit 1
fi

# Validate token format
if [[ ! "$GHCR_TOKEN" =~ ^ghp_ ]]; then
    echo "⚠️  Warning: Token doesn't start with 'ghp_'. Are you sure this is correct?"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
fi

echo ""
echo "📋 Step 3: Storing token in Vault..."

# Get root token (try to get from environment or prompt)
if [ -z "$VAULT_TOKEN" ]; then
    # Try to get from secret
    VAULT_TOKEN=$(kubectl get secret vault-token -n external-secrets -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || echo "")
fi

if [ -z "$VAULT_TOKEN" ]; then
    echo "Enter Vault root token (or press Enter to use 'root' for dev mode):"
    read -s VAULT_TOKEN
    VAULT_TOKEN=${VAULT_TOKEN:-root}
fi

# Store token in Vault
kubectl exec -n vault vault-0 -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='${VAULT_TOKEN}' && vault kv put secret/swimto/ghcr-token token='${GHCR_TOKEN}'" || {
    echo "❌ Failed to store token in Vault"
    echo "   Make sure Vault is unsealed and you have the correct root token"
    exit 1
}

echo "✅ Token stored in Vault at secret/swimto/ghcr-token"
echo ""

# Trigger ExternalSecret sync
echo "📋 Step 4: Triggering ExternalSecret sync..."
kubectl annotate externalsecret ghcr-secret -n swimto force-sync="$(date +%s)" --overwrite 2>/dev/null || true

echo "✅ ExternalSecret sync triggered"
echo ""

# Wait a moment for sync
echo "⏳ Waiting for secret sync..."
sleep 5

# Verify secret exists
if kubectl get secret ghcr-secret -n swimto &>/dev/null; then
    echo "✅ Secret 'ghcr-secret' exists in swimto namespace"
    
    # Check if it has the right format
    SECRET_TYPE=$(kubectl get secret ghcr-secret -n swimto -o jsonpath='{.type}')
    if [ "$SECRET_TYPE" = "kubernetes.io/dockerconfigjson" ]; then
        echo "✅ Secret has correct type (dockerconfigjson)"
    else
        echo "⚠️  Secret type is $SECRET_TYPE (expected kubernetes.io/dockerconfigjson)"
    fi
else
    echo "⚠️  Secret 'ghcr-secret' not found yet. It should sync automatically."
    echo "   Check with: kubectl get externalsecret ghcr-secret -n swimto"
fi

echo ""
echo "📋 Step 5: Verify ImageRepository can authenticate"
echo ""
echo "Checking ImageRepository status..."
kubectl get imagerepositories -n swimto

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Wait for ImageRepository to sync (may take a few minutes)"
echo "  2. Check status: kubectl get imagerepositories -n swimto"
echo "  3. Check ImagePolicy: kubectl get imagepolicies -n swimto"
echo ""
echo "If authentication fails, verify:"
echo "  - Token has 'read:packages' scope"
echo "  - Repository is accessible: https://github.com/raolivei/swimTO/packages"
echo ""

