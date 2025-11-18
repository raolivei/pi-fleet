terraform {
  required_version = ">= 1.0"

  # Backend configuration for remote state
  # Terraform Cloud backend is used in CI (GitHub Actions)
  # Local backend is used for local development
  backend "remote" {
    # Configuration is provided via environment variables in CI:
    # - TF_CLOUD_ORGANIZATION
    # - TF_CLOUD_WORKSPACE
    # Or via terraform init -backend-config flags
    #
    # For local development, use: terraform init -backend=false
    # Or override with: terraform init -backend-config="organization=your-org" -backend-config="workspaces.name=pi-fleet"
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
  }
}

