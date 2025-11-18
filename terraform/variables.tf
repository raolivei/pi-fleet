variable "pi_host" {
  description = "Hostname or IP address of the Raspberry Pi"
  type        = string
  default     = "eldertree"
}

variable "pi_user" {
  description = "SSH username for the Raspberry Pi"
  type        = string
  default     = "raolivei"
}

variable "pi_password" {
  description = "SSH password for the Raspberry Pi"
  type        = string
  default     = null  # Use null instead of empty string to avoid marked value issues
  sensitive   = true
  nullable    = true
}

variable "k3s_version" {
  description = "Version of k3s to install (leave empty for latest)"
  type        = string
  default     = ""
}

variable "k3s_token" {
  description = "K3s cluster token (auto-generated if not provided)"
  type        = string
  default     = null  # Use null instead of empty string to avoid marked value issues
  sensitive   = true
  nullable    = true
}

variable "kubeconfig_path" {
  description = "Local path to save the kubeconfig"
  type        = string
  default     = "~/.kube/config-eldertree"
}

variable "skip_k3s_resources" {
  description = "Skip k3s installation resources (useful for CI where SSH is not available)"
  type        = bool
  default     = false
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management. Should be stored in Vault at secret/terraform/cloudflare-api-token"
  type        = string
  sensitive   = true
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

