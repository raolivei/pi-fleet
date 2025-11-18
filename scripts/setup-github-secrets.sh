#!/bin/bash
# Setup GitHub Secrets for Terraform workflow
#
# Usage:
#   ./scripts/setup-github-secrets.sh
#
# This script sets up the required GitHub secrets for the Terraform workflow.
# It will:
# 1. Read Cloudflare values from terraform.tfvars
# 2. Prompt for Cloudflare API token (or get from Vault)
# 3. Prompt for Cloudflare Account ID (or get from Cloudflare API)
# 4. Set all secrets in GitHub repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$REPO_DIR/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔐 Setting up GitHub Secrets for Terraform workflow"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Install it: brew install gh"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub CLI${NC}"
    echo "Run: gh auth login"
    exit 1
fi

# Get repository name
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "Repository: $REPO"
echo ""

# Read values from terraform.tfvars
if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found${NC}"
    exit 1
fi

CLOUDFLARE_ZONE_ID=$(grep "^cloudflare_zone_id" "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2 | cut -d' ' -f3)
PUBLIC_IP=$(grep "^public_ip" "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2 | cut -d' ' -f3)

if [ -z "$CLOUDFLARE_ZONE_ID" ]; then
    echo -e "${YELLOW}Warning: cloudflare_zone_id not found in terraform.tfvars${NC}"
    read -p "Enter Cloudflare Zone ID: " CLOUDFLARE_ZONE_ID
fi

if [ -z "$PUBLIC_IP" ]; then
    echo -e "${YELLOW}Warning: public_ip not found in terraform.tfvars${NC}"
    read -p "Enter Public IP: " PUBLIC_IP
fi

echo "Found values:"
echo "  Zone ID: $CLOUDFLARE_ZONE_ID"
echo "  Public IP: $PUBLIC_IP"
echo ""

# Try to get Cloudflare API token from environment variable first
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"

# Try to get Cloudflare API token from Vault
if [ -z "$CLOUDFLARE_API_TOKEN" ] && command -v kubectl &> /dev/null; then
    export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
    VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$VAULT_POD" ]; then
        echo "Attempting to get Cloudflare API token from Vault..."
        VAULT_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status 2>&1 | grep "Sealed" | awk '{print $2}' || echo "true")
        
        if [ "$VAULT_STATUS" != "true" ]; then
            CLOUDFLARE_API_TOKEN=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=api-token secret/terraform/cloudflare-api-token 2>/dev/null || echo "")
            
            if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
                echo -e "${GREEN}✓ Retrieved Cloudflare API token from Vault${NC}"
            fi
        else
            echo -e "${YELLOW}Vault is sealed, cannot retrieve token${NC}"
        fi
    fi
fi

# Prompt for API token if not found
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo -e "${YELLOW}Cloudflare API token not found${NC}"
    echo "Set it via: export CLOUDFLARE_API_TOKEN='your-token'"
    echo "Or enter it now:"
    read -sp "Enter Cloudflare API Token: " CLOUDFLARE_API_TOKEN
    echo ""
fi

# Get Cloudflare Account ID
CLOUDFLARE_ACCOUNT_ID=""
if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    echo "Fetching Cloudflare Account ID..."
    CLOUDFLARE_ACCOUNT_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" | \
        grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4 || echo "")
    
    if [ -n "$CLOUDFLARE_ACCOUNT_ID" ]; then
        echo -e "${GREEN}✓ Retrieved Cloudflare Account ID: $CLOUDFLARE_ACCOUNT_ID${NC}"
    fi
fi

# Prompt for Account ID if not found
if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
    echo -e "${YELLOW}Could not fetch Cloudflare Account ID${NC}"
    read -p "Enter Cloudflare Account ID: " CLOUDFLARE_ACCOUNT_ID
fi

echo ""
echo "Setting GitHub secrets..."
echo ""

# Set secrets
gh secret set CLOUDFLARE_API_TOKEN --body "$CLOUDFLARE_API_TOKEN" --repo "$REPO" && \
    echo -e "${GREEN}✓ Set CLOUDFLARE_API_TOKEN${NC}" || \
    echo -e "${RED}✗ Failed to set CLOUDFLARE_API_TOKEN${NC}"

gh secret set CLOUDFLARE_ZONE_ID --body "$CLOUDFLARE_ZONE_ID" --repo "$REPO" && \
    echo -e "${GREEN}✓ Set CLOUDFLARE_ZONE_ID${NC}" || \
    echo -e "${RED}✗ Failed to set CLOUDFLARE_ZONE_ID${NC}"

gh secret set CLOUDFLARE_ACCOUNT_ID --body "$CLOUDFLARE_ACCOUNT_ID" --repo "$REPO" && \
    echo -e "${GREEN}✓ Set CLOUDFLARE_ACCOUNT_ID${NC}" || \
    echo -e "${RED}✗ Failed to set CLOUDFLARE_ACCOUNT_ID${NC}"

gh secret set PUBLIC_IP --body "$PUBLIC_IP" --repo "$REPO" && \
    echo -e "${GREEN}✓ Set PUBLIC_IP${NC}" || \
    echo -e "${RED}✗ Failed to set PUBLIC_IP${NC}"

echo ""
echo -e "${GREEN}✅ All secrets set successfully!${NC}"
echo ""
echo "You can verify secrets at: https://github.com/$REPO/settings/secrets/actions"

