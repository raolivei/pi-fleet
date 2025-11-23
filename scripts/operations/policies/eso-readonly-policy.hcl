# External Secrets Operator Read-Only Policy
# Grants read-only access to all secrets for syncing to Kubernetes
# This policy is used by External Secrets Operator to read secrets from all projects

path "secret/data/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/*" {
  capabilities = ["list", "read"]
}

