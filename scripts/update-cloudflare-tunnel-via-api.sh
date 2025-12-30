#!/bin/bash
# Update Cloudflare Tunnel configuration via API
# This bypasses Terraform and Vault authentication issues

set -e

# Check for required variables
if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ACCOUNT_ID" ] || [ -z "$TUNNEL_ID" ]; then
    echo "❌ Error: Missing required environment variables"
    echo ""
    echo "Required:"
    echo "  CLOUDFLARE_API_TOKEN - Your Cloudflare API token"
    echo "  CLOUDFLARE_ACCOUNT_ID - Your Cloudflare Account ID"
    echo "  TUNNEL_ID - The Cloudflare Tunnel ID (found in Cloudflare Dashboard)"
    echo ""
    echo "Usage:"
    echo "  export CLOUDFLARE_API_TOKEN='your-token'"
    echo "  export CLOUDFLARE_ACCOUNT_ID='your-account-id'"
    echo "  export TUNNEL_ID='your-tunnel-id'"
    echo "  $0"
    echo ""
    echo "Or get tunnel ID from:"
    echo "  kubectl logs -n cloudflare-tunnel deployment/cloudflared | grep -i 'tunnel.*id'"
    exit 1
fi

# Get current Traefik ClusterIP
echo "🔍 Getting current Traefik ClusterIP..."
TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.spec.clusterIP}')

if [ -z "$TRAEFIK_IP" ]; then
    echo "❌ Error: Could not get Traefik ClusterIP"
    exit 1
fi

echo "✅ Traefik ClusterIP: $TRAEFIK_IP"
echo ""

# Create the tunnel config JSON
CONFIG_JSON=$(cat <<EOF
{
  "config": {
    "ingress": [
      {
        "hostname": "swimto.eldertree.xyz",
        "path": "/",
        "service": "http://${TRAEFIK_IP}:80"
      },
      {
        "hostname": "swimto.eldertree.xyz",
        "path": "/api/*",
        "service": "http://${TRAEFIK_IP}:80"
      },
      {
        "service": "http_status:404"
      }
    ]
  }
}
EOF
)

echo "📤 Updating Cloudflare Tunnel configuration..."
echo ""

# Update tunnel configuration via API
RESPONSE=$(curl -s -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}/configurations" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$CONFIG_JSON")

# Check if update was successful
if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "✅ Tunnel configuration updated successfully!"
    echo ""
    echo "Updated ingress rules:"
    echo "  - swimto.eldertree.xyz/ → http://${TRAEFIK_IP}:80"
    echo "  - swimto.eldertree.xyz/api/* → http://${TRAEFIK_IP}:80"
    echo ""
    echo "⏳ Wait 30-60 seconds for the tunnel to reconnect..."
    echo ""
    echo "Test with: curl -I https://swimto.eldertree.xyz"
else
    echo "❌ Error updating tunnel configuration:"
    echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
    exit 1
fi

