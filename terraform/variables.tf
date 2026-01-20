# NOTE: k3s installation is handled by Ansible (ansible/playbooks/install-k3s.yml)
# These variables are no longer needed in Terraform.
# For k3s installation, use Ansible playbooks instead.

variable "skip_k3s_resources" {
  description = "Skip k3s installation resources (useful for CI where SSH is not available)"
  type        = bool
  default     = false
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management. Should be stored in Vault at secret/pi-fleet/terraform/cloudflare-api-token. Leave empty to skip Cloudflare resources (can be added later)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for eldertree.xyz. Obtained after adding domain to Cloudflare account."
  type        = string
  default     = ""
}

variable "public_ip" {
  description = "Public IP address for DNS A records (root and wildcard). May need dynamic DNS solution or router port forwarding."
  type        = string
  default     = ""
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (required for tunnels). Found in Cloudflare Dashboard → Right sidebar → Account ID"
  type        = string
  default     = ""
}

variable "pitanga_cloud_zone_id" {
  description = "Cloudflare Zone ID for pitanga.cloud. Obtained after adding domain to Cloudflare account."
  type        = string
  default     = ""
}

variable "swimto_app_zone_id" {
  description = "Cloudflare Zone ID for swimto.app. Obtained after adding domain to Cloudflare account."
  type        = string
  default     = ""
}

# =============================================================================
# Vault Configuration Variables
# =============================================================================
# These variables configure the Vault provider for managing secrets,
# policies, auth methods, and secrets engines.
#
# For local development:
#   kubectl port-forward vault-0 8200:8200 -n vault
#   export TF_VAR_vault_address="http://127.0.0.1:8200"
#   export TF_VAR_vault_token=$(kubectl get secret vault-token -n external-secrets -o jsonpath='{.data.token}' | base64 -d)
# =============================================================================

variable "vault_address" {
  description = "Vault server address. Use http://127.0.0.1:8200 with port-forward or Vault ingress URL."
  type        = string
  default     = "http://127.0.0.1:8200"
}

variable "vault_token" {
  description = "Vault authentication token (root token or token with sufficient permissions). Stored in external-secrets namespace."
  type        = string
  sensitive   = true
  default     = ""
}

variable "vault_skip_tls_verify" {
  description = "Skip TLS verification for Vault connection. Set to true for self-signed certificates."
  type        = bool
  default     = true
}

variable "skip_vault_resources" {
  description = "Skip Vault resource management. Set to true when Vault is not accessible (e.g., CI environments)."
  type        = bool
  default     = false
}

variable "vault_projects" {
  description = "List of projects that need Vault policies and secrets engines"
  type = list(object({
    name        = string
    description = string
    paths       = list(string)
  }))
  default = [
    {
      name        = "canopy"
      description = "Canopy personal finance tracker"
      paths       = ["secret/data/canopy/*", "secret/metadata/canopy/*"]
    },
    {
      name        = "swimto"
      description = "SwimTO pool finder application"
      paths       = ["secret/data/swimto/*", "secret/metadata/swimto/*"]
    },
    {
      name        = "journey"
      description = "Journey fitness tracking application"
      paths       = ["secret/data/journey/*", "secret/metadata/journey/*"]
    },
    {
      name        = "nima"
      description = "Nima AI assistant"
      paths       = ["secret/data/nima/*", "secret/metadata/nima/*"]
    },
    {
      name        = "us-law-severity-map"
      description = "US Law Severity Map visualization"
      paths       = ["secret/data/us-law-severity-map/*", "secret/metadata/us-law-severity-map/*"]
    },
    {
      name        = "monitoring"
      description = "Monitoring stack (Prometheus, Grafana)"
      paths       = ["secret/data/monitoring/*", "secret/metadata/monitoring/*"]
    },
    {
      name        = "ollie"
      description = "Ollie task automation"
      paths       = ["secret/data/ollie/*", "secret/metadata/ollie/*"]
    }
  ]
}

variable "kubernetes_host" {
  description = "Kubernetes API server address for Vault Kubernetes auth backend configuration."
  type        = string
  default     = "https://kubernetes.default.svc"
}
