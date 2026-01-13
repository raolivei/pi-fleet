#!/bin/bash
# Complete setup script for pitanga.cloud Origin Certificate
#
# This script guides you through the entire setup process:
# 1. Stores API token in Vault (if needed)
# 2. Gets Zone ID
# 3. Creates certificate via Terraform
# 4. Stores certificate in Vault

set -e

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VAULT_NAMESPACE="vault"

cd "$TERRAFORM_DIR"

echo "🚀 Pitanga.cloud Origin Certificate Setup"
echo "=========================================="
echo ""

# Step 1: Check/Store API Token
echo "Step 1: Cloudflare API Token"
echo "-----------------------------"

VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

if [ -z "$VAULT_POD" ]; then
    echo "❌ Error: Vault pod not found"
    exit 1
fi

API_TOKEN=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
    vault kv get -field=api-token secret/pi-fleet/terraform/cloudflare-api-token 2>/dev/null || echo "")

if [ -z "$API_TOKEN" ]; then
    echo "⚠️  API token not found in Vault"
    echo ""
    echo "Please provide your Cloudflare API token."
    echo "The token must have these permissions:"
    echo "  - Zone → Zone → Read"
    echo "  - Zone → DNS → Edit"
    echo "  - Zone → SSL and Certificates → Edit (required for Origin Certificates)"
    echo ""
    read -sp "Enter Cloudflare API token: " API_TOKEN
    echo ""
    echo ""
    
    if [ -z "$API_TOKEN" ]; then
        echo "❌ Error: API token is required"
        exit 1
    fi
    
    echo "💾 Storing API token in Vault..."
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
        vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token="$API_TOKEN"
    echo "✅ Token stored"
else
    echo "✅ API token found in Vault"
fi

echo ""

# Step 2: Get Zone ID
echo "Step 2: Get Zone ID for pitanga.cloud"
echo "--------------------------------------"

ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=pitanga.cloud" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" | \
    jq -r '.result[0].id // empty')

if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
    echo "❌ Error: Could not get Zone ID for pitanga.cloud"
    echo ""
    echo "Possible reasons:"
    echo "  1. Domain not added to Cloudflare account"
    echo "  2. API token doesn't have permission to read zones"
    echo "  3. Domain name is incorrect"
    echo ""
    echo "You can get the Zone ID manually:"
    echo "  - Cloudflare Dashboard → Select pitanga.cloud → Overview → Zone ID"
    echo ""
    read -p "Enter Zone ID manually (or press Enter to exit): " ZONE_ID
    
    if [ -z "$ZONE_ID" ]; then
        exit 1
    fi
else
    echo "✅ Zone ID found: $ZONE_ID"
fi

echo ""

# Step 3: Set Zone ID for Terraform
echo "Step 3: Configure Terraform"
echo "---------------------------"

export TF_VAR_pitanga_cloud_zone_id="$ZONE_ID"
export TF_VAR_cloudflare_api_token="$API_TOKEN"

echo "Zone ID set: $ZONE_ID"
echo ""

# Step 4: Terraform Plan
echo "Step 4: Terraform Plan"
echo "----------------------"

terraform plan -out=tfplan

echo ""
read -p "Review the plan above. Continue with apply? (y/N): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

echo ""

# Step 5: Terraform Apply
echo "Step 5: Terraform Apply"
echo "-----------------------"

terraform apply tfplan
rm -f tfplan

echo ""

# Step 6: Store Certificate in Vault
echo "Step 6: Store Certificate in Vault"
echo "----------------------------------"

"$SCRIPT_DIR/store-pitanga-cert-from-terraform.sh"

echo ""
echo "✅ Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Verify ExternalSecret sync: kubectl get externalsecret pitanga-cloudflare-origin-cert -n pitanga"
echo "2. Check Kubernetes secret: kubectl get secret pitanga-cloudflare-origin-tls -n pitanga"
echo "3. Set Cloudflare SSL mode to 'Full (strict)' in Cloudflare Dashboard"
echo "4. Test: curl -v https://pitanga.cloud"



