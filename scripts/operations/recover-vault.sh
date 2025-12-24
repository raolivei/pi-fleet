#!/bin/bash
# Comprehensive Vault Recovery Script
# This script attempts to recover Vault in various states:
# - Vault not running: Ensures deployment exists
# - Vault sealed: Unseals using backup keys
# - Vault not initialized: Initializes and unseals
# - Secrets missing: Restores from backup
#
# Usage: ./recover-vault.sh [--backup-file <file>] [--init-file <file>] [--non-interactive]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default backup locations
DEFAULT_BACKUP_FILE="$PI_FLEET_DIR/vault-backup-20251115-163624.json"
DEFAULT_INIT_FILE="$PI_FLEET_DIR/backups/vault-20251123-032746/vault-init.json"
DEFAULT_ROOT_TOKEN_FILE="$PI_FLEET_DIR/backups/vault-20251123-032746/vault-root-token.txt"

# Parse arguments
BACKUP_FILE="$DEFAULT_BACKUP_FILE"
INIT_FILE="$DEFAULT_INIT_FILE"
ROOT_TOKEN_FILE="$DEFAULT_ROOT_TOKEN_FILE"
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --backup-file)
            BACKUP_FILE="$2"
            shift 2
            ;;
        --init-file)
            INIT_FILE="$2"
            shift 2
            ;;
        --root-token-file)
            ROOT_TOKEN_FILE="$2"
            shift 2
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--backup-file <file>] [--init-file <file>] [--root-token-file <file>] [--non-interactive]"
            exit 1
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔄 Vault Recovery Script${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Check cluster connectivity
echo -e "${YELLOW}[1/8] Checking cluster connectivity...${NC}"
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}❌ Cannot connect to cluster${NC}"
    echo "   Please ensure:"
    echo "   1. KUBECONFIG is set correctly: export KUBECONFIG=~/.kube/config-eldertree"
    echo "   2. You can reach the cluster: kubectl cluster-info"
    exit 1
fi
echo -e "${GREEN}✅ Cluster accessible${NC}"
echo ""

# Step 2: Check/Ensure Vault namespace exists
echo -e "${YELLOW}[2/8] Checking Vault namespace...${NC}"
if ! kubectl get namespace vault &>/dev/null; then
    echo "Creating vault namespace..."
    kubectl create namespace vault
    echo -e "${GREEN}✅ Namespace created${NC}"
else
    echo -e "${GREEN}✅ Namespace exists${NC}"
fi
echo ""

# Step 3: Check/Ensure Vault pod is running
echo -e "${YELLOW}[3/8] Checking Vault pod status...${NC}"
VAULT_POD_EXISTS=false
if kubectl get pod vault-0 -n vault &>/dev/null; then
    VAULT_POD_EXISTS=true
    PHASE=$(kubectl get pod vault-0 -n vault -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    
    if [ "$PHASE" = "Running" ]; then
        echo -e "${GREEN}✅ Vault pod is running${NC}"
    else
        echo -e "${YELLOW}⚠️  Vault pod exists but not running (phase: $PHASE)${NC}"
        echo "   Waiting for pod to be ready..."
        kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=300s || {
            echo -e "${RED}❌ Vault pod did not become ready${NC}"
            kubectl describe pod vault-0 -n vault
            exit 1
        }
        echo -e "${GREEN}✅ Vault pod is ready${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Vault pod not found${NC}"
    echo "   Checking if HelmRelease exists..."
    
    if kubectl get helmrelease vault -n vault &>/dev/null; then
        echo "   HelmRelease exists, waiting for deployment..."
        # Force Flux reconciliation
        flux reconcile helmrelease vault -n vault 2>/dev/null || echo "   (Flux CLI not available, will reconcile automatically)"
        
        echo "   Waiting for Vault pod to be created..."
        for i in {1..60}; do
            if kubectl get pod vault-0 -n vault &>/dev/null; then
                echo -e "${GREEN}✅ Vault pod created${NC}"
                VAULT_POD_EXISTS=true
                break
            fi
            if [ $i -eq 60 ]; then
                echo -e "${RED}❌ Vault pod not created after 10 minutes${NC}"
                echo "   Please check HelmRelease status: kubectl describe helmrelease vault -n vault"
                exit 1
            fi
            sleep 10
        done
        
        # Wait for pod to be running
        kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=300s || {
            echo -e "${RED}❌ Vault pod did not become ready${NC}"
            exit 1
        }
    else
        echo -e "${YELLOW}⚠️  HelmRelease not found${NC}"
        echo "   Applying HelmRelease..."
        if [ -f "$PI_FLEET_DIR/clusters/eldertree/secrets-management/vault/helmrelease.yaml" ]; then
            kubectl apply -f "$PI_FLEET_DIR/clusters/eldertree/secrets-management/vault/helmrelease.yaml"
            echo "   Waiting for Vault to be deployed..."
            for i in {1..60}; do
                if kubectl get pod vault-0 -n vault &>/dev/null; then
                    echo -e "${GREEN}✅ Vault pod created${NC}"
                    VAULT_POD_EXISTS=true
                    break
                fi
                if [ $i -eq 60 ]; then
                    echo -e "${RED}❌ Vault pod not created after 10 minutes${NC}"
                    exit 1
                fi
                sleep 10
            done
            kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=300s || {
                echo -e "${RED}❌ Vault pod did not become ready${NC}"
                exit 1
            }
        else
            echo -e "${RED}❌ HelmRelease file not found${NC}"
            echo "   Expected: $PI_FLEET_DIR/clusters/eldertree/secrets-management/vault/helmrelease.yaml"
            exit 1
        fi
    fi
fi
echo ""

# Step 4: Check Vault initialization status
echo -e "${YELLOW}[4/8] Checking Vault initialization status...${NC}"
INIT_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.initialized' || echo "false")
SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")

if [ "$INIT_STATUS" = "false" ]; then
    echo -e "${YELLOW}⚠️  Vault is not initialized${NC}"
    
    if [ ! -f "$INIT_FILE" ]; then
        echo -e "${YELLOW}   Initialization file not found, will initialize now...${NC}"
        echo "   This will generate NEW unseal keys and root token!"
        
        if [ "$NON_INTERACTIVE" != "true" ]; then
            read -p "Continue with initialization? (y/n) " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        
        # Create backup directory
        BACKUP_DIR="$PI_FLEET_DIR/backups/vault-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        echo "   Initializing Vault..."
        INIT_OUTPUT=$(kubectl exec -n vault vault-0 -- vault operator init -format=json 2>/dev/null)
        
        if [ -z "$INIT_OUTPUT" ]; then
            echo -e "${RED}❌ Failed to initialize Vault${NC}"
            exit 1
        fi
        
        # Save credentials
        echo "$INIT_OUTPUT" > "$BACKUP_DIR/vault-init.json"
        ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
        echo "$ROOT_TOKEN" > "$BACKUP_DIR/vault-root-token.txt"
        
        echo -e "${GREEN}✅ Vault initialized${NC}"
        echo -e "${YELLOW}⚠️  CRITICAL: Save these credentials!${NC}"
        echo "   Backup directory: $BACKUP_DIR"
        echo "   Root token: $ROOT_TOKEN"
        echo ""
        echo "   Unseal Keys:"
        echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[]' | nl -v 1 | while read num key; do
            echo "     Key $num: $key"
        done
        echo ""
        
        # Update variables for unsealing
        INIT_FILE="$BACKUP_DIR/vault-init.json"
        ROOT_TOKEN_FILE="$BACKUP_DIR/vault-root-token.txt"
    else
        echo -e "${RED}❌ Vault is not initialized but init file exists${NC}"
        echo "   This means Vault was recreated. You may need to:"
        echo "   1. Delete the PVC: kubectl delete pvc data-vault-0 -n vault"
        echo "   2. Recreate Vault"
        echo "   3. Then run this script again"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Vault is initialized${NC}"
fi
echo ""

# Step 5: Unseal Vault
echo -e "${YELLOW}[5/8] Checking Vault seal status...${NC}"
SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")

if [ "$SEAL_STATUS" = "false" ]; then
    echo -e "${GREEN}✅ Vault is already unsealed${NC}"
else
    echo -e "${YELLOW}⚠️  Vault is sealed${NC}"
    
    if [ -f "$INIT_FILE" ]; then
        echo "   Using unseal keys from: $INIT_FILE"
        UNSEAL_KEYS=($(jq -r '.unseal_keys_b64[]' "$INIT_FILE"))
        
        if [ ${#UNSEAL_KEYS[@]} -lt 3 ]; then
            echo -e "${RED}❌ Not enough unseal keys in file (need at least 3)${NC}"
            exit 1
        fi
        
        echo "   Unsealing with keys 1, 2, and 3..."
        for i in 0 1 2; do
            echo "   Unsealing with key $((i+1))..."
            if kubectl exec -n vault vault-0 -- vault operator unseal "${UNSEAL_KEYS[$i]}" &>/dev/null; then
                echo -e "   ${GREEN}✅ Key $((i+1)) applied${NC}"
            else
                echo -e "${RED}❌ Failed to apply key $((i+1))${NC}"
                exit 1
            fi
        done
        
        # Verify unsealed
        SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
        if [ "$SEAL_STATUS" = "false" ]; then
            echo -e "${GREEN}✅ Vault unsealed successfully${NC}"
        else
            echo -e "${RED}❌ Vault is still sealed after unsealing${NC}"
            echo "   Please check unseal keys and try manually:"
            echo "   ./scripts/operations/unseal-vault.sh"
            exit 1
        fi
    else
        echo -e "${RED}❌ Init file not found: $INIT_FILE${NC}"
        echo "   Cannot unseal automatically. Please unseal manually:"
        echo "   ./scripts/operations/unseal-vault.sh"
        exit 1
    fi
fi
echo ""

# Step 6: Login to Vault
echo -e "${YELLOW}[6/8] Logging in to Vault...${NC}"
if [ -f "$ROOT_TOKEN_FILE" ]; then
    ROOT_TOKEN=$(cat "$ROOT_TOKEN_FILE")
else
    echo -e "${RED}❌ Root token file not found: $ROOT_TOKEN_FILE${NC}"
    echo "   Please provide root token manually"
    if [ "$NON_INTERACTIVE" != "true" ]; then
        read -s -p "Enter root token: " ROOT_TOKEN
        echo ""
    else
        exit 1
    fi
fi

# Check if already logged in
if kubectl exec -n vault vault-0 -- vault token lookup &>/dev/null; then
    echo -e "${GREEN}✅ Already logged in${NC}"
else
    echo "   Logging in..."
    if kubectl exec -n vault vault-0 -- vault login -method=token token="$ROOT_TOKEN" &>/dev/null; then
        echo -e "${GREEN}✅ Logged in successfully${NC}"
    else
        echo -e "${RED}❌ Failed to login${NC}"
        echo "   Please login manually: kubectl exec -it -n vault vault-0 -- vault login"
        exit 1
    fi
fi
echo ""

# Step 7: Restore secrets from backup
echo -e "${YELLOW}[7/8] Checking secrets...${NC}"
if [ -f "$BACKUP_FILE" ]; then
    echo "   Backup file found: $BACKUP_FILE"
    
    # Check if secrets exist
    SECRET_COUNT=$(kubectl exec -n vault vault-0 -- vault kv list secret/ 2>/dev/null | grep -v "^Keys" | grep -v "^---" | wc -l || echo "0")
    
    if [ "$SECRET_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No secrets found in Vault${NC}"
        echo "   Restoring from backup..."
        
        if [ -f "$PI_FLEET_DIR/scripts/operations/restore-vault-secrets.sh" ]; then
            "$PI_FLEET_DIR/scripts/operations/restore-vault-secrets.sh" "$BACKUP_FILE"
            echo -e "${GREEN}✅ Secrets restored${NC}"
        else
            echo -e "${RED}❌ Restore script not found${NC}"
            echo "   Expected: $PI_FLEET_DIR/scripts/operations/restore-vault-secrets.sh"
        fi
    else
        echo -e "${GREEN}✅ Secrets exist in Vault ($SECRET_COUNT paths)${NC}"
        echo "   Skipping restore (secrets already present)"
        echo "   To force restore, delete secrets first or use restore script manually"
    fi
else
    echo -e "${YELLOW}⚠️  Backup file not found: $BACKUP_FILE${NC}"
    echo "   Skipping secret restore"
fi
echo ""

# Step 8: Update External Secrets Operator token
echo -e "${YELLOW}[8/8] Updating External Secrets Operator token...${NC}"
if [ -f "$ROOT_TOKEN_FILE" ]; then
    ROOT_TOKEN=$(cat "$ROOT_TOKEN_FILE")
    
    # Delete existing secret if it exists
    kubectl delete secret vault-token -n external-secrets --ignore-not-found=true &>/dev/null
    
    # Create new secret
    if kubectl create secret generic vault-token \
        --from-literal=token="$ROOT_TOKEN" \
        -n external-secrets &>/dev/null; then
        echo -e "${GREEN}✅ External Secrets Operator token updated${NC}"
    else
        echo -e "${YELLOW}⚠️  Failed to update token (namespace may not exist)${NC}"
        echo "   You can create it manually:"
        echo "   kubectl create secret generic vault-token --from-literal=token=\"$ROOT_TOKEN\" -n external-secrets"
    fi
else
    echo -e "${YELLOW}⚠️  Root token file not found, skipping token update${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Vault Recovery Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📋 Summary:"
echo "   - Vault pod: $(kubectl get pod vault-0 -n vault -o jsonpath='{.status.phase}' 2>/dev/null || echo 'unknown')"
echo "   - Initialized: $(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.initialized' || echo 'unknown')"
echo "   - Sealed: $(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo 'unknown')"
echo ""

if [ -f "$INIT_FILE" ]; then
    echo "🔐 Credentials:"
    echo "   - Init file: $INIT_FILE"
    if [ -f "$ROOT_TOKEN_FILE" ]; then
        echo "   - Root token: $(cat "$ROOT_TOKEN_FILE")"
    fi
    echo ""
fi

echo "📝 Next steps:"
echo "   1. Verify Vault status: kubectl exec -n vault vault-0 -- vault status"
echo "   2. List secrets: kubectl exec -n vault vault-0 -- vault kv list secret/"
echo "   3. Check External Secrets: kubectl get externalsecrets -A"
echo "   4. Access Vault UI: kubectl port-forward -n vault svc/vault 8200:8200"
echo ""

