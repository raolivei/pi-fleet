#!/bin/bash
# Store Cloudflare API token in Vault for Terraform and External-DNS
#
# Usage:
#   ./scripts/store-cloudflare-token.sh YOUR_API_TOKEN_HERE
#   OR
#   ./scripts/store-cloudflare-token.sh  # Will prompt for token
#
# NOTE: This script is a convenience wrapper. For better automation, use:
#   ansible-playbook ansible/playbooks/manage-secrets.yml \
#     -e 'secrets=[{path: "secret/terraform/cloudflare-api-token", data: {api-token: "YOUR_TOKEN"}}]'

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Get API token from argument or prompt
if [ -z "$1" ]; then
    echo "Enter your Cloudflare API token (will not be displayed):"
    read -s CLOUDFLARE_API_TOKEN
else
    CLOUDFLARE_API_TOKEN="$1"
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "Error: Cloudflare API token is required"
    exit 1
fi

# Use Ansible playbook for secret management
cd "${PROJECT_ROOT}/ansible"
ansible-playbook playbooks/manage-secrets.yml \
  -e "secrets=[
    {path: 'secret/terraform/cloudflare-api-token', data: {api-token: '${CLOUDFLARE_API_TOKEN}'}},
    {path: 'secret/external-dns/cloudflare-api-token', data: {api-token: '${CLOUDFLARE_API_TOKEN}'}}
  ]" \
  || {
    echo ""
    echo "⚠️  Ansible playbook failed, falling back to direct kubectl commands..."
    echo ""
    
    # Fallback to direct kubectl commands
    export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
    
    VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$VAULT_POD" ]; then
        echo "Error: Vault pod not found"
        exit 1
    fi
    
    VAULT_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status 2>&1 | grep "Sealed" | awk '{print $2}' || echo "true")
    
    if [ "$VAULT_STATUS" = "true" ]; then
        echo "Error: Vault is sealed. Please unseal it first:"
        echo "  ./scripts/unseal-vault.sh"
        exit 1
    fi
    
    kubectl exec -n vault $VAULT_POD -- vault kv put secret/terraform/cloudflare-api-token api-token="$CLOUDFLARE_API_TOKEN"
    kubectl exec -n vault $VAULT_POD -- vault kv put secret/external-dns/cloudflare-api-token api-token="$CLOUDFLARE_API_TOKEN"
    
    echo ""
    echo "✅ Cloudflare API token stored successfully in Vault!"
  }

echo ""
echo "Vault paths:"
echo "  - secret/terraform/cloudflare-api-token"
echo "  - secret/external-dns/cloudflare-api-token"
echo ""
echo "External Secrets Operator will sync these to Kubernetes automatically."

