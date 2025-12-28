#!/bin/bash
# Setup Cloudflare Tunnel token after Terraform creates the tunnel
#
# Usage:
#   ./scripts/setup-tunnel-token.sh [tunnel-name]
#
# This script:
# 1. Gets the tunnel ID from Terraform output
# 2. Provides instructions to get the token
# 3. Optionally stores it in Vault if provided

set -e

TUNNEL_NAME="${1:-eldertree}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$TERRAFORM_DIR"

# Check if Terraform has been initialized
if [ ! -d ".terraform" ]; then
    echo "Error: Terraform not initialized. Run 'terraform init' first."
    exit 1
fi

# Get tunnel ID from Terraform
echo "Getting tunnel ID from Terraform..."
TUNNEL_ID=$(terraform output -raw cloudflare_tunnel_id 2>/dev/null || echo "")

if [ -z "$TUNNEL_ID" ]; then
    echo "Error: Tunnel not found in Terraform state."
    echo "Make sure you've run 'terraform apply' to create the tunnel."
    exit 1
fi

echo "Tunnel ID: $TUNNEL_ID"
echo ""

# Check if cloudflared is installed
if command -v cloudflared &> /dev/null; then
    echo "cloudflared CLI found. Attempting to get token..."
    echo ""
    echo "To get the token, run:"
    echo "  cloudflared tunnel token $TUNNEL_NAME"
    echo ""
    echo "Or get it from Cloudflare Dashboard:"
    echo "  1. Go to https://dash.cloudflare.com"
    echo "  2. Select eldertree.xyz domain"
    echo "  3. Zero Trust → Networks → Tunnels"
    echo "  4. Click on '$TUNNEL_NAME' tunnel"
    echo "  5. Click 'Configure' next to connector"
    echo "  6. Copy the token"
    echo ""
    
    # Try to get token via cloudflared if possible
    if cloudflared tunnel token "$TUNNEL_NAME" &> /dev/null; then
        TOKEN=$(cloudflared tunnel token "$TUNNEL_NAME" 2>/dev/null || echo "")
        if [ -n "$TOKEN" ]; then
            echo "Token retrieved: ${TOKEN:0:20}..."
            echo ""
            read -p "Store token in Vault? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
                VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
                
                if [ -z "$VAULT_POD" ]; then
                    echo "Error: Vault pod not found"
                    exit 1
                fi
                
                kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/cloudflare-tunnel/token token="$TOKEN"
                echo "✅ Token stored in Vault at secret/pi-fleet/cloudflare-tunnel/token"
            fi
        fi
    else
        echo "Note: cloudflared tunnel token command requires authentication."
        echo "Run 'cloudflared tunnel login' first, or get token from Dashboard."
    fi
else
    echo "cloudflared CLI not found. Get token from Cloudflare Dashboard:"
    echo ""
    echo "  1. Go to https://dash.cloudflare.com"
    echo "  2. Select eldertree.xyz domain"
    echo "  3. Zero Trust → Networks → Tunnels"
    echo "  4. Click on '$TUNNEL_NAME' tunnel"
    echo "  5. Click 'Configure' next to connector"
    echo "  6. Copy the token (starts with eyJ...)"
    echo ""
    echo "Then store it in Vault:"
    echo "  VAULT_POD=\$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')"
    echo "  kubectl exec -n vault \$VAULT_POD -- vault kv put secret/pi-fleet/cloudflare-tunnel/token token=\"YOUR_TOKEN_HERE\""
fi

