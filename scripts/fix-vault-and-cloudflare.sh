#!/bin/bash
# Fix Vault and Cloudflare External-DNS setup
# This script unseals Vault and creates the Cloudflare API token secret if needed

set -e

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

echo "=== Fix Vault and Cloudflare External-DNS ==="
echo ""

# Step 1: Unseal Vault
echo "Step 1: Unsealing Vault..."
if [ -f "./scripts/unseal-vault.sh" ]; then
    ./scripts/unseal-vault.sh
else
    echo "⚠️  unseal-vault.sh not found. Please unseal Vault manually:"
    echo "   ./scripts/unseal-vault.sh"
    exit 1
fi

# Step 2: Check if Cloudflare API token secret exists
echo ""
echo "Step 2: Checking if Cloudflare API token exists in Vault..."
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

if kubectl exec -n vault $VAULT_POD -- vault kv get secret/external-dns/cloudflare-api-token &>/dev/null; then
    echo "✅ Cloudflare API token already exists in Vault"
else
    echo "⚠️  Cloudflare API token not found in Vault"
    echo ""
    echo "To create it, run:"
    echo "  ./scripts/store-cloudflare-token.sh YOUR_API_TOKEN"
    echo ""
    echo "Or manually:"
    echo "  VAULT_POD=\$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')"
    echo "  kubectl exec -n vault \$VAULT_POD -- vault kv put secret/external-dns/cloudflare-api-token api-token=YOUR_API_TOKEN"
    echo ""
    read -p "Do you want to create it now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "./scripts/store-cloudflare-token.sh" ]; then
            ./scripts/store-cloudflare-token.sh
        else
            echo "⚠️  store-cloudflare-token.sh not found. Please create the secret manually."
            exit 1
        fi
    else
        echo "⚠️  Skipping Cloudflare token creation. External-DNS Cloudflare will remain suspended."
    fi
fi

# Step 3: Wait for External Secrets to sync
echo ""
echo "Step 3: Waiting for External Secrets to sync..."
echo "Checking ExternalSecret status..."
sleep 5

if kubectl get secret external-dns-cloudflare-secret -n external-dns &>/dev/null; then
    echo "✅ external-dns-cloudflare-secret exists"
    
    # Step 4: Unsuspend HelmRelease
    echo ""
    echo "Step 4: Unsuspending external-dns-cloudflare HelmRelease..."
    kubectl patch helmrelease external-dns-cloudflare -n external-dns --type=json -p='[{"op": "remove", "path": "/spec/suspend"}]'
    
    echo ""
    echo "✅ Done! External-DNS Cloudflare should start shortly."
    echo "   Check status: kubectl get pods -n external-dns"
else
    echo "⚠️  external-dns-cloudflare-secret not found yet. External Secrets Operator may need more time."
    echo "   Check status: kubectl get externalsecret external-dns-cloudflare-secret -n external-dns"
    echo ""
    echo "Once the secret is synced, unsuspend the HelmRelease:"
    echo "   kubectl patch helmrelease external-dns-cloudflare -n external-dns --type=json -p='[{\"op\": \"remove\", \"path\": \"/spec/suspend\"}]'"
fi

