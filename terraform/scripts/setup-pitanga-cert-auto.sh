#!/bin/bash
# Automated setup script for pitanga.cloud Origin Certificate
#
# Usage:
#   CLOUDFLARE_API_TOKEN="your-token" ./setup-pitanga-cert-auto.sh
#   OR
#   export CLOUDFLARE_API_TOKEN="your-token"
#   ./setup-pitanga-cert-auto.sh

set -e

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VAULT_NAMESPACE="vault"

cd "$TERRAFORM_DIR"

echo "🚀 Pitanga.cloud Origin Certificate Setup (Automated)"
echo "======================================================"
echo ""

# Get API token from environment or Vault
VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

if [ -z "$VAULT_POD" ]; then
    echo "❌ Error: Vault pod not found"
    exit 1
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "📥 Getting API token from Vault..."
    CLOUDFLARE_API_TOKEN=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
        vault kv get -field=api-token secret/pi-fleet/terraform/cloudflare-api-token 2>/dev/null || echo "")
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ Error: Cloudflare API token not found"
    echo ""
    echo "Set it as environment variable:"
    echo "  export CLOUDFLARE_API_TOKEN='your-token'"
    echo ""
    echo "Or store in Vault:"
    echo "  kubectl exec -n vault \$VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token='your-token'"
    exit 1
fi

echo "✅ API token available"
echo ""

# Get Zone ID
echo "🔍 Getting Zone ID for pitanga.cloud..."
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=pitanga.cloud" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" | \
    jq -r '.result[0].id // empty')

if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
    echo "❌ Error: Could not get Zone ID for pitanga.cloud"
    echo ""
    echo "Check:"
    echo "  1. Domain is added to Cloudflare"
    echo "  2. API token has Zone:Read permission"
    echo "  3. Domain name is correct"
    exit 1
fi

echo "✅ Zone ID: $ZONE_ID"
echo ""

# Configure Terraform
export TF_VAR_pitanga_cloud_zone_id="$ZONE_ID"
export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"

# Terraform Plan
echo "📋 Running Terraform plan..."
terraform plan -out=tfplan > /dev/null 2>&1 || {
    echo "⚠️  Plan had warnings/errors, but continuing..."
}

# Check if certificate resource is in plan
if terraform show tfplan 2>/dev/null | grep -q "cloudflare_origin_ca_certificate.pitanga_cloud"; then
    echo "✅ Certificate will be created"
    echo ""
    
    # Terraform Apply
    echo "🚀 Applying Terraform configuration..."
    terraform apply -auto-approve tfplan
    rm -f tfplan
    
    echo ""
    
    # Store in Vault
    echo "💾 Storing certificate in Vault..."
    "$SCRIPT_DIR/store-pitanga-cert-from-terraform.sh"
    
    echo ""
    echo "✅ Setup Complete!"
    echo ""
    echo "Certificate created and stored. Next steps:"
    echo "1. Verify: kubectl get externalsecret pitanga-cloudflare-origin-cert -n pitanga"
    echo "2. Check secret: kubectl get secret pitanga-cloudflare-origin-tls -n pitanga"
    echo "3. Set Cloudflare SSL mode to 'Full (strict)'"
else
    echo "⚠️  Certificate resource not in plan"
    echo ""
    echo "This might mean:"
    echo "  - Certificate already exists"
    echo "  - Zone ID is not set correctly"
    echo "  - API token lacks permissions"
    echo ""
    echo "Checking current state..."
    terraform state list | grep pitanga || echo "No pitanga resources in state"
    rm -f tfplan
fi



