# Journey Project Policy
# Grants read/write access to Journey secrets only

path "secret/data/journey/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/journey/*" {
  capabilities = ["list", "read", "delete"]
}

