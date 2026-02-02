#!/bin/bash
# OpenClaw Setup Script for Eldertree
# Stores credentials in Vault and verifies deployment
# Usage: ./scripts/setup-openclaw.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  OpenClaw Setup for Eldertree Cluster${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found${NC}"
    exit 1
fi

# Check Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$VAULT_POD" ]; then
    echo -e "${RED}Error: Vault pod not found${NC}"
    exit 1
fi

# Check if Vault is unsealed
SEAL_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
if [ "$SEAL_STATUS" = "true" ]; then
    echo -e "${RED}Error: Vault is sealed. Please unseal it first:${NC}"
    echo "   ./scripts/operations/unseal-vault.sh"
    exit 1
fi

# Check if logged in
if ! kubectl exec -n vault $VAULT_POD -- vault token lookup &>/dev/null; then
    echo -e "${YELLOW}Not logged in to Vault. Please login:${NC}"
    kubectl exec -it -n vault $VAULT_POD -- vault login
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# Get credentials
echo -e "${BLUE}Enter your credentials:${NC}"
echo ""

read -p "Telegram Bot Token: " -s TELEGRAM_TOKEN
echo ""

read -p "Google AI Studio API Key: " -s GEMINI_API_KEY
echo ""
echo ""

# Generate gateway token (random 32-character hex string)
echo -e "${YELLOW}Generating gateway authentication token...${NC}"
GATEWAY_TOKEN=$(openssl rand -hex 32)
echo -e "${GREEN}✓ Gateway token generated${NC}"
echo ""

# Validate inputs
if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}Error: Both Telegram token and Gemini API key are required${NC}"
    exit 1
fi

# Store secrets in Vault
echo -e "${YELLOW}Storing secrets in Vault...${NC}"

# Store Telegram token
kubectl exec -n vault $VAULT_POD -- vault kv put secret/openclaw/telegram token="$TELEGRAM_TOKEN"
echo -e "${GREEN}✓ Telegram token stored at secret/openclaw/telegram${NC}"

# Store Gemini API key
kubectl exec -n vault $VAULT_POD -- vault kv put secret/openclaw/gemini api-key="$GEMINI_API_KEY"
echo -e "${GREEN}✓ Gemini API key stored at secret/openclaw/gemini${NC}"

# Store Gateway token
kubectl exec -n vault $VAULT_POD -- vault kv put secret/openclaw/gateway token="$GATEWAY_TOKEN"
echo -e "${GREEN}✓ Gateway token stored at secret/openclaw/gateway${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Secrets stored successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verify secrets
echo -e "${YELLOW}Verifying secrets...${NC}"
kubectl exec -n vault $VAULT_POD -- vault kv get -field=token secret/openclaw/telegram > /dev/null && echo -e "${GREEN}✓ Telegram token verified${NC}"
kubectl exec -n vault $VAULT_POD -- vault kv get -field=api-key secret/openclaw/gemini > /dev/null && echo -e "${GREEN}✓ Gemini API key verified${NC}"
kubectl exec -n vault $VAULT_POD -- vault kv get -field=token secret/openclaw/gateway > /dev/null && echo -e "${GREEN}✓ Gateway token verified${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Next Steps${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. OpenClaw is already enabled in clusters/eldertree/kustomization.yaml"
echo ""
echo "2. Commit any changes and push to trigger Flux deployment:"
echo "   cd $PI_FLEET_DIR"
echo "   git add ."
echo "   git commit -m 'feat(openclaw): configure OpenClaw deployment'"
echo "   git push"
echo ""
echo "3. Flux will automatically deploy OpenClaw"
echo ""
echo "4. Monitor deployment:"
echo "   kubectl get pods -n openclaw -w"
echo ""
echo "5. Check logs:"
echo "   kubectl logs -n openclaw -l app=openclaw -f"
echo ""
echo "6. Access OpenClaw:"
echo "   - Web UI: https://openclaw.eldertree.local"
echo "   - Telegram: Message @eldertree_assistant_bot"
echo ""
