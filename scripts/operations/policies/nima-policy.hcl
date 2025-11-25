# NIMA Project Policy
# Grants read/write access to NIMA secrets only

path "secret/data/nima/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/nima/*" {
  capabilities = ["list", "read", "delete"]
}

