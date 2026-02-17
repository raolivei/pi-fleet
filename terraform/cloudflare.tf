# Cloudflare DNS Configuration for eldertree.xyz
#
# NOTE: Cloudflare resources are OPTIONAL and can be skipped during initial setup.
# They will only be created if cloudflare_api_token is provided.
#
# Setup Flow:
# 1. Install k3s (without Cloudflare resources)
# 2. Bootstrap FluxCD
# 3. Wait for Vault to be deployed and unsealed
# 4. Store Cloudflare API token in Vault: secret/pi-fleet/terraform/cloudflare-api-token
# 5. Re-run Terraform: cd terraform && ./run-terraform.sh apply (creates tunnel only)
# 6. Get tunnel token and store in Vault: secret/pi-fleet/cloudflare-tunnel/token
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
# 3. Cloudflare API token must be stored in Vault at secret/pi-fleet/terraform/cloudflare-api-token
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

# Data source to get Cloudflare zone for pitanga.cloud
# Zone ID can be obtained from Cloudflare dashboard or API after adding domain
# Only created if Cloudflare API token is provided
data "cloudflare_zone" "pitanga_cloud" {
  count   = local.cloudflare_enabled && var.pitanga_cloud_zone_id != "" ? 1 : 0
  zone_id = var.pitanga_cloud_zone_id
}

# Data source to get Cloudflare zone for swimto.app
# Zone ID can be obtained from Cloudflare dashboard or API after adding domain
# Only created if Cloudflare API token is provided
data "cloudflare_zone" "swimto_app" {
  count   = local.cloudflare_enabled && var.swimto_app_zone_id != "" ? 1 : 0
  zone_id = var.swimto_app_zone_id
}

# Data source to get Cloudflare zone for raolivei.me
# Zone ID can be obtained from Cloudflare dashboard or API after adding domain
# Only created if Cloudflare API token is provided
data "cloudflare_zone" "raolivei_me" {
  count   = local.cloudflare_enabled && var.raolivei_me_zone_id != "" ? 1 : 0
  zone_id = var.raolivei_me_zone_id
}

# NOTE: Zone-level SSL/TLS settings managed via Cloudflare Dashboard:
#   - SSL/TLS mode: Full (Strict)
#   - Always Use HTTPS: On
#   - Minimum TLS Version: 1.2
#   - TLS 1.3: On
#   - HSTS: Enabled (max-age 1 year, includeSubDomains, preload)
# (API token lacks Zone Settings:Edit permission)

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

# Generate private key for pitanga.cloud Origin Certificate
resource "tls_private_key" "pitanga_cloud" {
  count     = local.cloudflare_enabled && var.pitanga_cloud_zone_id != "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate CSR for pitanga.cloud Origin Certificate
resource "tls_cert_request" "pitanga_cloud" {
  count           = local.cloudflare_enabled && var.pitanga_cloud_zone_id != "" ? 1 : 0
  private_key_pem = tls_private_key.pitanga_cloud[0].private_key_pem

  subject {
    common_name  = "pitanga.cloud"
    organization = "Pitanga Systems LLC"
  }
}

# Cloudflare Origin Certificate for pitanga.cloud
# Creates Origin CA certificate for pitanga.cloud and all subdomains
# NOTE: Requires API token with "SSL and Certificates:Edit" permission
# See: ORIGIN_CERT_API_PERMISSIONS.md for permission setup
resource "cloudflare_origin_ca_certificate" "pitanga_cloud" {
  count = local.cloudflare_enabled && var.pitanga_cloud_zone_id != "" ? 1 : 0

  # Certificate configuration
  request_type       = "origin-rsa" # RSA 2048-bit key
  requested_validity = 5475         # 15 years (maximum)
  csr                = tls_cert_request.pitanga_cloud[0].cert_request_pem

  # Hostnames covered by this certificate
  # Using wildcard to cover all subdomains (pitanga.cloud, www.pitanga.cloud, northwaysignal.pitanga.cloud, etc.)
  hostnames = [
    "pitanga.cloud",
    "*.pitanga.cloud"
  ]
}

# =============================================================================
# swimto.app Origin Certificate
# =============================================================================

# Generate private key for swimto.app Origin Certificate
resource "tls_private_key" "swimto_app" {
  count     = local.cloudflare_enabled && var.swimto_app_zone_id != "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate CSR for swimto.app Origin Certificate
resource "tls_cert_request" "swimto_app" {
  count           = local.cloudflare_enabled && var.swimto_app_zone_id != "" ? 1 : 0
  private_key_pem = tls_private_key.swimto_app[0].private_key_pem

  subject {
    common_name  = "swimto.app"
    organization = "SwimTO"
  }
}

# Cloudflare Origin Certificate for swimto.app
# Creates Origin CA certificate for swimto.app and all subdomains
# NOTE: Requires API token with "SSL and Certificates:Edit" permission
resource "cloudflare_origin_ca_certificate" "swimto_app" {
  count = local.cloudflare_enabled && var.swimto_app_zone_id != "" ? 1 : 0

  # Certificate configuration
  request_type       = "origin-rsa" # RSA 2048-bit key
  requested_validity = 5475         # 15 years (maximum)
  csr                = tls_cert_request.swimto_app[0].cert_request_pem

  # Hostnames covered by this certificate
  # Using wildcard to cover all subdomains (swimto.app, www.swimto.app, api.swimto.app, etc.)
  hostnames = [
    "swimto.app",
    "*.swimto.app"
  ]
}

# =============================================================================
# eldertree.xyz Origin Certificate
# =============================================================================

# Generate private key for eldertree.xyz Origin Certificate
resource "tls_private_key" "eldertree_xyz" {
  count     = local.cloudflare_enabled && var.cloudflare_zone_id != "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate CSR for eldertree.xyz Origin Certificate
resource "tls_cert_request" "eldertree_xyz" {
  count           = local.cloudflare_enabled && var.cloudflare_zone_id != "" ? 1 : 0
  private_key_pem = tls_private_key.eldertree_xyz[0].private_key_pem

  subject {
    common_name  = "eldertree.xyz"
    organization = "Eldertree"
  }
}

# Cloudflare Origin Certificate for eldertree.xyz
# Creates Origin CA certificate for eldertree.xyz and all subdomains
# NOTE: Requires API token with "SSL and Certificates:Edit" permission
resource "cloudflare_origin_ca_certificate" "eldertree_xyz" {
  count = local.cloudflare_enabled && var.cloudflare_zone_id != "" ? 1 : 0

  # Certificate configuration
  request_type       = "origin-rsa" # RSA 2048-bit key
  requested_validity = 5475         # 15 years (maximum)
  csr                = tls_cert_request.eldertree_xyz[0].cert_request_pem

  # Hostnames covered by this certificate
  # Using wildcard to cover all subdomains (eldertree.xyz, swimto.eldertree.xyz, etc.)
  hostnames = [
    "eldertree.xyz",
    "*.eldertree.xyz"
  ]
}

# =============================================================================
# raolivei.me Origin Certificate
# =============================================================================

# Generate private key for raolivei.me Origin Certificate
resource "tls_private_key" "raolivei_me" {
  count     = local.cloudflare_enabled && var.raolivei_me_zone_id != "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate CSR for raolivei.me Origin Certificate
resource "tls_cert_request" "raolivei_me" {
  count           = local.cloudflare_enabled && var.raolivei_me_zone_id != "" ? 1 : 0
  private_key_pem = tls_private_key.raolivei_me[0].private_key_pem

  subject {
    common_name  = "raolivei.me"
    organization = "Rafael Oliveira"
  }
}

# Cloudflare Origin Certificate for raolivei.me
# Creates Origin CA certificate for raolivei.me and all subdomains
# NOTE: Requires API token with "SSL and Certificates:Edit" permission
resource "cloudflare_origin_ca_certificate" "raolivei_me" {
  count = local.cloudflare_enabled && var.raolivei_me_zone_id != "" ? 1 : 0

  request_type       = "origin-rsa"
  requested_validity = 5475 # 15 years (maximum)
  csr                = tls_cert_request.raolivei_me[0].cert_request_pem

  hostnames = [
    "raolivei.me",
    "*.raolivei.me"
  ]
}

# NOTE: TLS certificates are managed by cert-manager via Helm charts
# See: clusters/eldertree/core-infrastructure/issuers/
# 
# For Cloudflare Origin Certificates (if needed):
# 1. Create certificate manually via Cloudflare Dashboard (if API token lacks permissions)
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
    # IMPORTANT: Using ClusterIP (10.43.23.214) instead of DNS name (traefik.kube-system.svc.cluster.local)
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
      service  = "http://10.43.23.214:80"
    }

    # API service route (path-based)
    ingress_rule {
      hostname = "swimto.eldertree.xyz"
      path     = "/api/*"
      service  = "http://10.43.23.214:80"
    }

    # Visage AI headshots routes
    ingress_rule {
      hostname = "visage.eldertree.xyz"
      path     = "/"
      service  = "http://10.43.23.214:80"
    }

    ingress_rule {
      hostname = "visage.eldertree.xyz"
      path     = "/api/*"
      service  = "http://10.43.23.214:80"
    }

    ingress_rule {
      hostname = "visage.eldertree.xyz"
      path     = "/health"
      service  = "http://10.43.23.214:80"
    }

    # Pitanga website routes
    ingress_rule {
      hostname = "pitanga.cloud"
      path     = "/"
      service  = "http://10.43.23.214:80"
    }

    ingress_rule {
      hostname = "www.pitanga.cloud"
      path     = "/"
      service  = "http://10.43.23.214:80"
    }

    ingress_rule {
      hostname = "northwaysignal.pitanga.cloud"
      path     = "/"
      service  = "http://10.43.23.214:80"
    }

    # swimto.app routes
    ingress_rule {
      hostname = "swimto.app"
      path     = "/"
      service  = "http://10.43.23.214:80"
    }

    ingress_rule {
      hostname = "swimto.app"
      path     = "/api/*"
      service  = "http://10.43.23.214:80"
    }

    ingress_rule {
      hostname = "www.swimto.app"
      path     = "/"
      service  = "http://10.43.23.214:80"
    }

    ingress_rule {
      hostname = "api.swimto.app"
      path     = "/"
      service  = "http://10.43.23.214:80"
    }

    # raolivei.me routes (personal website)
    ingress_rule {
      hostname = "raolivei.me"
      path     = "/"
      service  = "http://10.43.23.214:80"
    }

    ingress_rule {
      hostname = "www.raolivei.me"
      path     = "/"
      service  = "http://10.43.23.214:80"
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

# DNS CNAME record for visage.eldertree.xyz pointing to tunnel
# Visage AI headshot generator - external access via Cloudflare Tunnel
resource "cloudflare_record" "visage_eldertree_xyz_tunnel" {
  count           = local.cloudflare_enabled && var.cloudflare_account_id != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.eldertree_xyz[0].id
  name            = "visage"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id}.cfargotunnel.com"
  type            = "CNAME"
  ttl             = 1    # Must be 1 when proxied=true
  proxied         = true # Enable Cloudflare proxy (orange cloud) for automatic HTTPS
  allow_overwrite = true
  comment         = "visage.eldertree.xyz - Visage AI headshots via Cloudflare Tunnel - managed by Terraform"
}

# DNS CNAME record for blog.eldertree.xyz pointing to GitHub Pages
# This creates the DNS record for the pi-fleet-blog GitHub Pages site
resource "cloudflare_record" "blog_eldertree_xyz_github_pages" {
  count           = local.cloudflare_enabled && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.eldertree_xyz[0].id
  name            = "blog"
  content         = "raolivei.github.io"
  type            = "CNAME"
  ttl             = 1    # Must be 1 when proxied=true
  proxied         = true # Enable Cloudflare proxy (orange cloud) for automatic HTTPS
  allow_overwrite = true
  comment         = "blog.eldertree.xyz - GitHub Pages for pi-fleet-blog - managed by Terraform"
}

# DNS CNAME record for docs.eldertree.xyz pointing to GitHub Pages
# This creates the DNS record for the eldertree-docs runbook site
resource "cloudflare_record" "docs_eldertree_xyz_github_pages" {
  count           = local.cloudflare_enabled && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.eldertree_xyz[0].id
  name            = "docs"
  content         = "raolivei.github.io"
  type            = "CNAME"
  ttl             = 1    # Must be 1 when proxied=true
  proxied         = true # Enable Cloudflare proxy (orange cloud) for automatic HTTPS
  allow_overwrite = true
  comment         = "docs.eldertree.xyz - GitHub Pages for eldertree-docs runbook - managed by Terraform"
}

# =============================================================================
# pitanga.cloud DNS Records - Point to Cloudflare Tunnel
# =============================================================================

# DNS CNAME record for pitanga.cloud (root domain)
resource "cloudflare_record" "pitanga_cloud_root" {
  count           = local.cloudflare_enabled && var.cloudflare_account_id != "" && var.pitanga_cloud_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.pitanga_cloud[0].id
  name            = "@"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id}.cfargotunnel.com"
  type            = "CNAME"
  ttl             = 1    # Must be 1 when proxied=true
  proxied         = true # Enable Cloudflare proxy for automatic HTTPS
  allow_overwrite = true
  comment         = "pitanga.cloud - Pitanga Systems website via Cloudflare Tunnel - managed by Terraform"
}

# DNS CNAME record for www.pitanga.cloud
resource "cloudflare_record" "pitanga_cloud_www" {
  count           = local.cloudflare_enabled && var.cloudflare_account_id != "" && var.pitanga_cloud_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.pitanga_cloud[0].id
  name            = "www"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id}.cfargotunnel.com"
  type            = "CNAME"
  ttl             = 1    # Must be 1 when proxied=true
  proxied         = true # Enable Cloudflare proxy for automatic HTTPS
  allow_overwrite = true
  comment         = "www.pitanga.cloud - Pitanga Systems website via Cloudflare Tunnel - managed by Terraform"
}

# DNS CNAME record for northwaysignal.pitanga.cloud
resource "cloudflare_record" "pitanga_cloud_northwaysignal" {
  count           = local.cloudflare_enabled && var.cloudflare_account_id != "" && var.pitanga_cloud_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.pitanga_cloud[0].id
  name            = "northwaysignal"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id}.cfargotunnel.com"
  type            = "CNAME"
  ttl             = 1    # Must be 1 when proxied=true
  proxied         = true # Enable Cloudflare proxy for automatic HTTPS
  allow_overwrite = true
  comment         = "northwaysignal.pitanga.cloud - NorthwaySignal website via Cloudflare Tunnel - managed by Terraform"
}

# =============================================================================
# swimto.app DNS Records - Point to Cloudflare Tunnel
# =============================================================================

# DNS CNAME record for swimto.app (root domain)
resource "cloudflare_record" "swimto_app_root" {
  count           = local.cloudflare_enabled && var.cloudflare_account_id != "" && var.swimto_app_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.swimto_app[0].id
  name            = "@"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id}.cfargotunnel.com"
  type            = "CNAME"
  ttl             = 1    # Must be 1 when proxied=true
  proxied         = true # Enable Cloudflare proxy for automatic HTTPS
  allow_overwrite = true
  comment         = "swimto.app - SwimTO via Cloudflare Tunnel - managed by Terraform"
}

# DNS CNAME record for www.swimto.app
resource "cloudflare_record" "swimto_app_www" {
  count           = local.cloudflare_enabled && var.cloudflare_account_id != "" && var.swimto_app_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.swimto_app[0].id
  name            = "www"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id}.cfargotunnel.com"
  type            = "CNAME"
  ttl             = 1    # Must be 1 when proxied=true
  proxied         = true # Enable Cloudflare proxy for automatic HTTPS
  allow_overwrite = true
  comment         = "www.swimto.app - SwimTO via Cloudflare Tunnel - managed by Terraform"
}

# DNS CNAME record for api.swimto.app
resource "cloudflare_record" "swimto_app_api" {
  count           = local.cloudflare_enabled && var.cloudflare_account_id != "" && var.swimto_app_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.swimto_app[0].id
  name            = "api"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id}.cfargotunnel.com"
  type            = "CNAME"
  ttl             = 1    # Must be 1 when proxied=true
  proxied         = true # Enable Cloudflare proxy for automatic HTTPS
  allow_overwrite = true
  comment         = "api.swimto.app - SwimTO API via Cloudflare Tunnel - managed by Terraform"
}

# =============================================================================
# raolivei.me DNS Records - Point to Cloudflare Tunnel
# =============================================================================

# DNS CNAME record for raolivei.me (root domain)
resource "cloudflare_record" "raolivei_me_root" {
  count           = local.cloudflare_enabled && var.cloudflare_account_id != "" && var.raolivei_me_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.raolivei_me[0].id
  name            = "@"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id}.cfargotunnel.com"
  type            = "CNAME"
  ttl             = 1    # Must be 1 when proxied=true
  proxied         = true # Enable Cloudflare proxy for automatic HTTPS
  allow_overwrite = true
  comment         = "raolivei.me - Personal website via Cloudflare Tunnel - managed by Terraform"
}

# DNS CNAME record for www.raolivei.me
resource "cloudflare_record" "raolivei_me_www" {
  count           = local.cloudflare_enabled && var.cloudflare_account_id != "" && var.raolivei_me_zone_id != "" ? 1 : 0
  zone_id         = data.cloudflare_zone.raolivei_me[0].id
  name            = "www"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id}.cfargotunnel.com"
  type            = "CNAME"
  ttl             = 1    # Must be 1 when proxied=true
  proxied         = true # Enable Cloudflare proxy for automatic HTTPS
  allow_overwrite = true
  comment         = "www.raolivei.me - Personal website via Cloudflare Tunnel - managed by Terraform"
}

# Output zone ID for External-DNS integration
output "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for eldertree.xyz (for External-DNS configuration)"
  value       = var.cloudflare_api_token != "" && var.cloudflare_zone_id != "" ? data.cloudflare_zone.eldertree_xyz[0].id : null
  sensitive   = true
}

# Output Cloudflare Tunnel information
output "cloudflare_tunnel_id" {
  description = "Cloudflare Tunnel ID for eldertree"
  value       = var.cloudflare_api_token != "" && var.cloudflare_account_id != "" ? cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id : null
  sensitive   = true
}

output "cloudflare_tunnel_name" {
  description = "Cloudflare Tunnel name"
  value       = var.cloudflare_api_token != "" && var.cloudflare_account_id != "" ? cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].name : null
  sensitive   = true
}

output "cloudflare_tunnel_token" {
  description = "Cloudflare Tunnel token - use this for TUNNEL_TOKEN in Kubernetes. Get from Cloudflare Dashboard after tunnel is created, or use cloudflared tunnel token command."
  value       = "" # Token must be obtained from Cloudflare Dashboard or generated via cloudflared CLI
  sensitive   = true
}

output "cloudflare_tunnel_cname" {
  description = "CNAME target for tunnel DNS records"
  value       = var.cloudflare_api_token != "" && var.cloudflare_account_id != "" ? "${cloudflare_zero_trust_tunnel_cloudflared.eldertree[0].id}.cfargotunnel.com" : null
  sensitive   = true
}

# =============================================================================
# eldertree.xyz Origin Certificate Outputs
# =============================================================================

output "eldertree_xyz_origin_cert" {
  description = "Origin certificate for eldertree.xyz - use with kubectl create secret tls"
  value       = local.cloudflare_enabled && var.cloudflare_zone_id != "" ? cloudflare_origin_ca_certificate.eldertree_xyz[0].certificate : null
  sensitive   = true
}

output "eldertree_xyz_origin_key" {
  description = "Private key for eldertree.xyz origin certificate"
  value       = local.cloudflare_enabled && var.cloudflare_zone_id != "" ? tls_private_key.eldertree_xyz[0].private_key_pem : null
  sensitive   = true
}

# =============================================================================
# swimto.app Origin Certificate Outputs
# =============================================================================

output "swimto_app_origin_cert" {
  description = "Origin certificate for swimto.app - use with kubectl create secret tls"
  value       = local.cloudflare_enabled && var.swimto_app_zone_id != "" ? cloudflare_origin_ca_certificate.swimto_app[0].certificate : null
  sensitive   = true
}

output "swimto_app_origin_key" {
  description = "Private key for swimto.app origin certificate"
  value       = local.cloudflare_enabled && var.swimto_app_zone_id != "" ? tls_private_key.swimto_app[0].private_key_pem : null
  sensitive   = true
}

# =============================================================================
# pitanga.cloud Origin Certificate Outputs
# =============================================================================

output "pitanga_cloud_origin_cert" {
  description = "Origin certificate for pitanga.cloud - use with kubectl create secret tls"
  value       = local.cloudflare_enabled && var.pitanga_cloud_zone_id != "" ? cloudflare_origin_ca_certificate.pitanga_cloud[0].certificate : null
  sensitive   = true
}

output "pitanga_cloud_origin_key" {
  description = "Private key for pitanga.cloud origin certificate"
  value       = local.cloudflare_enabled && var.pitanga_cloud_zone_id != "" ? tls_private_key.pitanga_cloud[0].private_key_pem : null
  sensitive   = true
}

# =============================================================================
# raolivei.me Origin Certificate Outputs
# =============================================================================

output "raolivei_me_origin_cert" {
  description = "Origin certificate for raolivei.me - use with kubectl create secret tls"
  value       = local.cloudflare_enabled && var.raolivei_me_zone_id != "" ? cloudflare_origin_ca_certificate.raolivei_me[0].certificate : null
  sensitive   = true
}

output "raolivei_me_origin_key" {
  description = "Private key for raolivei.me origin certificate"
  value       = local.cloudflare_enabled && var.raolivei_me_zone_id != "" ? tls_private_key.raolivei_me[0].private_key_pem : null
  sensitive   = true
}

# NOTE: TLS certificate outputs removed - certificates are managed by cert-manager via Helm
# See: clusters/eldertree/core-infrastructure/issuers/ for cert-manager configuration

