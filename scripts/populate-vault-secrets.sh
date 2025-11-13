#!/bin/bash
# Populate Vault with secrets for pi-fleet projects

set -e

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
VAULT_NAMESPACE="vault"
VAULT_POD=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Populating Vault Secrets ===${NC}"

# Check kubeconfig
if [ ! -f "$KUBECONFIG" ]; then
    echo -e "${RED}Error: Kubeconfig not found at $KUBECONFIG${NC}"
    echo "Set KUBECONFIG environment variable or ensure ~/.kube/config-eldertree exists"
    exit 1
fi

export KUBECONFIG

# Get Vault pod name
echo "Finding Vault pod..."
VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$VAULT_POD" ]; then
    echo -e "${RED}Error: Vault pod not found in namespace $VAULT_NAMESPACE${NC}"
    echo "Ensure Vault is deployed and running"
    exit 1
fi

echo -e "${GREEN}Found Vault pod: $VAULT_POD${NC}"

# Function to write secret to Vault (KV v2)
write_secret() {
    local path=$1
    local key=$2
    local value=$3
    
    echo "Writing secret: $path/$key"
    # KV v2 syntax: vault kv put path key=value
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

# Prompt for Grafana admin password
echo ""
echo -e "${YELLOW}Grafana Admin Password${NC}"
read -sp "Enter Grafana admin password (default: admin): " GRAFANA_PASSWORD
GRAFANA_PASSWORD=${GRAFANA_PASSWORD:-admin}
echo ""

# Store Grafana secrets
echo "Storing Grafana secrets..."
write_secret "secret/monitoring/grafana" "adminPassword" "$GRAFANA_PASSWORD"

# Prompt for other project secrets
echo ""
echo -e "${YELLOW}Flux Git SSH Key${NC}"
read -sp "Enter Flux Git SSH private key (or press Enter to skip): " FLUX_SSH_KEY
if [ -n "$FLUX_SSH_KEY" ]; then
    echo ""
    write_secret "secret/flux/git" "sshKey" "$FLUX_SSH_KEY"
fi

# Add more secrets as needed
echo ""
echo -e "${GREEN}=== Secrets stored in Vault ===${NC}"
echo ""
echo "Secret paths:"
echo "  - secret/monitoring/grafana (adminPassword)"
if [ -n "$FLUX_SSH_KEY" ]; then
    echo "  - secret/flux/git (sshKey)"
fi
echo ""
echo "To view secrets:"
echo "  kubectl exec -n vault $VAULT_POD -- vault kv get secret/monitoring/grafana"
echo ""
echo -e "${GREEN}Done!${NC}"

