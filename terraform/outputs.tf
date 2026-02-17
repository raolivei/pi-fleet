# NOTE: k3s installation is handled by Ansible, not Terraform.
# Cluster-related outputs are no longer available here.
# Use Ansible playbooks to install k3s and retrieve kubeconfig.

# Output Cloudflare Origin Certificate for pitanga.cloud
output "pitanga_cloud_origin_certificate" {
  description = "Cloudflare Origin Certificate for pitanga.cloud (PEM format)"
  value       = local.cloudflare_enabled && var.pitanga_cloud_zone_id != "" ? cloudflare_origin_ca_certificate.pitanga_cloud[0].certificate : null
  sensitive   = true
}

output "pitanga_cloud_origin_private_key" {
  description = "Private key for pitanga.cloud Origin Certificate (PEM format)"
  value       = local.cloudflare_enabled && var.pitanga_cloud_zone_id != "" ? tls_private_key.pitanga_cloud[0].private_key_pem : null
  sensitive   = true
}

output "pitanga_cloud_certificate_id" {
  description = "Cloudflare Origin Certificate ID for pitanga.cloud"
  value       = local.cloudflare_enabled && var.pitanga_cloud_zone_id != "" ? cloudflare_origin_ca_certificate.pitanga_cloud[0].id : null
  sensitive   = true
}
