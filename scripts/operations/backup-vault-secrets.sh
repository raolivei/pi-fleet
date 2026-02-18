#!/bin/bash
set -e

# Backup all Vault secrets to JSON format
# Usage: ./backup-vault-secrets.sh > vault-backup-$(date +%Y%m%d).json

echo "=== Vault Secrets Backup ===" >&2
echo "" >&2

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    echo "⚠️  KUBECONFIG not set. Setting to eldertree cluster..." >&2
    export KUBECONFIG=~/.kube/config-eldertree
fi

# Check if vault pod exists and is ready
if ! kubectl get pod vault-0 -n vault &>/dev/null; then
    echo "❌ Vault pod not found!" >&2
    exit 1
fi

# Check if Vault is unsealed
SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
if [ "$SEAL_STATUS" = "true" ]; then
    echo "❌ Vault is sealed. Please unseal it first: ./scripts/operations/unseal-vault.sh" >&2
    exit 1
fi

echo "Exporting secrets..." >&2

# Define all secret paths
SECRET_PATHS=(
    "secret/monitoring/grafana"
    "secret/pi-fleet/pihole/webpassword"
    "secret/pi-fleet/flux/git"
    "secret/canopy/ghcr-token"
    "secret/canopy/postgres"
    "secret/canopy/app"
    "secret/canopy/database"
    "secret/canopy/questrade"
    "secret/canopy/wise"
    "secret/swimto/database"
    "secret/swimto/postgres"
    "secret/swimto/redis"
    "secret/swimto/app"
    "secret/swimto/api-keys"
    "secret/swimto/oauth"
    "secret/us-law-severity-map/mapbox"
    "secret/journey/postgres"
    "secret/journey/database"
    "secret/pi-fleet/external-dns/tsig-secret"
    "secret/pi-fleet/terraform/cloudflare-api-token"
    "secret/pi-fleet/external-dns/cloudflare-api-token"
    "secret/pi-fleet/cloudflare-tunnel/token"
)

# Start JSON array
echo "{"
echo '  "backup_date": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
echo '  "secrets": {'

FIRST=true
for path in "${SECRET_PATHS[@]}"; do
    # Try to read secret
    SECRET_DATA=$(kubectl exec -n vault vault-0 -- vault kv get -format=json "$path" 2>/dev/null || echo "")
    
    if [ -n "$SECRET_DATA" ]; then
        # Add comma for all but first entry
        if [ "$FIRST" = false ]; then
            echo ","
        fi
        FIRST=false
        
        # Extract just the data part
        SECRET_JSON=$(echo "$SECRET_DATA" | jq -c '.data.data')
        
        echo "    $path ✓" >&2
        echo -n "    \"$path\": $SECRET_JSON"
    else
        echo "    ⚠️  Skipping $path (not found)" >&2
    fi
done

echo ""
echo "  }"
echo "}"

echo "" >&2
echo "✅ Backup complete!" >&2
echo "   Secrets exported to stdout (redirect to file)" >&2

