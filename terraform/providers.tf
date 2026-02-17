terraform {
  required_version = ">= 1.0"

  # Backend configuration for remote state
  # Terraform Cloud backend is used in CI (GitHub Actions)
  # Local backend is used for local development
  backend "remote" {
    organization = "eldertree"
    workspaces {
      name = "pi-fleet-terraform"
    }
  }

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

# =============================================================================
# Vault Provider Configuration
# =============================================================================
# Vault is used for secrets management in the eldertree cluster.
# The provider is configured to connect to Vault running in Kubernetes.
#
# Prerequisites:
# - Vault must be deployed and unsealed in the cluster
# - kubectl port-forward vault-0 8200:8200 -n vault (for local development)
# - Or use the Vault ingress URL for remote access
#
# Authentication:
# - Uses token auth by default (VAULT_TOKEN env var or vault_token variable)
# - Token can be obtained from: kubectl get secret vault-token -n external-secrets -o jsonpath='{.data.token}' | base64 -d
# =============================================================================
provider "vault" {
  address         = var.vault_address
  token           = var.vault_token
  skip_tls_verify = var.vault_skip_tls_verify

  # These flags prevent the provider from making API calls during init,
  # allowing Terraform to run in CI without Vault access (with -refresh=false)
  skip_child_token      = true
  skip_get_vault_version = true
}

