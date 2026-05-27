#!/usr/bin/env bash
# Load Terraform-related secrets from Vault (KV v2) into the environment.
# Source this file:  source "$(dirname "$0")/../lib/load-terraform-secrets-from-vault.sh"
#
# Sets (when present in Vault):
#   TF_VAR_cloudflare_api_token, TF_VAR_cloudflare_origin_ca_key, TF_VAR_pi_user
#   TF_TOKEN_app_terraform_io  (HCP Terraform / Terraform Cloud)
#
# Paths:
#   secret/pi-fleet/terraform/cloudflare-api-token     (api-token)
#   secret/pi-fleet/terraform/cloudflare-origin-ca-key (origin-ca-key)
#   secret/pi-fleet/terraform/terraform-cloud-token    (token)
#   secret/pi-fleet/terraform/pi-user                    (pi-user)

load_terraform_secrets_from_vault() {
  export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

  local script_dir vault_pod vault_token
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  _vault_field() {
    local path="$1" field="$2"
    if command -v kubectl >/dev/null 2>&1; then
      vault_pod=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault \
        -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null | awk '{print $1}')
      if [[ -n "$vault_pod" ]]; then
        vault_token=$(kubectl get secret vault-token -n external-secrets \
          -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)
        if [[ -n "$vault_token" ]]; then
          kubectl exec -n vault "$vault_pod" -- \
            env VAULT_ADDR=http://127.0.0.1:8200 "VAULT_TOKEN=${vault_token}" \
            vault kv get "-field=${field}" "$path" 2>/dev/null || true
          return
        fi
      fi
    fi
    # Fallback: get-vault-secret.sh (same paths)
    if [[ -f "${script_dir}/../get-vault-secret.sh" ]]; then
      "${script_dir}/../get-vault-secret.sh" "$path" "$field" 2>/dev/null || true
    fi
  }

  local v
  v=$(_vault_field secret/pi-fleet/terraform/cloudflare-api-token api-token)
  [[ -n "$v" ]] && export TF_VAR_cloudflare_api_token="$v"

  v=$(_vault_field secret/pi-fleet/terraform/cloudflare-origin-ca-key origin-ca-key)
  [[ -n "$v" ]] && export TF_VAR_cloudflare_origin_ca_key="$v"

  v=$(_vault_field secret/pi-fleet/terraform/terraform-cloud-token token)
  [[ -n "$v" ]] && export TF_TOKEN_app_terraform_io="$v"

  v=$(_vault_field secret/pi-fleet/terraform/pi-user pi-user)
  [[ -n "$v" ]] && export TF_VAR_pi_user="$v"
}

# When executed directly, print which keys are set (not values)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  load_terraform_secrets_from_vault
  for name in TF_VAR_cloudflare_api_token TF_VAR_cloudflare_origin_ca_key TF_TOKEN_app_terraform_io TF_VAR_pi_user; do
    if [[ -n "${!name:-}" ]]; then
      echo "set $name"
    else
      echo "missing $name"
    fi
  done
fi
