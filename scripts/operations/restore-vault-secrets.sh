#!/bin/bash
set -e

# Restore Vault secrets from JSON backup
# Usage: ./restore-vault-secrets.sh vault-backup-20250115.json

if [ -z "$1" ]; then
    echo "Usage: $0 <backup-file.json>"
    echo ""
    echo "Example:"
    echo "  $0 vault-backup-20250115.json"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "=== Vault Secrets Restore ==="
echo ""

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    echo "⚠️  KUBECONFIG not set. Setting to eldertree cluster..."
    export KUBECONFIG=~/.kube/config-eldertree
fi

# Check if vault pod exists and is ready
if ! kubectl get pod vault-0 -n vault &>/dev/null; then
    echo "❌ Vault pod not found!"
    exit 1
fi

# Check if Vault is unsealed
SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
if [ "$SEAL_STATUS" = "true" ]; then
    echo "❌ Vault is sealed. Please unseal it first: ./scripts/operations/unseal-vault.sh"
    exit 1
fi

echo "Reading backup file: $BACKUP_FILE"
BACKUP_DATE=$(jq -r '.backup_date' "$BACKUP_FILE")
echo "Backup date: $BACKUP_DATE"
echo ""

# Check if user is logged in
if ! kubectl exec -n vault vault-0 -- vault token lookup &>/dev/null; then
    echo "❌ Not logged in to Vault. Please login first:"
    echo "   kubectl exec -n vault vault-0 -- vault login"
    exit 1
fi

echo "Restoring secrets..."
echo ""

# Get list of secret paths
SECRET_PATHS=$(jq -r '.secrets | keys[]' "$BACKUP_FILE")

for path in $SECRET_PATHS; do
    echo "Restoring: $path"
    
    # Extract secret data
    SECRET_DATA=$(jq -c ".secrets[\"$path\"]" "$BACKUP_FILE")
    
    # Convert JSON to key=value pairs for vault kv put
    KV_PAIRS=$(echo "$SECRET_DATA" | jq -r 'to_entries | map("\(.key)=\(.value)") | .[]')
    
    # Build vault command
    CMD="vault kv put $path"
    while IFS= read -r pair; do
        CMD="$CMD $pair"
    done <<< "$KV_PAIRS"
    
    # Execute restore
    if kubectl exec -n vault vault-0 -- sh -c "$CMD" &>/dev/null; then
        echo "  ✅ Restored"
    else
        echo "  ❌ Failed to restore"
    fi
done

echo ""
echo "✅ Restore complete!"
echo ""
echo "Next steps:"
echo "1. Verify secrets: kubectl exec -n vault vault-0 -- vault kv list secret/"
echo "2. Restart External Secrets Operator if needed"

