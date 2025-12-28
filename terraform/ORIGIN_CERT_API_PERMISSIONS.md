# Cloudflare Origin CA Certificate API Permissions

## Issue

When trying to create Origin CA certificates via Terraform, you may encounter:

```
Error: error creating origin certificate: User is not authorized to perform this action (1016)
```

## Cause

The Cloudflare API token used for Terraform doesn't have permission to create Origin CA certificates. Standard DNS tokens only have:
- Zone:Read
- DNS:Edit

But Origin CA certificates require:
- **SSL and Certificates:Edit** permission

## Solutions

### Option 1: Create Certificate Manually (Recommended)

Since Origin CA certificates are long-lived (15 years), creating them manually is acceptable:

1. **Generate CSR using Terraform** (already done):
   ```bash
   cd terraform
   terraform apply  # Creates private key and CSR
   terraform output swimto_origin_csr > swimto.csr
   terraform output swimto_origin_private_key > swimto.key
   ```

2. **Create Certificate in Cloudflare Dashboard**:
   - Go to SSL/TLS → Origin Server
   - Click "Create Certificate"
   - Paste the CSR from `swimto.csr`
   - Select hostnames: `swimto.eldertree.xyz` and `*.eldertree.xyz`
   - Set validity: 15 years
   - Copy the certificate

3. **Store in Kubernetes**:
   ```bash
   # Save certificate to file
   echo "PASTE_CERTIFICATE_HERE" > swimto.crt
   
   # Create secret
   kubectl create secret tls swimto-cloudflare-origin-tls \
     --cert=swimto.crt \
     --key=swimto.key \
     -n swimto
   ```

### Option 2: Update API Token Permissions

If you want Terraform to create certificates automatically:

1. **Create New API Token**:
   - Go to Cloudflare Dashboard → My Profile → API Tokens
   - Click "Create Token"
   - Use "Custom token" template
   - Add permissions:
     - **Zone** → **Zone** → **Read**
     - **Zone** → **DNS** → **Edit**
     - **Zone** → **SSL and Certificates** → **Edit** ← **Required for Origin CA**
   - Zone Resources: Include `eldertree.xyz`
   - Create token

2. **Update Token in Vault**:
   ```bash
   VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token=NEW_TOKEN_HERE
   ```

3. **Uncomment Terraform Resource**:
   Edit `terraform/cloudflare.tf` and uncomment the `cloudflare_origin_ca_certificate` resource.

4. **Apply Terraform**:
   ```bash
   terraform apply
   ```

## Current Setup

The Terraform configuration currently:
- ✅ Creates private key and CSR (always works)
- ✅ Creates DNS record with proxy enabled
- ❌ Origin Certificate resource is commented out (requires special permissions)

You can use the generated CSR and private key to create the certificate manually, which is the recommended approach for long-lived certificates.

## References

- [Cloudflare API Token Permissions](https://developers.cloudflare.com/api/tokens/create/permissions/)
- [Origin CA Certificate Setup Guide](../clusters/eldertree/swimto/CLOUDFLARE_ORIGIN_CERT_SETUP.md)

