# NOTE: k3s installation is handled by Ansible (ansible/playbooks/install-k3s.yml)
# These variables are no longer needed in Terraform.
# For k3s installation, use Ansible playbooks instead.

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

