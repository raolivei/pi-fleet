#!/bin/bash
# Setup Vault Policies and Service Tokens
# This script creates per-project policies, generates service tokens, and stores GitHub tokens
# Usage: ./scripts/operations/setup-vault-policies.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
POLICIES_DIR="$SCRIPT_DIR/policies"

echo -e "${BLUE}=== Vault Policies and Service Tokens Setup ===${NC}"
echo ""

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    echo -e "${YELLOW}⚠️  KUBECONFIG not set. Setting to eldertree cluster...${NC}"
    export KUBECONFIG=~/.kube/config-eldertree
fi

# Check if vault pod exists
echo -e "${BLUE}Checking Vault pod status...${NC}"
if ! kubectl get pod vault-0 -n vault &>/dev/null; then
    echo -e "${RED}❌ Vault pod not found!${NC}"
    echo "   Make sure Vault is deployed: kubectl get pods -n vault"
    exit 1
fi

# Check if Vault is unsealed
SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
if [ "$SEAL_STATUS" = "true" ]; then
    echo -e "${RED}❌ Vault is sealed. Please unseal it first:${NC}"
    echo "   ./scripts/operations/unseal-vault.sh"
    exit 1
fi

echo -e "${GREEN}✅ Vault is unsealed${NC}"
echo ""

# Get Vault root token
echo -e "${BLUE}Getting Vault root token...${NC}"
VAULT_ROOT_TOKEN=$(kubectl get secret vault-token -n external-secrets -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

if [ -z "$VAULT_ROOT_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  Root token not found in external-secrets namespace${NC}"
    echo -e "${YELLOW}Please provide the Vault root token:${NC}"
    read -s VAULT_ROOT_TOKEN
    if [ -z "$VAULT_ROOT_TOKEN" ]; then
        echo -e "${RED}❌ Root token is required${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Found root token in external-secrets namespace${NC}"
fi

echo ""

# Function to create policy
create_policy() {
    local policy_name=$1
    local policy_file=$2
    
    echo -e "${BLUE}Creating policy: ${policy_name}...${NC}"
    
    # Read policy content
    if [ ! -f "$policy_file" ]; then
        echo -e "${RED}❌ Policy file not found: ${policy_file}${NC}"
        return 1
    fi
    
    # Create policy in Vault
    kubectl exec -n vault vault-0 -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='${VAULT_ROOT_TOKEN}' && cat > /tmp/policy.hcl" < "$policy_file"
    
    if kubectl exec -n vault vault-0 -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='${VAULT_ROOT_TOKEN}' && vault policy write ${policy_name} /tmp/policy.hcl" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Policy ${policy_name} created${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to create policy ${policy_name}${NC}"
        return 1
    fi
}

# Function to create service token
create_service_token() {
    local token_name=$1
    local policy_name=$2
    local k8s_secret_name=$3
    
    echo -e "${BLUE}Creating service token: ${token_name}...${NC}"
    
    # Generate token with the policy
    TOKEN_OUTPUT=$(kubectl exec -n vault vault-0 -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='${VAULT_ROOT_TOKEN}' && vault token create -policy=${policy_name} -ttl=0 -format=json" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Extract token from JSON output
        SERVICE_TOKEN=$(echo "$TOKEN_OUTPUT" | jq -r '.auth.client_token' 2>/dev/null || echo "")
        
        if [ -n "$SERVICE_TOKEN" ] && [ "$SERVICE_TOKEN" != "null" ]; then
            # Store token in Kubernetes secret
            kubectl create secret generic "$k8s_secret_name" \
                --from-literal=token="$SERVICE_TOKEN" \
                -n external-secrets \
                --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
            
            echo -e "${GREEN}✅ Token ${token_name} created and stored in secret ${k8s_secret_name}${NC}"
            return 0
        else
            echo -e "${RED}❌ Failed to extract token from output${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to create token ${token_name}${NC}"
        return 1
    fi
}

# Function to store GitHub token in Vault
store_ghcr_token() {
    local project=$1
    local token=$2
    local vault_path="secret/${project}/ghcr-token"
    
    echo -e "${BLUE}Storing GHCR token for ${project}...${NC}"
    
    if kubectl exec -n vault vault-0 -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='${VAULT_ROOT_TOKEN}' && vault kv put ${vault_path} token='${token}'" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ GHCR token stored at ${vault_path}${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to store GHCR token for ${project}${NC}"
        return 1
    fi
}

# Create all policies
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 1: Creating Vault Policies${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

create_policy "canopy-policy" "$POLICIES_DIR/canopy-policy.hcl"
create_policy "swimto-policy" "$POLICIES_DIR/swimto-policy.hcl"
create_policy "journey-policy" "$POLICIES_DIR/journey-policy.hcl"
create_policy "nima-policy" "$POLICIES_DIR/nima-policy.hcl"
create_policy "us-law-severity-map-policy" "$POLICIES_DIR/us-law-severity-map-policy.hcl"
create_policy "monitoring-policy" "$POLICIES_DIR/monitoring-policy.hcl"
create_policy "infrastructure-policy" "$POLICIES_DIR/infrastructure-policy.hcl"
create_policy "eso-readonly-policy" "$POLICIES_DIR/eso-readonly-policy.hcl"

echo ""

# Create service tokens
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 2: Creating Service Tokens${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

create_service_token "canopy-token" "canopy-policy" "vault-token-canopy"
create_service_token "swimto-token" "swimto-policy" "vault-token-swimto"
create_service_token "journey-token" "journey-policy" "vault-token-journey"
create_service_token "nima-token" "nima-policy" "vault-token-nima"
create_service_token "us-law-severity-map-token" "us-law-severity-map-policy" "vault-token-us-law-severity-map"
create_service_token "monitoring-token" "monitoring-policy" "vault-token-monitoring"
create_service_token "infrastructure-token" "infrastructure-policy" "vault-token-infrastructure"

echo ""

# Store GitHub tokens
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 3: Storing GitHub Container Registry Tokens${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# GitHub tokens from environment variables or prompt
if [ -n "$SWIMTO_GHCR_TOKEN" ]; then
    store_ghcr_token "swimto" "$SWIMTO_GHCR_TOKEN"
else
    echo -e "${YELLOW}Skipping swimto GHCR token (set SWIMTO_GHCR_TOKEN env var to store)${NC}"
fi

if [ -n "$US_LAW_SEVERITY_MAP_GHCR_TOKEN" ]; then
    store_ghcr_token "us-law-severity-map" "$US_LAW_SEVERITY_MAP_GHCR_TOKEN"
else
    echo -e "${YELLOW}Skipping us-law-severity-map GHCR token (set US_LAW_SEVERITY_MAP_GHCR_TOKEN env var to store)${NC}"
fi

if [ -n "$NIMA_GHCR_TOKEN" ]; then
    store_ghcr_token "nima" "$NIMA_GHCR_TOKEN"
else
    echo -e "${YELLOW}Skipping nima GHCR token (set NIMA_GHCR_TOKEN env var to store)${NC}"
fi

if [ -n "$CANOPY_GHCR_TOKEN" ]; then
    store_ghcr_token "canopy" "$CANOPY_GHCR_TOKEN"
else
    echo -e "${YELLOW}Skipping canopy GHCR token (set CANOPY_GHCR_TOKEN env var to store)${NC}"
fi

echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Created Policies:${NC}"
echo "  - canopy-policy"
echo "  - swimto-policy"
echo "  - journey-policy"
echo "  - nima-policy"
echo "  - us-law-severity-map-policy"
echo "  - monitoring-policy"
echo "  - infrastructure-policy"
echo "  - eso-readonly-policy"
echo ""
echo -e "${GREEN}Created Service Tokens (stored in external-secrets namespace):${NC}"
echo "  - vault-token-canopy"
echo "  - vault-token-swimto"
echo "  - vault-token-journey"
echo "  - vault-token-nima"
echo "  - vault-token-us-law-severity-map"
echo "  - vault-token-monitoring"
echo "  - vault-token-infrastructure"
echo ""
echo -e "${GREEN}Stored GitHub Tokens in Vault:${NC}"
echo "  - secret/swimto/ghcr-token"
echo "  - secret/us-law-severity-map/ghcr-token"
echo "  - secret/nima/ghcr-token"
echo "  - secret/canopy/ghcr-token"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Update project scripts to use their respective tokens"
echo "  2. Update External Secrets Operator to use eso-readonly-policy (optional)"
echo "  3. Test token access by running project-specific scripts"
echo ""

