# Canopy Project Policy
# Grants read/write access to Canopy secrets only

path "secret/data/canopy/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/canopy/*" {
  capabilities = ["list", "read", "delete"]
}

