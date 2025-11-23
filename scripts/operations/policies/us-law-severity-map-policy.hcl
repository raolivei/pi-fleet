# US Law Severity Map Project Policy
# Grants read/write access to US Law Severity Map secrets only

path "secret/data/us-law-severity-map/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/us-law-severity-map/*" {
  capabilities = ["list", "read", "delete"]
}

