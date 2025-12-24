# Ollie Project Policy
# Grants read/write access to Ollie secrets only

path "secret/data/ollie/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/ollie/*" {
  capabilities = ["list", "read", "delete"]
}

