#!/bin/bash
# Set GitHub secrets for Terraform workflow (non-interactive)
#
# Usage:
#   CLOUDFLARE_API_TOKEN='your-token' ./scripts/set-github-secrets.sh
#   OR
#   ./scripts/set-github-secrets.sh your-api-token-here

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$REPO_DIR/terraform"

# Get API token from argument or environment variable
CLOUDFLARE_API_TOKEN="${1:-${CLOUDFLARE_API_TOKEN:-}}"

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "Error: Cloudflare API token required"
    echo "Usage: CLOUDFLARE_API_TOKEN='token' $0"
    echo "   OR: $0 your-api-token"
    exit 1
fi

# Read values from terraform.tfvars
CLOUDFLARE_ZONE_ID=$(grep "^cloudflare_zone_id" "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2 | cut -d' ' -f3)
PUBLIC_IP=$(grep "^public_ip" "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2 | cut -d' ' -f3)

if [ -z "$CLOUDFLARE_ZONE_ID" ] || [ -z "$PUBLIC_IP" ]; then
    echo "Error: Could not read values from terraform.tfvars"
    exit 1
fi

# Get Account ID from Cloudflare API
echo "Fetching Cloudflare Account ID..."
CLOUDFLARE_ACCOUNT_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4 || echo "")

if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
    echo "Error: Could not fetch Account ID from Cloudflare API"
    echo "Please provide it manually:"
    read -p "Enter Cloudflare Account ID: " CLOUDFLARE_ACCOUNT_ID
fi

# Set secrets
echo "Setting GitHub secrets..."
gh secret set CLOUDFLARE_API_TOKEN --body "$CLOUDFLARE_API_TOKEN" && echo "✓ CLOUDFLARE_API_TOKEN"
gh secret set CLOUDFLARE_ZONE_ID --body "$CLOUDFLARE_ZONE_ID" && echo "✓ CLOUDFLARE_ZONE_ID"
gh secret set CLOUDFLARE_ACCOUNT_ID --body "$CLOUDFLARE_ACCOUNT_ID" && echo "✓ CLOUDFLARE_ACCOUNT_ID"
gh secret set PUBLIC_IP --body "$PUBLIC_IP" && echo "✓ PUBLIC_IP"

echo ""
echo "✅ All secrets set successfully!"

