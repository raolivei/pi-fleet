#!/bin/bash
# Get Cloudflare Tunnel token and store it in Vault
#
# Usage:
#   ./scripts/operations/get-and-store-tunnel-token.sh [token]
#   OR
#   ./scripts/operations/get-and-store-tunnel-token.sh  # Will prompt for token or try API

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAFORM_DIR="$PI_FLEET_DIR/terraform"

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

TUNNEL_NAME="eldertree"

# If token provided as argument, use it
if [ -n "$1" ]; then
    TUNNEL_TOKEN="$1"
    echo "📋 Using provided token..."
else
    # Try to get token from Cloudflare API
    echo "🔍 Attempting to get tunnel token from Cloudflare API..."
    
    # Get API token from Vault
    VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$VAULT_POD" ]; then
        echo "❌ Vault pod not found"
        exit 1
    fi
    
    VAULT_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status 2>&1 | grep "Sealed" | awk '{print $2}' || echo "true")
    if [ "$VAULT_STATUS" = "true" ]; then
        echo "❌ Vault is sealed"
        exit 1
    fi
    
    API_TOKEN=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=api-token secret/terraform/cloudflare-api-token 2>/dev/null || echo "")
    
    if [ -z "$API_TOKEN" ]; then
        echo "⚠️  API token not found in Vault, will need manual entry"
    else
        # Get tunnel ID from Terraform
        cd "$TERRAFORM_DIR"
        TUNNEL_ID=$(terraform output -raw cloudflare_tunnel_id 2>/dev/null || echo "")
        
        if [ -n "$TUNNEL_ID" ] && [ -n "$API_TOKEN" ]; then
            # Try to get account ID
            ACCOUNT_ID=$(terraform output -raw cloudflare_account_id 2>/dev/null || echo "")
            
            if [ -z "$ACCOUNT_ID" ]; then
                # Try to get from tfvars or ask user
                echo "⚠️  Account ID not found, need to get token manually"
            else
                echo "🔐 Attempting to get token via Cloudflare API..."
                # Note: Cloudflare API doesn't directly provide tokens, but we can verify tunnel exists
                # Tokens must be obtained from Dashboard or cloudflared CLI
                echo "ℹ️  Cloudflare API doesn't provide tunnel tokens directly"
                echo "   Tokens must be obtained from Dashboard or cloudflared CLI"
            fi
        fi
    fi
    
    # If we don't have token yet, prompt user
    if [ -z "$TUNNEL_TOKEN" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 Get Tunnel Token from Cloudflare Dashboard"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "1. Go to: https://dash.cloudflare.com"
        echo "2. Select your account (eldertree.xyz domain)"
        echo "3. Navigate to: Zero Trust → Networks → Tunnels"
        echo "4. Click on the '$TUNNEL_NAME' tunnel"
        echo "5. Click 'Configure' next to the connector"
        echo "6. Copy the Tunnel Token (starts with eyJ...)"
        echo ""
        
        # Get tunnel ID for reference
        cd "$TERRAFORM_DIR"
        TUNNEL_ID=$(terraform output -raw cloudflare_tunnel_id 2>/dev/null || echo "")
        if [ -n "$TUNNEL_ID" ]; then
            echo "Tunnel ID: $TUNNEL_ID"
            echo ""
        fi
        
        echo "Enter the tunnel token (will not be displayed):"
        read -s TUNNEL_TOKEN
        echo ""
    fi
fi

if [ -z "$TUNNEL_TOKEN" ]; then
    echo "❌ Error: Tunnel token is required"
    exit 1
fi

# Validate token format (should start with eyJ for JWT)
if [[ ! "$TUNNEL_TOKEN" =~ ^eyJ ]]; then
    echo "⚠️  Warning: Token doesn't start with 'eyJ' (expected JWT format)"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Store token in Vault
echo "💾 Storing tunnel token in Vault..."
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$VAULT_POD" ]; then
    echo "❌ Error: Vault pod not found"
    exit 1
fi

VAULT_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status 2>&1 | grep "Sealed" | awk '{print $2}' || echo "true")
if [ "$VAULT_STATUS" = "true" ]; then
    echo "❌ Error: Vault is sealed. Please unseal it first:"
    echo "   cd $PI_FLEET_DIR && ./scripts/operations/unseal-vault.sh"
    exit 1
fi

kubectl exec -n vault $VAULT_POD -- vault kv put secret/cloudflare-tunnel/token token="$TUNNEL_TOKEN"

echo ""
echo "✅ Tunnel token stored successfully in Vault!"
echo ""
echo "The External Secrets Operator will sync this to Kubernetes automatically."
echo "The cloudflared pod should pick it up and start within a few minutes."
echo ""
echo "Check status:"
echo "  kubectl get pods -n cloudflare-tunnel"
echo "  kubectl get externalsecrets -n cloudflare-tunnel"
echo "  kubectl logs -n cloudflare-tunnel deployment/cloudflared -f"
echo ""

