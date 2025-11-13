#!/bin/bash
# Sync Canopy secrets from Vault to Kubernetes
# This script reads secrets from Vault and creates/updates Kubernetes secrets

set -e

export KUBECONFIG=~/.kube/config-eldertree
NAMESPACE=canopy

echo "🔐 Syncing Canopy secrets from Vault to Kubernetes..."

# Check if vault CLI is available
if ! command -v vault &> /dev/null; then
    echo "❌ Error: vault CLI not found. Please install Vault CLI or use Vault UI."
    exit 1
fi

# Check if vault is accessible
if ! vault status &> /dev/null; then
    echo "❌ Error: Cannot connect to Vault. Please ensure Vault is accessible."
    echo "   Set VAULT_ADDR if needed: export VAULT_ADDR=https://vault.eldertree.local"
    exit 1
fi

# Get secrets from Vault
echo "📥 Reading secrets from Vault..."
POSTGRES_PASSWORD=$(vault kv get -field=password secret/kv/canopy/postgres 2>/dev/null || echo "")
SECRET_KEY=$(vault kv get -field=secret-key secret/kv/canopy/app 2>/dev/null || echo "")
DATABASE_URL=$(vault kv get -field=url secret/kv/canopy/database 2>/dev/null || echo "")
GHCR_TOKEN=$(vault kv get -field=token secret/kv/canopy/ghcr-token 2>/dev/null || echo "")

# Validate all secrets are present
if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$SECRET_KEY" ] || [ -z "$DATABASE_URL" ] || [ -z "$GHCR_TOKEN" ]; then
    echo "❌ Error: Some secrets are missing from Vault."
    echo "   Please ensure all secrets are stored in Vault (see VAULT_SECRETS.md)"
    exit 1
fi

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create canopy-secrets
echo "📦 Creating canopy-secrets..."
kubectl create secret generic canopy-secrets \
  --namespace $NAMESPACE \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=secret-key="$SECRET_KEY" \
  --from-literal=database-url="$DATABASE_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create ghcr-secret
echo "📦 Creating ghcr-secret..."
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password="$GHCR_TOKEN" \
  --namespace $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secrets synced successfully!"
echo ""
echo "Verification:"
kubectl get secrets -n $NAMESPACE

