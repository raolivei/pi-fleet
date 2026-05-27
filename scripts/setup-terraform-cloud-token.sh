#!/usr/bin/env bash
# Store HCP Terraform user API token in Vault (source of truth).
# Optionally publish to GitHub Actions + Dependabot (public runners cannot read Vault directly).
#
# Usage:
#   ./scripts/setup-terraform-cloud-token.sh              # prompt, Vault only
#   ./scripts/setup-terraform-cloud-token.sh --sync-github  # Vault + GitHub secrets
#   TF_API_TOKEN='at-...' ./scripts/setup-terraform-cloud-token.sh --sync-github --no-prompt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ORG="eldertree"
HOST="app.terraform.io"
VAULT_PATH="${TF_VAULT_HCP_PATH:-secret/pi-fleet/terraform/eldertree-github-2026}"

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

NO_PROMPT=0
SYNC_GITHUB=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-prompt) NO_PROMPT=1; shift ;;
    --sync-github) SYNC_GITHUB=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "${TF_API_TOKEN:-}" ]]; then
  if [[ "$NO_PROMPT" -eq 1 ]]; then
    echo "Error: set TF_API_TOKEN or run without --no-prompt" >&2
    exit 1
  fi
  echo "Create a token: https://app.terraform.io/app/settings/tokens"
  echo "Organization: ${ORG}"
  read -r -s -p "Paste token (hidden): " TF_API_TOKEN
  echo ""
  [[ -n "$TF_API_TOKEN" ]] || { echo "Error: empty token" >&2; exit 1; }
fi

code=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${TF_API_TOKEN}" \
  -H "Content-Type: application/vnd.api+json" \
  "https://${HOST}/api/v2/organizations/${ORG}")
[[ "$code" == "200" ]] || { echo "Error: invalid token for org ${ORG} (HTTP ${code})" >&2; exit 1; }

pod=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault \
  -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')
root=$(kubectl get secret vault-token -n external-secrets -o jsonpath='{.data.token}' | base64 -d)
[[ -n "$pod" && -n "$root" ]] || { echo "Error: Vault unavailable" >&2; exit 1; }

kubectl exec -n vault "$pod" -- \
  env VAULT_ADDR=http://127.0.0.1:8200 "VAULT_TOKEN=${root}" \
  vault kv put "$VAULT_PATH" token="${TF_API_TOKEN}" >/dev/null

echo "OK: stored in Vault at ${VAULT_PATH}"

# Local ~/.terraform.d/credentials.tfrc.json
mkdir -p "${HOME}/.terraform.d"
python3 - "${HOME}/.terraform.d/credentials.tfrc.json" "$HOST" "$TF_API_TOKEN" <<'PY'
import json, os, sys
path, host, token = sys.argv[1], sys.argv[2], sys.argv[3]
data = {"credentials": {host: {"token": token}}}
if os.path.isfile(path):
    with open(path) as f:
        data = json.load(f)
    data.setdefault("credentials", {})[host] = {"token": token}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.chmod(path, 0o600)
PY
echo "OK: ~/.terraform.d/credentials.tfrc.json"

if [[ "$SYNC_GITHUB" -eq 1 ]]; then
  export TF_API_TOKEN
  "${SCRIPT_DIR}/sync-github-terraform-secrets-from-vault.sh" --app actions --app dependabot
else
  echo ""
  echo "GitHub Actions/Dependabot cannot reach vault.eldertree.local."
  echo "After storing in Vault, publish to GitHub with:"
  echo "  ${SCRIPT_DIR}/sync-github-terraform-secrets-from-vault.sh --app actions --app dependabot"
fi

echo ""
echo "Optional: delete the old HCP user token named 'eldertree' after verifying CI."
