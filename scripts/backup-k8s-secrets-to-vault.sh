#!/bin/bash
# Backup all Kubernetes secrets to Vault
# Run this script to ensure all secrets are stored in Vault

set -e

export KUBECONFIG=~/.kube/config-eldertree

echo "=========================================="
echo "Backing up K8s secrets to Vault"
echo "=========================================="
echo ""

# First, let's see what secrets exist
echo "=== Step 1: Listing all secrets in cluster ==="
kubectl get secrets -A --field-selector type!=kubernetes.io/service-account-token 2>/dev/null | grep -v "helm.sh" | grep -v "sh.flux" | grep -v "kubernetes.io"

echo ""
echo "=== Step 2: Extracting and storing important secrets ==="

# Function to store secret in vault
store_in_vault() {
    local ns=$1
    local name=$2
    local vault_path=$3
    
    echo "Processing: $ns/$name -> vault:$vault_path"
    
    # Get secret data
    data=$(kubectl get secret -n "$ns" "$name" -o json 2>/dev/null | jq -r '.data | to_entries | map("\(.key)=\(.value | @base64d)") | join(" ")')
    
    if [ -n "$data" ] && [ "$data" != "" ]; then
        # Store in vault
        kubectl exec -n vault vault-0 -- vault kv put "secret/$vault_path" $data 2>/dev/null && echo "  ✓ Stored in Vault" || echo "  ✗ Failed to store"
    else
        echo "  ⚠ No data found"
    fi
}

# SwimTO secrets
echo ""
echo "--- SwimTO ---"
store_in_vault "swimto" "swimto-secrets" "swimto/app"
store_in_vault "swimto" "postgres-secrets" "swimto/postgres"
store_in_vault "swimto" "ghcr-secret" "swimto/ghcr"

# Canopy secrets
echo ""
echo "--- Canopy ---"
store_in_vault "canopy" "canopy-secrets" "canopy/app"
store_in_vault "canopy" "postgres-secrets" "canopy/postgres"
store_in_vault "canopy" "ghcr-secret" "canopy/ghcr"

# Pitanga secrets
echo ""
echo "--- Pitanga ---"
store_in_vault "pitanga" "ghcr-secret" "pitanga/ghcr"

# Observability
echo ""
echo "--- Observability ---"
store_in_vault "observability" "grafana-admin" "monitoring/grafana"

# Cert-manager
echo ""
echo "--- Cert-manager ---"
store_in_vault "cert-manager" "cloudflare-api-token-secret" "pi-fleet/cloudflare-api-token"

# External-dns
echo ""
echo "--- External-DNS ---"
store_in_vault "external-dns" "cloudflare-api-token" "pi-fleet/external-dns/cloudflare"

# Cloudflare tunnel
echo ""
echo "--- Cloudflare Tunnel ---"
store_in_vault "cloudflare-tunnel" "tunnel-credentials" "pi-fleet/cloudflare-tunnel/credentials"

# External-secrets store credentials
echo ""
echo "--- External Secrets ---"
store_in_vault "external-secrets" "vault-token" "pi-fleet/external-secrets/vault-token"

echo ""
echo "=== Step 3: Verify Vault contents ==="
echo ""
echo "All secret paths in Vault:"
kubectl exec -n vault vault-0 -- vault kv list -format=json secret/ 2>/dev/null | jq -r '.[]'

echo ""
echo "=========================================="
echo "Backup Complete!"
echo "=========================================="
