# Aeron Project Policy
# Grants read/write access to Aeron secrets only

path "secret/data/aeron/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/aeron/*" {
  capabilities = ["list", "read", "delete"]
}

