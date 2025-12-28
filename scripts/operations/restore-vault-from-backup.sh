#!/bin/bash
# Restore Vault from existing backups
# This script:
# 1. Initializes Vault (if needed) using backup init file
# 2. Unseals Vault using backup keys
# 3. Restores secrets from backup JSON file
# Usage: ./restore-vault-from-backup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default backup locations
BACKUP_FILE="${BACKUP_FILE:-$PI_FLEET_DIR/vault-backup-20251115-163624.json}"
INIT_FILE="${INIT_FILE:-$PI_FLEET_DIR/backups/vault-20251123-032746/vault-init.json}"
ROOT_TOKEN_FILE="${ROOT_TOKEN_FILE:-$PI_FLEET_DIR/backups/vault-20251123-032746/vault-root-token.txt}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔄 Restore Vault from Backup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check cluster connectivity
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}❌ Cannot connect to cluster${NC}"
    exit 1
fi

# Check if Vault pod exists
if ! kubectl get pod vault-0 -n vault &>/dev/null; then
    echo -e "${RED}❌ Vault pod not found!${NC}"
    echo "   Please install Vault first: ./scripts/operations/install-vault-helm.sh"
    exit 1
fi

# Wait for pod to be running
echo -e "${YELLOW}[1/4] Waiting for Vault pod...${NC}"
kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=300s || {
    echo -e "${RED}❌ Vault pod not ready${NC}"
    exit 1
}
echo -e "${GREEN}✅ Vault pod is ready${NC}"
echo ""

# Check initialization status
echo -e "${YELLOW}[2/4] Checking Vault initialization...${NC}"
INIT_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.initialized' || echo "false")

if [ "$INIT_STATUS" = "false" ]; then
    echo -e "${YELLOW}⚠️  Vault is not initialized${NC}"
    
    if [ ! -f "$INIT_FILE" ]; then
        echo -e "${RED}❌ Init file not found: $INIT_FILE${NC}"
        echo "   Vault needs to be initialized. Run:"
        echo "   kubectl exec -n vault vault-0 -- vault operator init"
        exit 1
    fi
    
    echo -e "${RED}⚠️  WARNING: Vault is not initialized but init file exists${NC}"
    echo "   This means Vault was recreated. You need to initialize it first."
    echo "   The init file contains keys from a previous instance."
    echo ""
    echo "   Options:"
    echo "   1. Initialize with new keys (old data will be lost):"
    echo "      kubectl exec -n vault vault-0 -- vault operator init"
    echo "   2. If you have the PVC from the old instance, restore it"
    echo ""
    exit 1
else
    echo -e "${GREEN}✅ Vault is initialized${NC}"
fi
echo ""

# Unseal Vault
echo -e "${YELLOW}[3/4] Unsealing Vault...${NC}"
SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")

if [ "$SEAL_STATUS" = "false" ]; then
    echo -e "${GREEN}✅ Vault is already unsealed${NC}"
else
    if [ ! -f "$INIT_FILE" ]; then
        echo -e "${RED}❌ Init file not found: $INIT_FILE${NC}"
        echo "   Cannot unseal automatically. Use: ./scripts/operations/unseal-vault.sh"
        exit 1
    fi
    
    echo "   Using unseal keys from: $INIT_FILE"
    UNSEAL_KEYS=($(jq -r '.unseal_keys_b64[]' "$INIT_FILE"))
    
    if [ ${#UNSEAL_KEYS[@]} -lt 3 ]; then
        echo -e "${RED}❌ Not enough unseal keys in file${NC}"
        exit 1
    fi
    
    echo "   Unsealing with keys 1, 2, and 3..."
    for i in 0 1 2; do
        echo "   Unsealing with key $((i+1))..."
        kubectl exec -n vault vault-0 -- vault operator unseal "${UNSEAL_KEYS[$i]}" &>/dev/null
    done
    
    # Verify
    SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
    if [ "$SEAL_STATUS" = "false" ]; then
        echo -e "${GREEN}✅ Vault unsealed${NC}"
    else
        echo -e "${RED}❌ Failed to unseal Vault${NC}"
        echo "   The keys may be from a different Vault instance"
        exit 1
    fi
fi
echo ""

# Login and restore secrets
echo -e "${YELLOW}[4/4] Restoring secrets...${NC}"

if [ ! -f "$ROOT_TOKEN_FILE" ]; then
    echo -e "${RED}❌ Root token file not found: $ROOT_TOKEN_FILE${NC}"
    echo "   Please provide root token manually"
    read -s -p "Enter root token: " ROOT_TOKEN
    echo ""
else
    ROOT_TOKEN=$(cat "$ROOT_TOKEN_FILE")
fi

# Login
echo "   Logging in to Vault..."
kubectl exec -n vault vault-0 -- vault login -method=token token="$ROOT_TOKEN" &>/dev/null || {
    echo -e "${RED}❌ Failed to login${NC}"
    echo "   Token may be from a different Vault instance"
    exit 1
}
echo -e "${GREEN}✅ Logged in${NC}"

# Restore secrets
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${YELLOW}⚠️  Backup file not found: $BACKUP_FILE${NC}"
    echo "   Skipping secret restore"
else
    echo "   Restoring secrets from: $BACKUP_FILE"
    "$PI_FLEET_DIR/scripts/operations/restore-vault-secrets.sh" "$BACKUP_FILE"
fi
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Restore Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📝 Next steps:"
echo "   1. Verify secrets: kubectl exec -n vault vault-0 -- vault kv list secret/"
echo "   2. Update External Secrets Operator token if needed"
echo ""


