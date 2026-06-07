#!/usr/bin/env bash
# Store a GitHub PAT in Vault for ARC repo-scoped scale sets (raolivei User account).
# Requires: gh auth token with repo + workflow scopes, kubectl + Eldertree cluster.
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
VAULT_PATH="${VAULT_PATH:-secret/eldertree/arc-runners/ollie}"
VERIFY_REPO="${VERIFY_REPO:-ollie}"

echo "==> Checking gh token..."
if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "Not logged in. Run: gh auth login"
  exit 1
fi

GITHUB_TOKEN="$(gh auth token -h github.com)"
echo "==> Verifying repo registration-token API (raolivei/${VERIFY_REPO})..."
HTTP_CODE=$(curl -sS -o /tmp/arc-reg-token.json -w '%{http_code}' \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/raolivei/${VERIFY_REPO}/actions/runners/registration-token")
if [[ "$HTTP_CODE" != "201" ]]; then
  echo "Repo registration-token failed (HTTP ${HTTP_CODE}):"
  cat /tmp/arc-reg-token.json
  exit 1
fi
echo "    OK — token can register repo runners"

VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')
VAULT_TOKEN=$(kubectl get secret vault-token -n external-secrets -o jsonpath='{.data.token}' | base64 -d)

echo "==> Writing to Vault (${VAULT_PATH})..."
kubectl exec -n vault "$VAULT_POD" -- \
  env VAULT_ADDR=http://127.0.0.1:8200 "VAULT_TOKEN=${VAULT_TOKEN}" \
  vault kv put "$VAULT_PATH" github_token="${GITHUB_TOKEN}"

echo "==> Forcing ExternalSecret sync..."
kubectl annotate externalsecret ollie-runner-github-secret -n arc-runners \
  force-sync="$(date +%s)" --overwrite 2>/dev/null || \
  kubectl delete secret ollie-runner-github-secret -n arc-runners --ignore-not-found

sleep 5
kubectl get secret ollie-runner-github-secret -n arc-runners >/dev/null
echo "==> Secret synced. Reconcile listeners:"
echo "    flux reconcile helmrelease --all -n arc-runners"
