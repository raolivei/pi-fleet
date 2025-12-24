#!/bin/bash
# Get Cloudflare Tunnel token for Kubernetes deployment
#
# Usage:
#   ./scripts/get-tunnel-token.sh [tunnel-name]
#
# This script helps you get the tunnel token after Terraform creates the tunnel.
# The token is required for the Kubernetes cloudflared deployment.

set -e

TUNNEL_NAME="${1:-eldertree}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$TERRAFORM_DIR"

echo "Getting Cloudflare Tunnel token for: $TUNNEL_NAME"
echo ""
echo "After Terraform creates the tunnel, you can get the token in two ways:"
echo ""
echo "Method 1: Cloudflare Dashboard"
echo "  1. Go to https://dash.cloudflare.com"
echo "  2. Select your domain (eldertree.xyz)"
echo "  3. Go to Zero Trust → Networks → Tunnels"
echo "  4. Click on the '$TUNNEL_NAME' tunnel"
echo "  5. Click 'Configure' next to your connector"
echo "  6. Copy the token (starts with eyJ...)"
echo ""
echo "Method 2: cloudflared CLI"
echo "  1. Install cloudflared: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
echo "  2. Run: cloudflared tunnel token $TUNNEL_NAME"
echo ""
echo "Method 3: Terraform Output (if available)"
TUNNEL_ID=$(terraform output -raw cloudflare_tunnel_id 2>/dev/null || echo "")
if [ -n "$TUNNEL_ID" ]; then
    echo "  Tunnel ID: $TUNNEL_ID"
    echo "  Use this ID to get token from Cloudflare Dashboard"
else
    echo "  Tunnel not created yet. Run 'terraform apply' first."
fi
echo ""
echo "After getting the token, store it in Vault:"
echo ""
echo "  # Method 1: Using root token (requires Vault root token)"
echo "  export KUBECONFIG=~/.kube/config-eldertree"
echo "  kubectl exec -n vault vault-0 -- sh -c \"VAULT_TOKEN='YOUR_ROOT_TOKEN' vault kv put secret/cloudflare-tunnel/token token='YOUR_TOKEN_HERE'\""
echo ""
echo "  # Method 2: Using infrastructure service token (if available)"
echo "  VAULT_TOKEN=\$(kubectl get secret vault-token-infrastructure -n external-secrets -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)"
echo "  if [ -n \"\$VAULT_TOKEN\" ]; then"
echo "    kubectl exec -n vault vault-0 -- sh -c \"VAULT_TOKEN='\${VAULT_TOKEN}' vault kv put secret/cloudflare-tunnel/token token='YOUR_TOKEN_HERE'\""
echo "  fi"
echo ""
echo "After updating Vault, the ExternalSecret will automatically sync within 1 hour,"
echo "or you can force a refresh by deleting the Kubernetes secret:"
echo ""
echo "  kubectl delete secret cloudflared-credentials -n cloudflare-tunnel"
echo "  kubectl delete pod -n cloudflare-tunnel -l app=cloudflared"
echo ""

