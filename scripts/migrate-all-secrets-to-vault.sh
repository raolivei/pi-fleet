#!/bin/bash
# Migrate all existing Kubernetes secrets to Vault

set -e

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
VAULT_NAMESPACE="vault"
VAULT_POD=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Migrating All Secrets to Vault ===${NC}"

export KUBECONFIG

# Get Vault pod
VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

if [ -z "$VAULT_POD" ]; then
    echo -e "${RED}Error: Vault pod not found${NC}"
    exit 1
fi

echo -e "${GREEN}Found Vault pod: $VAULT_POD${NC}"

# Function to write secret to Vault (KV v2)
write_secret() {
    local path=$1
    local key=$2
    local value=$3
    
    echo "  Writing: $path/$key"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
        sh -c "vault kv put $path $key='$value'" > /dev/null 2>&1 || {
        echo -e "${RED}Error: Failed to write secret $path/$key${NC}"
        return 1
    }
}

# Enable KV secrets engine if not already enabled
echo "Enabling KV secrets engine..."
kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
    vault secrets enable -path=secret kv-v2 > /dev/null 2>&1 || echo "KV engine already enabled"

# 1. Migrate Grafana admin password
echo ""
echo -e "${YELLOW}[1/4] Migrating Grafana secrets...${NC}"
GRAFANA_SECRET=$(kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || echo "admin")
write_secret "secret/monitoring/grafana" "adminPassword" "$GRAFANA_SECRET"

# 2. Migrate Flux Git SSH key
echo ""
echo -e "${YELLOW}[2/4] Migrating Flux Git SSH key...${NC}"
FLUX_SSH_KEY=$(kubectl get secret flux-system -n flux-system -o jsonpath='{.data.identity}' 2>/dev/null | base64 -d || echo "")
if [ -n "$FLUX_SSH_KEY" ] && [ "$FLUX_SSH_KEY" != "" ]; then
    # Escape the key for Vault
    FLUX_SSH_KEY_ESCAPED=$(echo "$FLUX_SSH_KEY" | sed "s/'/''/g")
    write_secret "secret/flux/git" "sshKey" "$FLUX_SSH_KEY_ESCAPED"
    echo -e "${GREEN}  ✓ Flux SSH key migrated${NC}"
else
    echo -e "${YELLOW}  ⚠ Flux SSH key not found, skipping${NC}"
fi

# 3. Migrate Canopy secrets
echo ""
echo -e "${YELLOW}[3/4] Migrating Canopy secrets...${NC}"
CANOPY_POSTGRES_PASSWORD=$(kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.postgres-password}' 2>/dev/null | base64 -d || echo "")
CANOPY_SECRET_KEY=$(kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.secret-key}' 2>/dev/null | base64 -d || echo "")
CANOPY_DATABASE_URL=$(kubectl get secret canopy-secrets -n canopy -o jsonpath='{.data.database-url}' 2>/dev/null | base64 -d || echo "")

if [ -n "$CANOPY_POSTGRES_PASSWORD" ]; then
    write_secret "secret/canopy/postgres" "password" "$CANOPY_POSTGRES_PASSWORD"
    echo -e "${GREEN}  ✓ PostgreSQL password migrated${NC}"
fi

if [ -n "$CANOPY_SECRET_KEY" ]; then
    write_secret "secret/canopy/app" "secret-key" "$CANOPY_SECRET_KEY"
    echo -e "${GREEN}  ✓ Application secret key migrated${NC}"
fi

if [ -n "$CANOPY_DATABASE_URL" ]; then
    CANOPY_DATABASE_URL_ESCAPED=$(echo "$CANOPY_DATABASE_URL" | sed "s/'/''/g")
    write_secret "secret/canopy/database" "url" "$CANOPY_DATABASE_URL_ESCAPED"
    echo -e "${GREEN}  ✓ Database URL migrated${NC}"
fi

# 4. Migrate GHCR token
echo ""
echo -e "${YELLOW}[4/4] Migrating GHCR token...${NC}"
GHCR_TOKEN=$(kubectl get secret ghcr-secret -n canopy -o jsonpath='{.data.\.dockerconfigjson}' 2>/dev/null | base64 -d | jq -r '.auths."ghcr.io".password' 2>/dev/null || echo "")
if [ -n "$GHCR_TOKEN" ] && [ "$GHCR_TOKEN" != "null" ] && [ "$GHCR_TOKEN" != "" ]; then
    write_secret "secret/canopy/ghcr-token" "token" "$GHCR_TOKEN"
    echo -e "${GREEN}  ✓ GHCR token migrated${NC}"
else
    echo -e "${YELLOW}  ⚠ GHCR token not found, skipping${NC}"
fi

echo ""
echo -e "${GREEN}=== Migration Complete ===${NC}"
echo ""
echo "Secrets stored in Vault:"
echo "  - secret/monitoring/grafana (adminPassword)"
if [ -n "$FLUX_SSH_KEY" ] && [ "$FLUX_SSH_KEY" != "" ]; then
    echo "  - secret/flux/git (sshKey)"
fi
if [ -n "$CANOPY_POSTGRES_PASSWORD" ]; then
    echo "  - secret/canopy/postgres (password)"
fi
if [ -n "$CANOPY_SECRET_KEY" ]; then
    echo "  - secret/canopy/app (secret-key)"
fi
if [ -n "$CANOPY_DATABASE_URL" ]; then
    echo "  - secret/canopy/database (url)"
fi
if [ -n "$GHCR_TOKEN" ] && [ "$GHCR_TOKEN" != "null" ] && [ "$GHCR_TOKEN" != "" ]; then
    echo "  - secret/canopy/ghcr-token (token)"
fi
echo ""
echo "To verify secrets:"
echo "  kubectl exec -n vault $VAULT_POD -- vault kv list secret/"
echo ""

