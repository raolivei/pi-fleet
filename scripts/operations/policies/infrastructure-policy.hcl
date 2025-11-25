# Infrastructure Policy
# Grants read/write access to infrastructure secrets (pihole, flux, external-dns, terraform, cloudflare-tunnel)

path "secret/data/pihole/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/pihole/*" {
  capabilities = ["list", "read", "delete"]
}

path "secret/data/flux/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/flux/*" {
  capabilities = ["list", "read", "delete"]
}

path "secret/data/external-dns/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/external-dns/*" {
  capabilities = ["list", "read", "delete"]
}

path "secret/data/terraform/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/terraform/*" {
  capabilities = ["list", "read", "delete"]
}

path "secret/data/cloudflare-tunnel/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/cloudflare-tunnel/*" {
  capabilities = ["list", "read", "delete"]
}

