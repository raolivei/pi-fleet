# Infrastructure Policy
# Grants read/write access to infrastructure secrets under secret/pi-fleet/
# All infrastructure secrets are now organized under secret/pi-fleet/

# New structure: secret/pi-fleet/*
path "secret/data/pi-fleet/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/pi-fleet/*" {
  capabilities = ["list", "read", "delete"]
}

# Legacy paths (for backward compatibility during migration)
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

