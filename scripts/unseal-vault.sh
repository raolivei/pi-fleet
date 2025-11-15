#!/bin/bash
set -e

# Unseal Vault after restart
# This script prompts for 3 unseal keys and unseals Vault

echo "=== Vault Unseal Script ==="
echo ""

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    echo "⚠️  KUBECONFIG not set. Setting to eldertree cluster..."
    export KUBECONFIG=~/.kube/config-eldertree
fi

# Check if vault pod exists
echo "Checking Vault pod status..."
if ! kubectl get pod vault-0 -n vault &>/dev/null; then
    echo "❌ Vault pod not found!"
    echo "   Make sure Vault is deployed: kubectl get pods -n vault"
    exit 1
fi

# Wait for pod to be ready
echo "Waiting for Vault pod to be ready..."
kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=300s

# Check if already unsealed
SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
if [ "$SEAL_STATUS" = "false" ]; then
    echo "✅ Vault is already unsealed!"
    kubectl exec -n vault vault-0 -- vault status
    exit 0
fi

echo ""
echo "🔒 Vault is sealed. You need to provide 3 unseal keys."
echo "   (Press Ctrl+C to cancel)"
echo ""

# Prompt for 3 unseal keys
for i in 1 2 3; do
    echo "Enter Unseal Key $i:"
    read -s UNSEAL_KEY
    
    if [ -z "$UNSEAL_KEY" ]; then
        echo "❌ No key provided. Aborting."
        exit 1
    fi
    
    echo "Unsealing with key $i..."
    if ! kubectl exec -n vault vault-0 -- vault operator unseal "$UNSEAL_KEY" &>/dev/null; then
        echo "❌ Failed to unseal with key $i"
        exit 1
    fi
    
    # Check seal status
    SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
    
    if [ "$SEAL_STATUS" = "false" ]; then
        echo ""
        echo "✅ Vault successfully unsealed!"
        echo ""
        kubectl exec -n vault vault-0 -- vault status
        exit 0
    else
        echo "   Progress: $i/3 keys provided"
        echo ""
    fi
done

# Check final status
SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
if [ "$SEAL_STATUS" = "false" ]; then
    echo "✅ Vault successfully unsealed!"
    echo ""
    kubectl exec -n vault vault-0 -- vault status
else
    echo "❌ Vault is still sealed. Please check your unseal keys."
    exit 1
fi

