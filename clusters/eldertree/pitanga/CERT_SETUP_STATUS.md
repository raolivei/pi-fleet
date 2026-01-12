# Certificate Setup Status

## ✅ Completed Steps

1. **Terraform Configuration** - Certificate resource configured
2. **Private Key Generated** - RSA 2048-bit key created
3. **CSR Generated** - Certificate Signing Request created
4. **Files Extracted** - CSR and private key saved to `/tmp/pitanga.csr` and `/tmp/pitanga.key`

## ⚠️ Current Status

The API token doesn't have "SSL and Certificates:Edit" permission, so the certificate needs to be created manually in the Cloudflare Dashboard.

## 📋 Next Steps

### Step 1: Create Certificate in Cloudflare Dashboard

1. **Go to Cloudflare Dashboard:**
   - Visit: https://dash.cloudflare.com
   - Select `pitanga.cloud` domain

2. **Navigate to SSL/TLS:**
   - Go to **SSL/TLS** → **Origin Server**
   - Click **Create Certificate**

3. **Upload CSR:**
   - Select **Upload CSR** option
   - Open `/tmp/pitanga.csr` and copy the entire contents (including BEGIN/END lines)
   - Paste into the CSR field

4. **Configure Certificate:**
   - **Hostnames**: 
     - `pitanga.cloud`
     - `*.pitanga.cloud` (wildcard)
   - **Certificate Validity**: 15 years (maximum)
   - Click **Create**

5. **Copy Certificate:**
   - Cloudflare will show the certificate
   - Copy the entire certificate (including BEGIN/END lines)

### Step 2: Store Certificate in Vault

**Option A: Using the script (Recommended)**

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform

# Save certificate to a file first
echo "PASTE_CERTIFICATE_HERE" > /tmp/pitanga.crt

# Store in Vault
./scripts/store-pitanga-cert-manual.sh /tmp/pitanga.crt /tmp/pitanga.key
```

**Option B: Manual Vault storage**

```bash
export KUBECONFIG=~/.kube/config-eldertree
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Store certificate (replace CERT_CONTENT and KEY_CONTENT)
kubectl exec -n vault $VAULT_POD -- vault kv put secret/pitanga/cloudflare-origin-cert \
  certificate="$(cat /tmp/pitanga.crt)" \
  private-key="$(cat /tmp/pitanga.key)"
```

### Step 3: Verify Setup

```bash
# Check ExternalSecret sync
kubectl get externalsecret pitanga-cloudflare-origin-cert -n pitanga

# Check Kubernetes secret
kubectl get secret pitanga-cloudflare-origin-tls -n pitanga

# View certificate details
kubectl get secret pitanga-cloudflare-origin-tls -n pitanga -o jsonpath='{.data.tls\.crt}' | \
    base64 -d | openssl x509 -text -noout | grep -E "(Subject:|Issuer:|Validity|DNS:)"
```

### Step 4: Configure Cloudflare SSL Mode

1. Go to Cloudflare Dashboard → Select `pitanga.cloud`
2. Navigate to **SSL/TLS** → **Overview**
3. Set encryption mode to **Full (strict)**

## Files Available

- **CSR**: `/tmp/pitanga.csr` - Use this to create certificate in Cloudflare
- **Private Key**: `/tmp/pitanga.key` - Keep this secure, needed for Vault storage

## Alternative: Update API Token Permissions

If you want Terraform to create certificates automatically in the future:

1. **Create New API Token:**
   - Cloudflare Dashboard → My Profile → API Tokens
   - Create custom token with:
     - **Zone** → **Zone** → **Read**
     - **Zone** → **DNS** → **Edit**
     - **Zone** → **SSL and Certificates** → **Edit** ← **Required**
   - Zone Resources: Include `pitanga.cloud`

2. **Update Token in Vault:**
   ```bash
   VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token='NEW_TOKEN'
   ```

3. **Re-run Terraform:**
   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet/terraform
   terraform apply -target='cloudflare_origin_ca_certificate.pitanga_cloud[0]'
   ```

## Summary

- ✅ Private key and CSR generated via Terraform
- ⏳ Certificate needs to be created manually in Cloudflare Dashboard
- ⏳ Certificate needs to be stored in Vault
- ⏳ ExternalSecret will sync to Kubernetes automatically


