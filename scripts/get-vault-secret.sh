#!/bin/bash
# Helper script to get secrets from Vault
# Usage: ./get-vault-secret.sh <secret-path> <key-name>
# Example: ./get-vault-secret.sh secret/canopy/ghcr-token token

set -e

SECRET_PATH="${1}"
KEY_NAME="${2}"

if [ -z "$SECRET_PATH" ] || [ -z "$KEY_NAME" ]; then
    echo "Usage: $0 <secret-path> <key-name>"
    echo "Example: $0 secret/canopy/ghcr-token token"
    exit 1
fi

# Get kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

# Try to find Vault pod in different namespaces
VAULT_NAMESPACE=""
VAULT_POD=""

for ns in vault vault-system; do
    POD=$(kubectl get pods -n "$ns" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD" ]; then
        VAULT_NAMESPACE="$ns"
        VAULT_POD="$POD"
        break
    fi
done

if [ -z "$VAULT_POD" ]; then
    echo "❌ Vault pod not found. Is Vault deployed and running?" >&2
    exit 1
fi

# Check if Vault is unsealed
if ! kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- vault status > /dev/null 2>&1; then
    echo "❌ Vault is sealed or not accessible" >&2
    exit 1
fi

# Prefer ESO root token (works when /tmp/vault-init.json is absent in the pod)
VAULT_TOKEN=$(kubectl get secret vault-token -n external-secrets -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || true)

# Get secret from Vault
SECRET_VALUE=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- \
    env VAULT_ADDR=http://127.0.0.1:8200 "VAULT_TOKEN=${VAULT_TOKEN}" \
    vault kv get "-field=${KEY_NAME}" "$SECRET_PATH" 2>/dev/null || true)

if [ -z "$SECRET_VALUE" ] || [ "$SECRET_VALUE" = "null" ]; then
    echo "❌ Secret not found at $SECRET_PATH with key $KEY_NAME" >&2
    echo "   Make sure the secret exists in Vault:" >&2
    echo "   kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault kv get $SECRET_PATH" >&2
    exit 1
fi

echo "$SECRET_VALUE"


