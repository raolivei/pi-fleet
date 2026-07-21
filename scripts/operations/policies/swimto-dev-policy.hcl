# SwimTO Dev Environment Policy
# Grants read/write access to SwimTO dev secrets only

path "secret/data/swimto-dev/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/swimto-dev/*" {
  capabilities = ["list", "read", "delete"]
}
