#!/bin/bash
set -e

# Unseal Vault HA cluster after restart
# This script unseals all Vault pods using keys from Kubernetes secret
# or prompts for manual input if the secret doesn't exist
#
# Usage:
#   ./unseal-vault.sh           # Auto-unseal from K8s secret
#   ./unseal-vault.sh --manual  # Prompt for unseal keys

echo "=== Vault HA Unseal Script ==="
echo ""

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    echo "⚠️  KUBECONFIG not set. Setting to eldertree cluster..."
    export KUBECONFIG=~/.kube/config-eldertree
fi

NAMESPACE="vault"
UNSEAL_SECRET_NAME="vault-unseal-keys"
MANUAL_MODE=false

# Parse arguments
if [ "$1" = "--manual" ] || [ "$1" = "-m" ]; then
    MANUAL_MODE=true
fi

# Function to check if pod is running
is_pod_running() {
    local pod_name=$1
    PHASE=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    [ "$PHASE" = "Running" ]
}

# Function to check if Vault is sealed
is_vault_sealed() {
    local pod_name=$1
    kubectl exec -n "$NAMESPACE" "$pod_name" -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true"
}

# Function to unseal a vault pod
unseal_vault_pod() {
    local pod_name=$1
    local key1=$2
    local key2=$3
    local key3=$4
    
    # Check if pod exists and is running
    if ! is_pod_running "$pod_name"; then
        echo "⚠️  $pod_name is not running, skipping..."
        return 1
    fi
    
    # Check if already unsealed
    if [ "$(is_vault_sealed "$pod_name")" = "false" ]; then
        echo "✅ $pod_name is already unsealed"
        return 0
    fi
    
    echo "🔓 Unsealing $pod_name..."
    
    kubectl exec -n "$NAMESPACE" "$pod_name" -- vault operator unseal "$key1" >/dev/null 2>&1 || true
    kubectl exec -n "$NAMESPACE" "$pod_name" -- vault operator unseal "$key2" >/dev/null 2>&1 || true
    kubectl exec -n "$NAMESPACE" "$pod_name" -- vault operator unseal "$key3" >/dev/null 2>&1 || true
    
    if [ "$(is_vault_sealed "$pod_name")" = "false" ]; then
        echo "✅ $pod_name unsealed successfully"
        return 0
    else
        echo "❌ Failed to unseal $pod_name"
        return 1
    fi
}

# Get list of vault pods
echo "Checking Vault pods..."
VAULT_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault,component=server -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$VAULT_PODS" ]; then
    echo "❌ No Vault pods found!"
    echo "   Make sure Vault is deployed: kubectl get pods -n vault"
    exit 1
fi

echo "Found Vault pods: $VAULT_PODS"
echo ""

# Get unseal keys
if [ "$MANUAL_MODE" = false ]; then
    # Try to get keys from Kubernetes secret
    if kubectl get secret "$UNSEAL_SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        echo "📦 Reading unseal keys from secret: $UNSEAL_SECRET_NAME"
        
        UNSEAL_KEY_1=$(kubectl get secret "$UNSEAL_SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.UNSEAL_KEY_1}' | base64 -d)
        UNSEAL_KEY_2=$(kubectl get secret "$UNSEAL_SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.UNSEAL_KEY_2}' | base64 -d)
        UNSEAL_KEY_3=$(kubectl get secret "$UNSEAL_SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.UNSEAL_KEY_3}' | base64 -d)
        
        if [ -z "$UNSEAL_KEY_1" ] || [ -z "$UNSEAL_KEY_2" ] || [ -z "$UNSEAL_KEY_3" ]; then
            echo "❌ Failed to read unseal keys from secret"
            echo "   Falling back to manual mode..."
            MANUAL_MODE=true
        fi
    else
        echo "⚠️  Unseal secret not found: $UNSEAL_SECRET_NAME"
        echo "   Falling back to manual mode..."
        MANUAL_MODE=true
    fi
fi

if [ "$MANUAL_MODE" = true ]; then
    echo ""
    echo "🔒 Manual unseal mode. You need to provide 3 unseal keys."
    echo "   (Press Ctrl+C to cancel)"
    echo ""
    
    echo "Enter Unseal Key 1:"
    read -s UNSEAL_KEY_1
    echo "Enter Unseal Key 2:"
    read -s UNSEAL_KEY_2
    echo "Enter Unseal Key 3:"
    read -s UNSEAL_KEY_3
    
    if [ -z "$UNSEAL_KEY_1" ] || [ -z "$UNSEAL_KEY_2" ] || [ -z "$UNSEAL_KEY_3" ]; then
        echo "❌ No keys provided. Aborting."
        exit 1
    fi
fi

echo ""

# Unseal each pod
SUCCESS_COUNT=0
TOTAL_COUNT=0

for pod in $VAULT_PODS; do
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    if unseal_vault_pod "$pod" "$UNSEAL_KEY_1" "$UNSEAL_KEY_2" "$UNSEAL_KEY_3"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
done

echo ""
echo "=========================================="
if [ "$SUCCESS_COUNT" -eq "$TOTAL_COUNT" ]; then
    echo "✅ All Vault pods unsealed successfully!"
else
    echo "⚠️  Unsealed $SUCCESS_COUNT of $TOTAL_COUNT pods"
fi
echo "=========================================="
echo ""

# Show cluster status
echo "Vault HA cluster status:"
echo ""

for pod in $VAULT_PODS; do
    if is_pod_running "$pod"; then
        echo "--- $pod ---"
        kubectl exec -n "$NAMESPACE" "$pod" -- vault status 2>/dev/null | grep -E "Seal|HA|Version" || echo "Unable to get status"
        echo ""
    fi
done

# Check Raft peers if possible
LEADER_POD=""
for pod in $VAULT_PODS; do
    if is_pod_running "$pod" && [ "$(is_vault_sealed "$pod")" = "false" ]; then
        IS_LEADER=$(kubectl exec -n "$NAMESPACE" "$pod" -- vault status -format=json 2>/dev/null | jq -r '.is_self' || echo "false")
        if [ "$IS_LEADER" = "true" ]; then
            LEADER_POD=$pod
            break
        fi
    fi
done

if [ -n "$LEADER_POD" ]; then
    echo "Raft cluster members (from $LEADER_POD):"
    kubectl exec -n "$NAMESPACE" "$LEADER_POD" -- vault operator raft list-peers 2>/dev/null || echo "Unable to list Raft peers (may need to login first)"
fi
