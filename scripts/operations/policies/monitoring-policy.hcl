# Monitoring Policy
# Grants read/write access to monitoring secrets only

path "secret/data/monitoring/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/monitoring/*" {
  capabilities = ["list", "read", "delete"]
}

