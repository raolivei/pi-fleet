# Cloudflare DNS Configuration for eldertree.xyz
#
# Prerequisites:
# 1. Domain eldertree.xyz must be added to Cloudflare account (Add Site)
# 2. Nameservers must be changed at Porkbun to Cloudflare nameservers
# 3. Cloudflare API token must be stored in Vault at secret/terraform/cloudflare-api-token
# 4. Cloudflare zone ID must be obtained after adding domain to Cloudflare

# Configure Cloudflare provider
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Data source to get Cloudflare zone for eldertree.xyz
# Zone ID can be obtained from Cloudflare dashboard or API after adding domain
data "cloudflare_zone" "eldertree_xyz" {
  zone_id = var.cloudflare_zone_id
}

# Root domain A record
resource "cloudflare_record" "eldertree_xyz_root" {
  count           = var.public_ip != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.eldertree_xyz.id
  name            = "@"
  content         = var.public_ip
  type            = "A"
  ttl             = 300
  allow_overwrite = true
  comment         = "Root domain A record for eldertree.xyz - managed by Terraform"
}

# Wildcard A record
resource "cloudflare_record" "eldertree_xyz_wildcard" {
  count           = var.public_ip != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.eldertree_xyz.id
  name            = "*"
  content         = var.public_ip
  type            = "A"
  ttl             = 300
  allow_overwrite = true
  comment         = "Wildcard A record for *.eldertree.xyz - managed by Terraform"
}

# Output zone ID for External-DNS integration
output "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for eldertree.xyz (for External-DNS configuration)"
  value       = data.cloudflare_zone.eldertree_xyz.id
}

