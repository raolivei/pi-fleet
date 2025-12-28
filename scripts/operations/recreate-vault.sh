#!/bin/bash
# Backup and recreate Vault from scratch
# This script will:
# 1. Attempt to backup secrets (if unsealed)
# 2. Delete Vault deployment and PVC
# 3. Recreate Vault
# 4. Initialize and unseal
# 5. Restore secrets
# 6. Add tunnel token

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_DIR="$PI_FLEET_DIR/backups/vault-$(date +%Y%m%d-%H%M%S)"
TUNNEL_TOKEN="${TUNNEL_TOKEN:-eyJhIjoiZGY5ZjRhNjdmYWQ2NTMyMWMyYzVkOWM4NjZkMmYyMzkiLCJ0IjoiOTBkYjNiYTMtNWU4NC00MjNmLTk3NDctMjQ5Yjc1NWE2M2EwIiwicyI6Ik5tVTFaalV3WkRNdE9EWTROeTAwTTJZM0xUbG1ObVF0TWpCbE1EZGlZelZpTTJOaSJ9}"

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

echo "🔄 Vault Backup and Recreate Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "📁 Backup directory: $BACKUP_DIR"
echo ""

# Step 1: Attempt to backup secrets
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Attempting to backup secrets..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if kubectl get pod vault-0 -n vault &>/dev/null; then
    SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
    
    if [ "$SEAL_STATUS" = "false" ]; then
        echo "✅ Vault is unsealed, backing up secrets..."
        "$PI_FLEET_DIR/scripts/operations/backup-vault-secrets.sh" > "$BACKUP_DIR/vault-secrets.json" 2>&1
        echo "✅ Backup saved to: $BACKUP_DIR/vault-secrets.json"
    else
        echo "⚠️  Vault is sealed, cannot backup secrets"
        echo "   Secrets will be lost unless you have a previous backup"
        if [ "${NON_INTERACTIVE:-false}" != "true" ]; then
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            echo "   Continuing in non-interactive mode..."
        fi
    fi
else
    echo "⚠️  Vault pod not found, skipping backup"
fi
echo ""

# Step 2: Delete Vault
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Deleting Vault deployment..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Delete HelmRelease (Flux will handle cleanup)
if kubectl get helmrelease vault -n vault &>/dev/null; then
    echo "🗑️  Deleting HelmRelease..."
    kubectl delete helmrelease vault -n vault --wait=false
    echo "✅ HelmRelease deleted"
else
    echo "⚠️  HelmRelease not found"
fi

# Wait for pod to terminate
echo "⏳ Waiting for Vault pod to terminate..."
for i in {1..30}; do
    if ! kubectl get pod vault-0 -n vault &>/dev/null; then
        echo "✅ Vault pod terminated"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "⚠️  Vault pod still exists after 5 minutes, forcing deletion..."
        kubectl delete pod vault-0 -n vault --force --grace-period=0 2>/dev/null || true
    fi
    sleep 10
done
echo ""

# Delete PVC (this will delete all data!)
echo "🗑️  Deleting PVC (this will delete all Vault data)..."
if kubectl get pvc data-vault-0 -n vault &>/dev/null; then
    kubectl delete pvc data-vault-0 -n vault
    echo "✅ PVC deleted"
else
    echo "⚠️  PVC not found"
fi
echo ""

# Step 3: Recreate Vault
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Recreating Vault..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Recreate HelmRelease
echo "🔄 Recreating HelmRelease..."
kubectl apply -f "$PI_FLEET_DIR/clusters/eldertree/secrets-management/vault/helmrelease.yaml"

# Force Flux reconciliation
echo "🔄 Forcing Flux reconciliation..."
flux reconcile helmrelease vault -n vault 2>/dev/null || echo "⚠️  Flux CLI not available, will reconcile automatically"

# Wait for pod to be running
echo "⏳ Waiting for Vault pod to be running..."
for i in {1..60}; do
    PHASE=$(kubectl get pod vault-0 -n vault -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    if [ "$PHASE" = "Running" ]; then
        echo "✅ Vault pod is running"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "❌ Vault pod did not start within 10 minutes"
        kubectl get pods -n vault
        exit 1
    fi
    sleep 10
done
echo ""

# Step 4: Initialize Vault
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Initializing Vault..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if already initialized
INIT_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.initialized' || echo "false")

if [ "$INIT_STATUS" = "true" ]; then
    echo "⚠️  Vault is already initialized"
    echo "   If you want to reinitialize, you'll need to delete the PVC first"
else
    echo "🔐 Initializing Vault..."
    INIT_OUTPUT=$(kubectl exec -n vault vault-0 -- vault operator init -format=json 2>/dev/null)
    
    if [ -z "$INIT_OUTPUT" ]; then
        echo "❌ Failed to initialize Vault"
        exit 1
    fi
    
    # Save unseal keys and root token
    echo "$INIT_OUTPUT" > "$BACKUP_DIR/vault-init.json"
    echo "✅ Vault initialized"
    echo "📋 Credentials saved to: $BACKUP_DIR/vault-init.json"
    echo ""
    
    # Extract and display keys
    echo "🔑 Unseal Keys (save these securely!):"
    echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[]' | nl -v 1 | while read num key; do
        echo "   Key $num: $key"
    done
    echo ""
    
    ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
    echo "🔑 Root Token: $ROOT_TOKEN"
    echo "$ROOT_TOKEN" > "$BACKUP_DIR/vault-root-token.txt"
    echo ""
    echo "⚠️  CRITICAL: Save these credentials securely!"
    echo ""
fi
echo ""

# Step 5: Unseal Vault
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Unsealing Vault..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")

if [ "$SEAL_STATUS" = "false" ]; then
    echo "✅ Vault is already unsealed"
else
    # Try to get keys from backup file
    if [ -f "$BACKUP_DIR/vault-init.json" ]; then
        echo "📋 Using unseal keys from initialization..."
        UNSEAL_KEYS=($(jq -r '.unseal_keys_b64[]' "$BACKUP_DIR/vault-init.json"))
        
        for i in 0 1 2; do
            echo "🔓 Unsealing with key $((i+1))..."
            kubectl exec -n vault vault-0 -- vault operator unseal "${UNSEAL_KEYS[$i]}" &>/dev/null
        done
        
        # Check if unsealed
        SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
        if [ "$SEAL_STATUS" = "false" ]; then
            echo "✅ Vault unsealed successfully"
        else
            echo "❌ Failed to unseal Vault"
            echo "   Please unseal manually: ./scripts/operations/unseal-vault.sh"
        fi
    else
        echo "⚠️  No unseal keys found, please unseal manually:"
        echo "   ./scripts/operations/unseal-vault.sh"
        echo ""
        if [ "${NON_INTERACTIVE:-false}" != "true" ]; then
            read -p "Press Enter after you've unsealed Vault..."
        else
            echo "   Waiting 30 seconds for manual unseal..."
            sleep 30
        fi
    fi
fi
echo ""

# Step 6: Login and restore secrets
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Restoring secrets..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get root token
if [ -f "$BACKUP_DIR/vault-root-token.txt" ]; then
    ROOT_TOKEN=$(cat "$BACKUP_DIR/vault-root-token.txt")
else
    echo "Enter root token:"
    read -s ROOT_TOKEN
fi

# Login to Vault
echo "🔐 Logging in to Vault..."
kubectl exec -n vault vault-0 -- vault login -method=token token="$ROOT_TOKEN" &>/dev/null || {
    echo "❌ Failed to login to Vault"
    echo "   Please login manually: kubectl exec -it -n vault vault-0 -- vault login"
    exit 1
}
echo "✅ Logged in to Vault"
echo ""

# Restore secrets if backup exists
if [ -f "$BACKUP_DIR/vault-secrets.json" ]; then
    echo "📦 Restoring secrets from backup..."
    "$PI_FLEET_DIR/scripts/operations/restore-vault-secrets.sh" "$BACKUP_DIR/vault-secrets.json"
    echo "✅ Secrets restored"
else
    echo "⚠️  No backup found, skipping restore"
fi
echo ""

# Step 7: Add tunnel token
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Adding Cloudflare Tunnel token..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "💾 Storing tunnel token..."
kubectl exec -n vault vault-0 -- vault kv put secret/pi-fleet/cloudflare-tunnel/token token="$TUNNEL_TOKEN"
echo "✅ Tunnel token stored"
echo ""

# Step 8: Update External Secrets Operator token
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 8: Updating External Secrets Operator..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Delete existing secret if it exists
kubectl delete secret vault-token -n external-secrets --ignore-not-found=true

# Create new secret with root token
kubectl create secret generic vault-token \
    --from-literal=token="$ROOT_TOKEN" \
    -n external-secrets

echo "✅ External Secrets Operator token updated"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Vault Recreate Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "   - Backup directory: $BACKUP_DIR"
echo "   - Root token: $ROOT_TOKEN"
echo "   - Tunnel token: Stored in secret/pi-fleet/cloudflare-tunnel/token"
echo ""
echo "🔐 IMPORTANT: Save these credentials securely:"
echo "   - Root token: $ROOT_TOKEN"
if [ -f "$BACKUP_DIR/vault-init.json" ]; then
    echo "   - Unseal keys: $BACKUP_DIR/vault-init.json"
fi
echo ""
echo "📝 Next steps:"
echo "   1. Verify secrets: kubectl exec -n vault vault-0 -- vault kv list secret/"
echo "   2. Check External Secrets: kubectl get externalsecrets -A"
echo "   3. Check tunnel: kubectl get pods -n cloudflare-tunnel"
echo ""

