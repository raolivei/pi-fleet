#!/bin/bash
set -e

# Initialize Vault HA cluster with Raft storage
# This script should be run ONCE after deploying Vault in HA mode
#
# Prerequisites:
# - Vault HA HelmRelease deployed
# - All 3 vault pods running (may be in not-ready state)
# - kubectl configured for eldertree cluster
#
# What this script does:
# 1. Waits for vault-0 to be running
# 2. Initializes the Vault cluster (generates unseal keys)
# 3. Unseals vault-0
# 4. Waits for vault-1 and vault-2 to join the Raft cluster
# 5. Unseals vault-1 and vault-2
# 6. Creates a Kubernetes secret with unseal keys for auto-unseal
# 7. Verifies the Raft cluster is healthy

echo "=== Vault HA Initialization Script ==="
echo ""

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    echo "⚠️  KUBECONFIG not set. Setting to eldertree cluster..."
    export KUBECONFIG=~/.kube/config-eldertree
fi

NAMESPACE="vault"
UNSEAL_SECRET_NAME="vault-unseal-keys"

# Function to wait for pod to be running
wait_for_pod_running() {
    local pod_name=$1
    local timeout=${2:-300}
    
    echo "Waiting for $pod_name to be running..."
    for i in $(seq 1 $timeout); do
        PHASE=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [ "$PHASE" = "Running" ]; then
            echo "✅ $pod_name is running"
            return 0
        fi
        if [ $((i % 10)) -eq 0 ]; then
            echo "   Still waiting... ($i/${timeout}s)"
        fi
        sleep 1
    done
    echo "❌ Timeout waiting for $pod_name to be running"
    return 1
}

# Function to check if Vault is initialized
is_vault_initialized() {
    local pod_name=$1
    kubectl exec -n "$NAMESPACE" "$pod_name" -- vault status -format=json 2>/dev/null | jq -r '.initialized' || echo "false"
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
    
    echo "Unsealing $pod_name..."
    
    kubectl exec -n "$NAMESPACE" "$pod_name" -- vault operator unseal "$key1" >/dev/null 2>&1
    kubectl exec -n "$NAMESPACE" "$pod_name" -- vault operator unseal "$key2" >/dev/null 2>&1
    kubectl exec -n "$NAMESPACE" "$pod_name" -- vault operator unseal "$key3" >/dev/null 2>&1
    
    if [ "$(is_vault_sealed "$pod_name")" = "false" ]; then
        echo "✅ $pod_name unsealed successfully"
        return 0
    else
        echo "❌ Failed to unseal $pod_name"
        return 1
    fi
}

# Step 1: Wait for vault-0 to be running
echo ""
echo "=== Step 1: Waiting for vault-0 ==="
wait_for_pod_running "vault-0" 300

# Step 2: Check if already initialized
echo ""
echo "=== Step 2: Checking initialization status ==="
if [ "$(is_vault_initialized vault-0)" = "true" ]; then
    echo "⚠️  Vault is already initialized!"
    echo "   If you need to reinitialize, delete the PVCs first."
    
    # Check if unseal secret exists
    if kubectl get secret "$UNSEAL_SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        echo "   Unseal keys are stored in secret: $UNSEAL_SECRET_NAME"
        echo ""
        echo "To unseal all pods, run:"
        echo "   ./scripts/operations/unseal-vault.sh"
    fi
    exit 0
fi

# Step 3: Initialize Vault
echo ""
echo "=== Step 3: Initializing Vault cluster ==="
echo "This will generate new unseal keys and root token."
echo ""

INIT_OUTPUT=$(kubectl exec -n "$NAMESPACE" vault-0 -- vault operator init -format=json)

# Extract keys and token
UNSEAL_KEY_1=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[2]')
UNSEAL_KEY_4=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[3]')
UNSEAL_KEY_5=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[4]')
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')

echo "✅ Vault initialized successfully!"
echo ""
echo "=========================================="
echo "⚠️  CRITICAL: SAVE THESE KEYS SECURELY! ⚠️"
echo "=========================================="
echo ""
echo "Unseal Key 1: $UNSEAL_KEY_1"
echo "Unseal Key 2: $UNSEAL_KEY_2"
echo "Unseal Key 3: $UNSEAL_KEY_3"
echo "Unseal Key 4: $UNSEAL_KEY_4"
echo "Unseal Key 5: $UNSEAL_KEY_5"
echo ""
echo "Root Token:   $ROOT_TOKEN"
echo ""
echo "=========================================="
echo ""

# Step 4: Create Kubernetes secret with unseal keys
echo "=== Step 4: Creating Kubernetes secret for auto-unseal ==="

kubectl create secret generic "$UNSEAL_SECRET_NAME" \
    -n "$NAMESPACE" \
    --from-literal=UNSEAL_KEY_1="$UNSEAL_KEY_1" \
    --from-literal=UNSEAL_KEY_2="$UNSEAL_KEY_2" \
    --from-literal=UNSEAL_KEY_3="$UNSEAL_KEY_3" \
    --from-literal=UNSEAL_KEY_4="$UNSEAL_KEY_4" \
    --from-literal=UNSEAL_KEY_5="$UNSEAL_KEY_5" \
    --from-literal=ROOT_TOKEN="$ROOT_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Unseal keys stored in secret: $UNSEAL_SECRET_NAME"
echo ""

# Step 5: Unseal vault-0
echo "=== Step 5: Unsealing vault-0 ==="
unseal_vault_pod "vault-0" "$UNSEAL_KEY_1" "$UNSEAL_KEY_2" "$UNSEAL_KEY_3"

# Give the Raft cluster time to stabilize
echo ""
echo "Waiting for Raft cluster to stabilize..."
sleep 10

# Step 6: Wait for and unseal vault-1
echo ""
echo "=== Step 6: Waiting for vault-1 to join ==="
wait_for_pod_running "vault-1" 120

echo "Waiting for vault-1 to join Raft cluster..."
sleep 5

unseal_vault_pod "vault-1" "$UNSEAL_KEY_1" "$UNSEAL_KEY_2" "$UNSEAL_KEY_3"

# Step 7: Wait for and unseal vault-2
echo ""
echo "=== Step 7: Waiting for vault-2 to join ==="
wait_for_pod_running "vault-2" 120

echo "Waiting for vault-2 to join Raft cluster..."
sleep 5

unseal_vault_pod "vault-2" "$UNSEAL_KEY_1" "$UNSEAL_KEY_2" "$UNSEAL_KEY_3"

# Step 8: Verify Raft cluster health
echo ""
echo "=== Step 8: Verifying Raft cluster ==="

# Login with root token
kubectl exec -n "$NAMESPACE" vault-0 -- vault login "$ROOT_TOKEN" >/dev/null 2>&1

# Check Raft peers
echo ""
echo "Raft cluster members:"
kubectl exec -n "$NAMESPACE" vault-0 -- vault operator raft list-peers

echo ""
echo "Vault status on all nodes:"
for pod in vault-0 vault-1 vault-2; do
    echo ""
    echo "--- $pod ---"
    kubectl exec -n "$NAMESPACE" "$pod" -- vault status 2>/dev/null || echo "Unable to get status"
done

# Step 9: Update the External Secrets vault-token
echo ""
echo "=== Step 9: Updating External Secrets vault-token ==="

kubectl create secret generic vault-token \
    -n external-secrets \
    --from-literal=token="$ROOT_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ vault-token secret updated in external-secrets namespace"

# Step 10: Enable KV secrets engine
echo ""
echo "=== Step 10: Enabling KV secrets engine ==="
kubectl exec -n "$NAMESPACE" vault-0 -- vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV engine already enabled"

echo ""
echo "=========================================="
echo "✅ Vault HA cluster initialization complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Save the unseal keys and root token in a secure location (password manager, etc.)"
echo "2. Restore secrets from backup:"
echo "   ./scripts/operations/restore-vault-secrets.sh vault-backup-pre-ha-clean.json"
echo "3. Verify External Secrets are syncing:"
echo "   kubectl get externalsecrets -A"
echo ""
echo "The unseal keys are stored in Kubernetes secret '$UNSEAL_SECRET_NAME'"
echo "for auto-unseal purposes. To manually unseal after restart:"
echo "   ./scripts/operations/unseal-vault.sh"
echo ""
