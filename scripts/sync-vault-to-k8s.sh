#!/bin/bash
# Sync secrets from Vault to Kubernetes secrets

set -e

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
VAULT_NAMESPACE="vault"
VAULT_POD=""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Syncing Vault Secrets to Kubernetes ===${NC}"

export KUBECONFIG

# Get Vault pod
VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

if [ -z "$VAULT_POD" ]; then
    echo "Error: Vault pod not found"
    exit 1
fi

# Function to get secret from Vault and create K8s secret
sync_secret() {
    local vault_path=$1
    local vault_key=$2
    local k8s_namespace=$3
    local k8s_secret=$4
    local k8s_key=$5
    
    echo "Syncing $vault_path/$vault_key -> $k8s_namespace/$k8s_secret[$k8s_key]"
    
    # Get secret from Vault
    local value=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
        vault kv get -field="$vault_key" "$vault_path" 2>/dev/null || echo "")
    
    if [ -z "$value" ]; then
        echo -e "${YELLOW}Warning: Secret not found in Vault at $vault_path/$vault_key${NC}"
        return 1
    fi
    
    # Create or update Kubernetes secret
    kubectl create secret generic "$k8s_secret" \
        --from-literal="$k8s_key=$value" \
        -n "$k8s_namespace" \
        --dry-run=client -o yaml | kubectl apply -f - > /dev/null
    
    echo -e "${GREEN}✓ Synced${NC}"
}

# Sync Grafana admin password
echo "Syncing Grafana secrets..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - > /dev/null
sync_secret "secret/monitoring/grafana" "adminPassword" "monitoring" "grafana-admin" "admin-password"

# Sync Flux Git SSH key if exists
FLUX_SSH_KEY=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
    vault kv get -field=sshKey secret/flux/git 2>/dev/null || echo "")

if [ -n "$FLUX_SSH_KEY" ]; then
    echo "Syncing Flux Git secrets..."
    kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f - > /dev/null
    echo "$FLUX_SSH_KEY" | kubectl create secret generic flux-system \
        --from-file=identity=/dev/stdin \
        -n flux-system \
        --dry-run=client -o yaml | kubectl apply -f - > /dev/null
    echo -e "${GREEN}✓ Synced Flux Git SSH key${NC}"
fi

# Sync Canopy secrets
echo "Syncing Canopy secrets..."
kubectl create namespace canopy --dry-run=client -o yaml | kubectl apply -f - > /dev/null

CANOPY_POSTGRES=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
    vault kv get -field=password secret/canopy/postgres 2>/dev/null || echo "")
CANOPY_SECRET_KEY=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
    vault kv get -field=secret-key secret/canopy/app 2>/dev/null || echo "")
CANOPY_DATABASE_URL=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
    vault kv get -field=url secret/canopy/database 2>/dev/null || echo "")

if [ -n "$CANOPY_POSTGRES" ] && [ -n "$CANOPY_SECRET_KEY" ] && [ -n "$CANOPY_DATABASE_URL" ]; then
    kubectl create secret generic canopy-secrets \
        --from-literal=postgres-password="$CANOPY_POSTGRES" \
        --from-literal=secret-key="$CANOPY_SECRET_KEY" \
        --from-literal=database-url="$CANOPY_DATABASE_URL" \
        -n canopy \
        --dry-run=client -o yaml | kubectl apply -f - > /dev/null
    echo -e "${GREEN}✓ Synced Canopy secrets${NC}"
fi

# Sync GHCR token
GHCR_TOKEN=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
    vault kv get -field=token secret/canopy/ghcr-token 2>/dev/null || echo "")

if [ -n "$GHCR_TOKEN" ]; then
    kubectl create secret docker-registry ghcr-secret \
        --docker-server=ghcr.io \
        --docker-username=raolivei \
        --docker-password="$GHCR_TOKEN" \
        -n canopy \
        --dry-run=client -o yaml | kubectl apply -f - > /dev/null
    echo -e "${GREEN}✓ Synced GHCR token${NC}"
fi

echo ""
echo -e "${GREEN}=== Sync Complete ===${NC}"

