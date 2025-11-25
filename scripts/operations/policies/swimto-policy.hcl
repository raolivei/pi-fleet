# SwimTO Project Policy
# Grants read/write access to SwimTO secrets only

path "secret/data/swimto/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/swimto/*" {
  capabilities = ["list", "read", "delete"]
}

