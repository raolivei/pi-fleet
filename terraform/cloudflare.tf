# Cloudflare DNS Configuration for eldertree.xyz
#
# NOTE: Cloudflare resources are OPTIONAL and can be skipped during initial setup.
# They will only be created if cloudflare_api_token is provided.
#
# Setup Flow:
# 1. Install k3s (without Cloudflare resources)
# 2. Bootstrap FluxCD
# 3. Wait for Vault to be deployed and unsealed
# 4. Store Cloudflare API token in Vault: secret/terraform/cloudflare-api-token
# 5. Re-run Terraform: cd terraform && ./run-terraform.sh apply (creates tunnel only)
# 6. Get tunnel token and store in Vault: secret/cloudflare-tunnel/token
# 7. FluxCD deploys cloudflared via Helm chart (clusters/eldertree/dns-services/cloudflare-tunnel)
#
# IMPORTANT: Tunnel configuration (ingress rules) is managed via Helm chart values
# See: clusters/eldertree/dns-services/cloudflare-tunnel/helmrelease.yaml
# Terraform only creates the tunnel itself. Configuration is GitOps-managed via FluxCD.
#
# Prerequisites (when adding Cloudflare resources):
# 1. Domain eldertree.xyz must be added to Cloudflare account (Add Site)
# 2. Nameservers must be changed at Porkbun to Cloudflare nameservers
# 3. Cloudflare API token must be stored in Vault at secret/terraform/cloudflare-api-token
# 4. Cloudflare zone ID must be obtained after adding domain to Cloudflare
# 5. Cloudflare Account ID (for tunnels) - found in Cloudflare Dashboard

# Local value to check if Cloudflare is enabled (token is provided)
locals {
  cloudflare_enabled = var.cloudflare_api_token != ""
}

# Configure Cloudflare provider
# Note: Provider requires authentication. Cloudflare resources check local.cloudflare_enabled
# before creating (via count conditions). If token is not provided, Cloudflare resources
# will be skipped. Use run-terraform.sh to load token from Vault automatically.
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Data source to get Cloudflare zone for eldertree.xyz
# Zone ID can be obtained from Cloudflare dashboard or API after adding domain
# Only created if Cloudflare API token is provided
data "cloudflare_zone" "eldertree_xyz" {
  count   = local.cloudflare_enabled && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
}

# Root domain A record
resource "cloudflare_record" "eldertree_xyz_root" {
  count           = local.cloudflare_enabled && var.public_ip != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.eldertree_xyz[0].id
  name            = "@"
  content         = var.public_ip
  type            = "A"
  ttl             = 300
  proxied         = false
  allow_overwrite = true
  comment         = "Root domain A record for eldertree.xyz - managed by Terraform"
}

# Wildcard A record
resource "cloudflare_record" "eldertree_xyz_wildcard" {
  count           = local.cloudflare_enabled && var.public_ip != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.eldertree_xyz[0].id
  name            = "*"
  content         = var.public_ip
  type            = "A"
  ttl             = 300
  proxied         = false
  allow_overwrite = true
  comment         = "Wildcard A record for *.eldertree.xyz - managed by Terraform"
}

# Generate private key for Origin Certificate
resource "tls_private_key" "swimto_origin" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate CSR for Origin Certificate
resource "tls_cert_request" "swimto_origin" {
  private_key_pem = tls_private_key.swimto_origin.private_key_pem

  subject {
    common_name  = "swimto.eldertree.xyz"
    organization = "Eldertree"
  }

  dns_names = [
    "swimto.eldertree.xyz",
    "*.eldertree.xyz"
  ]
}

# Cloudflare Origin Certificate for swimto.eldertree.xyz
# 
# NOTE: Creating Origin CA certificates via API requires special permissions:
# - API token needs "SSL and Certificates:Edit" permission
# - Standard DNS tokens don't have this permission
# 
# If you get error 1016 (not authorized), you have two options:
# 1. Create certificate manually via Cloudflare Dashboard (see CLOUDFLARE_ORIGIN_CERT_SETUP.md)
# 2. Update API token to include SSL/Certificates permissions
#
# To make this optional, uncomment the resource below and ensure your API token has the right permissions
#
# resource "cloudflare_origin_ca_certificate" "swimto" {
#   csr              = tls_cert_request.swimto_origin.cert_request_pem
#   hostnames        = ["swimto.eldertree.xyz", "*.eldertree.xyz"]
#   request_type     = "origin-rsa"
#   requested_validity = 5475  # 15 years (maximum, in days)
# }

# Generate tunnel secret
resource "random_password" "tunnel_secret" {
  length  = 32
  special = false
}

# Cloudflare Tunnel for eldertree cluster
# Creates secure outbound connection from cluster to Cloudflare
# Using cloudflare_zero_trust_tunnel_cloudflared (replaces deprecated cloudflare_tunnel)
# Only created if Cloudflare API token and account ID are provided
resource "cloudflare_zero_trust_tunnel_cloudflared" "eldertree" {
  count      = local.cloudflare_enabled && var.cloudflare_account_id != "" ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = "eldertree"
  secret     = base64encode(random_password.tunnel_secret.result)
}

# Cloudflare Tunnel Configuration
# Defines ingress rules for routing traffic
# Using cloudflare_zero_trust_tunnel_cloudflared_config (replaces deprecated cloudflare_tunnel_config)
# 
# NOTE: Tunnel connector is deployed via Kubernetes Deployment (not Helm chart)
# because cloudflare-tunnel Helm chart expects credentials file format,
# but we use TUNNEL_TOKEN mode which is simpler with ExternalSecret.
# The deployment is GitOps-managed via FluxCD at: clusters/eldertree/dns-services/cloudflare-tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "eldertree" {
  count      = local.cloudflare_enabled && var.cloudflare_account_id != "" ? 1 : 0
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id

  config {
    # Web service route
    ingress_rule {
      hostname = "swimto.eldertree.xyz"
      path     = "/"
      service  = "http://traefik.kube-system.svc.cluster.local:80"
    }

    # API service route (path-based)
    ingress_rule {
      hostname = "swimto.eldertree.xyz"
      path     = "/api/*"
      service  = "http://traefik.kube-system.svc.cluster.local:80"
    }

    # Catch-all rule (must be last)
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# DNS CNAME record for swimto.eldertree.xyz pointing to tunnel
# This creates the DNS record that routes traffic to the tunnel
resource "cloudflare_record" "swimto_eldertree_xyz_tunnel" {
  count           = local.cloudflare_enabled && var.cloudflare_account_id != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.eldertree_xyz[0].id
  name            = "swimto"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id}.cfargotunnel.com"
  type            = "CNAME"
  ttl             = 1    # Must be 1 when proxied=true
  proxied         = true # Enable Cloudflare proxy (orange cloud) for automatic HTTPS
  allow_overwrite = true
  comment         = "swimto.eldertree.xyz - managed by Terraform via Cloudflare Tunnel"
}

# Output zone ID for External-DNS integration
output "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for eldertree.xyz (for External-DNS configuration)"
  value       = var.cloudflare_api_token != "" && var.cloudflare_zone_id != "" ? data.cloudflare_zone.eldertree_xyz[0].id : null
}

# Output Cloudflare Tunnel information
output "cloudflare_tunnel_id" {
  description = "Cloudflare Tunnel ID for eldertree"
  value       = var.cloudflare_api_token != "" && var.cloudflare_account_id != "" ? cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id : null
}

output "cloudflare_tunnel_name" {
  description = "Cloudflare Tunnel name"
  value       = var.cloudflare_api_token != "" && var.cloudflare_account_id != "" ? cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].name : null
}

output "cloudflare_tunnel_token" {
  description = "Cloudflare Tunnel token - use this for TUNNEL_TOKEN in Kubernetes. Get from Cloudflare Dashboard after tunnel is created, or use cloudflared tunnel token command."
  value       = "" # Token must be obtained from Cloudflare Dashboard or generated via cloudflared CLI
  sensitive   = true
}

output "cloudflare_tunnel_cname" {
  description = "CNAME target for tunnel DNS records"
  value       = var.cloudflare_api_token != "" && var.cloudflare_account_id != "" ? "${cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id}.cfargotunnel.com" : null
}

# Output Origin Certificate components for Kubernetes secret creation
# Note: Certificate must be created manually in Cloudflare Dashboard (see ORIGIN_CERT_API_PERMISSIONS.md)
# Terraform generates the private key and CSR, which you use to create the certificate
output "swimto_origin_private_key" {
  description = "Private key for Cloudflare Origin Certificate (use with kubectl create secret tls). Always available from Terraform."
  value       = tls_private_key.swimto_origin.private_key_pem
  sensitive   = true
}

output "swimto_origin_csr" {
  description = "Certificate Signing Request (CSR) - use this when creating certificate manually in Cloudflare Dashboard"
  value       = tls_cert_request.swimto_origin.cert_request_pem
  sensitive   = false
}

# Note: If you uncomment the cloudflare_origin_ca_certificate resource above and have proper API permissions,
# you can add these outputs:
# output "swimto_origin_certificate" {
#   value = cloudflare_origin_ca_certificate.swimto.certificate
#   sensitive = false
# }
# output "swimto_certificate_id" {
#   value = cloudflare_origin_ca_certificate.swimto.id
# }

