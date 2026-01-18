# =============================================================================
# Vault Configuration - Policies, Auth Methods, and Secrets Engines
# =============================================================================
#
# This file manages all Vault configuration declaratively via Terraform,
# replacing the shell script at scripts/operations/setup-vault-policies.sh
#
# Resources managed:
# - KV Secrets Engine (v2) for project secrets
# - Vault Policies (per-project access control)
# - Kubernetes Auth Method (for External Secrets Operator)
# - AppRoles (optional, for CI/CD pipelines)
#
# Prerequisites:
# - Vault must be deployed and unsealed
# - kubectl port-forward vault-0 8200:8200 -n vault (for local dev)
# - VAULT_TOKEN must be set (root token or admin token)
#
# Usage:
#   terraform apply -target=module.vault  # Apply only Vault resources
# =============================================================================

# Local values for Vault configuration
locals {
  # Skip Vault resources when token is not provided or skip flag is set
  vault_enabled = var.vault_token != "" && !var.skip_vault_resources

  # Project policies map for easy lookup
  project_policies = {
    for project in var.vault_projects : project.name => project
  }

  # Infrastructure paths for the infrastructure policy
  infrastructure_paths = [
    "secret/data/pi-fleet/*",
    "secret/metadata/pi-fleet/*",
    "secret/data/pihole/*",
    "secret/metadata/pihole/*",
    "secret/data/flux/*",
    "secret/metadata/flux/*",
    "secret/data/external-dns/*",
    "secret/metadata/external-dns/*",
    "secret/data/terraform/*",
    "secret/metadata/terraform/*",
    "secret/data/cloudflare-tunnel/*",
    "secret/metadata/cloudflare-tunnel/*",
    "secret/data/pitanga/*",
    "secret/metadata/pitanga/*",
  ]
}

# =============================================================================
# KV Secrets Engine v2
# =============================================================================
# Enable KV v2 secrets engine at "secret/" path if not already enabled
# Note: This is typically enabled by default in Vault, but we ensure it exists

resource "vault_mount" "kv_v2" {
  count = local.vault_enabled ? 1 : 0

  path        = "secret"
  type        = "kv"
  description = "KV v2 secrets engine for pi-fleet projects"

  options = {
    version = "2"
  }

  lifecycle {
    # Prevent destruction of the secrets engine
    prevent_destroy = true
  }
}

# =============================================================================
# Project Policies
# =============================================================================
# Create a policy for each project with read/write access to their secrets

resource "vault_policy" "project_policy" {
  for_each = local.vault_enabled ? local.project_policies : {}

  name = "${each.key}-policy"

  policy = <<-EOT
    # ${each.value.description}
    # Grants read/write access to ${each.key} secrets only

    path "secret/data/${each.key}/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "secret/metadata/${each.key}/*" {
      capabilities = ["list", "read", "delete"]
    }
  EOT
}

# =============================================================================
# Infrastructure Policy
# =============================================================================
# Policy for infrastructure components (Terraform, External DNS, etc.)

resource "vault_policy" "infrastructure_policy" {
  count = local.vault_enabled ? 1 : 0

  name = "infrastructure-policy"

  policy = <<-EOT
    # Infrastructure Policy
    # Grants read/write access to infrastructure secrets under secret/pi-fleet/
    # All infrastructure secrets are organized under secret/pi-fleet/

    # New structure: secret/pi-fleet/*
    path "secret/data/pi-fleet/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "secret/metadata/pi-fleet/*" {
      capabilities = ["list", "read", "delete"]
    }

    # Legacy paths (for backward compatibility)
    path "secret/data/pihole/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "secret/metadata/pihole/*" {
      capabilities = ["list", "read", "delete"]
    }

    path "secret/data/flux/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "secret/metadata/flux/*" {
      capabilities = ["list", "read", "delete"]
    }

    path "secret/data/external-dns/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "secret/metadata/external-dns/*" {
      capabilities = ["list", "read", "delete"]
    }

    path "secret/data/terraform/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "secret/metadata/terraform/*" {
      capabilities = ["list", "read", "delete"]
    }

    path "secret/data/cloudflare-tunnel/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "secret/metadata/cloudflare-tunnel/*" {
      capabilities = ["list", "read", "delete"]
    }

    path "secret/data/pitanga/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "secret/metadata/pitanga/*" {
      capabilities = ["list", "read", "delete"]
    }
  EOT
}

# =============================================================================
# ESO Read-Only Policy
# =============================================================================
# Policy for External Secrets Operator with read-only access to all secrets

resource "vault_policy" "eso_readonly_policy" {
  count = local.vault_enabled ? 1 : 0

  name = "eso-readonly-policy"

  policy = <<-EOT
    # External Secrets Operator Read-Only Policy
    # Grants read access to all project secrets for syncing to Kubernetes

    # Read access to all project secrets
    path "secret/data/*" {
      capabilities = ["read", "list"]
    }

    path "secret/metadata/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

# =============================================================================
# Kubernetes Auth Method
# =============================================================================
# Enable Kubernetes authentication for pods to access Vault

resource "vault_auth_backend" "kubernetes" {
  count = local.vault_enabled ? 1 : 0

  type        = "kubernetes"
  path        = "kubernetes"
  description = "Kubernetes auth method for pod authentication"
}

resource "vault_kubernetes_auth_backend_config" "config" {
  count = local.vault_enabled ? 1 : 0

  backend         = vault_auth_backend.kubernetes[0].path
  kubernetes_host = var.kubernetes_host

  # When running Vault in Kubernetes, the service account token is automatically
  # mounted at this path. Vault uses this to validate incoming tokens.
  # If Vault is outside Kubernetes, you need to provide kubernetes_ca_cert
  # and token_reviewer_jwt manually.
}

# =============================================================================
# Kubernetes Auth Roles for Projects
# =============================================================================
# Each project gets a Kubernetes auth role bound to its namespace

resource "vault_kubernetes_auth_backend_role" "project_role" {
  for_each = local.vault_enabled ? local.project_policies : {}

  backend                          = vault_auth_backend.kubernetes[0].path
  role_name                        = each.key
  bound_service_account_names      = ["*"]
  bound_service_account_namespaces = [each.key]
  token_policies                   = ["${each.key}-policy"]
  token_ttl                        = 3600  # 1 hour
  token_max_ttl                    = 86400 # 24 hours
}

# ESO role for External Secrets Operator
resource "vault_kubernetes_auth_backend_role" "eso_role" {
  count = local.vault_enabled ? 1 : 0

  backend                          = vault_auth_backend.kubernetes[0].path
  role_name                        = "external-secrets"
  bound_service_account_names      = ["external-secrets", "vault-token"]
  bound_service_account_namespaces = ["external-secrets"]
  token_policies                   = ["eso-readonly-policy"]
  token_ttl                        = 3600
  token_max_ttl                    = 86400
}

# Infrastructure role for Terraform and CI/CD
resource "vault_kubernetes_auth_backend_role" "infrastructure_role" {
  count = local.vault_enabled ? 1 : 0

  backend                          = vault_auth_backend.kubernetes[0].path
  role_name                        = "infrastructure"
  bound_service_account_names      = ["default", "terraform"]
  bound_service_account_namespaces = ["default", "flux-system", "kube-system"]
  token_policies                   = ["infrastructure-policy"]
  token_ttl                        = 3600
  token_max_ttl                    = 86400
}

# =============================================================================
# Token Auth - Service Tokens
# =============================================================================
# Create service tokens for projects (used by External Secrets Operator)
# These tokens are stored in Kubernetes secrets in the external-secrets namespace

resource "vault_token" "project_token" {
  for_each = local.vault_enabled ? local.project_policies : {}

  display_name = "${each.key}-service-token"
  policies     = ["${each.key}-policy"]
  renewable    = true
  ttl          = "0" # No expiration
  no_parent    = true

  metadata = {
    project = each.key
    purpose = "External Secrets Operator"
  }

  lifecycle {
    # Don't recreate tokens on every apply
    ignore_changes = [ttl]
  }
}

resource "vault_token" "infrastructure_token" {
  count = local.vault_enabled ? 1 : 0

  display_name = "infrastructure-service-token"
  policies     = ["infrastructure-policy"]
  renewable    = true
  ttl          = "0"
  no_parent    = true

  metadata = {
    project = "infrastructure"
    purpose = "Terraform and CI/CD"
  }

  lifecycle {
    ignore_changes = [ttl]
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "vault_policies" {
  description = "List of created Vault policies"
  value = local.vault_enabled ? concat(
    [for p in vault_policy.project_policy : p.name],
    [vault_policy.infrastructure_policy[0].name],
    [vault_policy.eso_readonly_policy[0].name]
  ) : []
}

output "vault_kubernetes_auth_roles" {
  description = "List of Kubernetes auth roles"
  value = local.vault_enabled ? concat(
    [for r in vault_kubernetes_auth_backend_role.project_role : r.role_name],
    ["external-secrets", "infrastructure"]
  ) : []
}

output "vault_project_tokens" {
  description = "Map of project names to their service token IDs (tokens are sensitive)"
  value       = local.vault_enabled ? { for k, v in vault_token.project_token : k => v.id } : {}
  sensitive   = true
}

output "vault_enabled" {
  description = "Whether Vault resources are managed by Terraform"
  value       = local.vault_enabled
  sensitive   = true
}
