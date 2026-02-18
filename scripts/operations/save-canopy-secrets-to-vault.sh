#!/bin/bash
# Save all Canopy secrets to Vault.
# Uses env vars if set; otherwise prompts for each value.
# Optional secrets (Questrade, Wise, GHCR) can be skipped by pressing Enter.
#
# Usage:
#   ./save-canopy-secrets-to-vault.sh
#   CANOPY_POSTGRES_PASSWORD=xxx CANOPY_WISE_API_TOKEN=yyy ./save-canopy-secrets-to-vault.sh
#
# Env vars (all optional; script will prompt if unset):
#   CANOPY_POSTGRES_PASSWORD   - PostgreSQL password for canopy DB
#   CANOPY_SECRET_KEY          - App secret key (e.g. Flask/FastAPI)
#   CANOPY_DATABASE_URL        - Full DB URL (default built from postgres password)
#   CANOPY_QUESTRADE_REFRESH_TOKEN - Questrade API refresh token (optional)
#   CANOPY_WISE_API_TOKEN      - Wise API token (optional)
#   CANOPY_GHCR_TOKEN          - GitHub token for GHCR image pulls (optional)
#
# Non-interactive: set CANOPY_NONINTERACTIVE=1 and only the env vars you want to write.
# Only secrets with values are written; no prompts.

set -e

NONINTERACTIVE="${CANOPY_NONINTERACTIVE:-0}"

if [ -z "$KUBECONFIG" ]; then
    export KUBECONFIG=~/.kube/config-eldertree
fi

VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -z "$VAULT_POD" ]; then
    echo "Error: No Vault pod found in namespace $VAULT_NAMESPACE. Is Vault running?"
    exit 1
fi

put() {
    local path="$1"
    shift
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- vault kv put "$path" "$@"
}

echo "=== Save Canopy secrets to Vault ==="
echo "Vault pod: $VAULT_POD"
echo ""

# Required: postgres password
if [ -n "$CANOPY_POSTGRES_PASSWORD" ]; then
    put secret/canopy/postgres password="$CANOPY_POSTGRES_PASSWORD"
    echo "  ✓ secret/canopy/postgres"
elif [ "$NONINTERACTIVE" != "1" ]; then
    read -sp "Canopy Postgres password: " CANOPY_POSTGRES_PASSWORD
    echo
    if [ -n "$CANOPY_POSTGRES_PASSWORD" ]; then
        put secret/canopy/postgres password="$CANOPY_POSTGRES_PASSWORD"
        echo "  ✓ secret/canopy/postgres"
    fi
fi

# Required: app secret key
if [ -n "$CANOPY_SECRET_KEY" ]; then
    put secret/canopy/app secret-key="$CANOPY_SECRET_KEY"
    echo "  ✓ secret/canopy/app"
elif [ "$NONINTERACTIVE" != "1" ]; then
    read -sp "Canopy app secret-key (or Enter to generate): " CANOPY_SECRET_KEY
    echo
    if [ -z "$CANOPY_SECRET_KEY" ]; then
        CANOPY_SECRET_KEY=$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)
        echo "  (generated secret-key)"
    fi
    put secret/canopy/app secret-key="$CANOPY_SECRET_KEY"
    echo "  ✓ secret/canopy/app"
fi

# Required: database URL (default from postgres password)
if [ -n "$CANOPY_DATABASE_URL" ]; then
    put secret/canopy/database url="$CANOPY_DATABASE_URL"
    echo "  ✓ secret/canopy/database"
elif [ -n "$CANOPY_POSTGRES_PASSWORD" ]; then
    CANOPY_DATABASE_URL="postgresql+psycopg://canopy:${CANOPY_POSTGRES_PASSWORD}@canopy-postgres:5432/canopy"
    put secret/canopy/database url="$CANOPY_DATABASE_URL"
    echo "  ✓ secret/canopy/database (from postgres password)"
elif [ "$NONINTERACTIVE" != "1" ]; then
    read -p "Canopy database URL (postgresql+psycopg://canopy:PASSWORD@canopy-postgres:5432/canopy): " CANOPY_DATABASE_URL
    if [ -n "$CANOPY_DATABASE_URL" ]; then
        put secret/canopy/database url="$CANOPY_DATABASE_URL"
        echo "  ✓ secret/canopy/database"
    fi
fi

# Optional: Questrade
if [ -n "$CANOPY_QUESTRADE_REFRESH_TOKEN" ]; then
    put secret/canopy/questrade refresh-token="$CANOPY_QUESTRADE_REFRESH_TOKEN"
    echo "  ✓ secret/canopy/questrade"
elif [ "$NONINTERACTIVE" != "1" ]; then
    read -sp "Questrade refresh-token (optional, Enter to skip): " CANOPY_QUESTRADE_REFRESH_TOKEN
    echo
    if [ -n "$CANOPY_QUESTRADE_REFRESH_TOKEN" ]; then
        put secret/canopy/questrade refresh-token="$CANOPY_QUESTRADE_REFRESH_TOKEN"
        echo "  ✓ secret/canopy/questrade"
    fi
fi

# Optional: Wise
if [ -n "$CANOPY_WISE_API_TOKEN" ]; then
    put secret/canopy/wise api-token="$CANOPY_WISE_API_TOKEN"
    echo "  ✓ secret/canopy/wise"
elif [ "$NONINTERACTIVE" != "1" ]; then
    read -sp "Wise API token (optional, Enter to skip): " CANOPY_WISE_API_TOKEN
    echo
    if [ -n "$CANOPY_WISE_API_TOKEN" ]; then
        put secret/canopy/wise api-token="$CANOPY_WISE_API_TOKEN"
        echo "  ✓ secret/canopy/wise"
    fi
fi

# Optional: GHCR (for image pulls)
if [ -n "$CANOPY_GHCR_TOKEN" ]; then
    put secret/canopy/ghcr-token token="$CANOPY_GHCR_TOKEN"
    echo "  ✓ secret/canopy/ghcr-token"
elif [ "$NONINTERACTIVE" != "1" ]; then
    read -sp "GHCR token for image pulls (optional, Enter to skip): " CANOPY_GHCR_TOKEN
    echo
    if [ -n "$CANOPY_GHCR_TOKEN" ]; then
        put secret/canopy/ghcr-token token="$CANOPY_GHCR_TOKEN"
        echo "  ✓ secret/canopy/ghcr-token"
    fi
fi

echo ""
echo "Done. External Secrets Operator will sync to K8s secret canopy-secrets (refreshInterval 24h or force with: kubectl annotate externalsecret canopy-secrets -n canopy force-sync=\$(date +%s) --overwrite)"
