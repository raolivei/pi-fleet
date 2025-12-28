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
# IMPORTANT: Tunnel configuration (ingress rules) is managed via Terraform (Cloudflare API)
# This is infrastructure provisioning, not application configuration.
# The tunnel connector pod is deployed via Kubernetes (FluxCD), but ingress rules
# are configured via Cloudflare API through Terraform.
# See: clusters/eldertree/dns-services/cloudflare-tunnel/ for Kubernetes deployment
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
# 
# IMPORTANT: The Cloudflare provider requires a non-empty api_token for initialization.
# When Cloudflare is not configured (token is empty), Terraform will still initialize
# the provider but all Cloudflare resources will be skipped via count conditions.
# The provider may show warnings but will not fail if resources are not created.
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

# NOTE: TLS certificates are managed by cert-manager via Helm charts
# See: clusters/eldertree/core-infrastructure/issuers/
# 
# For Cloudflare Origin Certificates (if needed):
# 1. Create certificate manually via Cloudflare Dashboard
# 2. Store certificate and key in Vault
# 3. Use External Secrets Operator to sync to Kubernetes
# See: clusters/eldertree/swimto/CLOUDFLARE_ORIGIN_CERT_SETUP.md

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
    # IMPORTANT: Using ClusterIP (10.43.81.2) instead of DNS name (traefik.kube-system.svc.cluster.local)
    # because this cluster uses IP addresses instead of DNS names (gigabit network configuration).
    # The tunnel container may have DNS resolution problems with Kubernetes service DNS,
    # so using the direct ClusterIP bypasses this issue and works reliably with IP-based networking.
    # 
    # To find the current Traefik ClusterIP:
    #   kubectl get svc traefik -n kube-system -o jsonpath='{.spec.clusterIP}'
    # 
    # If the ClusterIP changes, update this file and run: terraform apply
    ingress_rule {
      hostname = "swimto.eldertree.xyz"
      path     = "/"
      service  = "http://10.43.81.2:80"
    }

    # API service route (path-based)
    ingress_rule {
      hostname = "swimto.eldertree.xyz"
      path     = "/api/*"
      service  = "http://10.43.81.2:80"
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

# NOTE: TLS certificate outputs removed - certificates are managed by cert-manager via Helm
# See: clusters/eldertree/core-infrastructure/issuers/ for cert-manager configuration

