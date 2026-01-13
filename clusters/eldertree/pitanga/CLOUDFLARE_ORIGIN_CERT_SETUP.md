# Cloudflare Origin Certificate Setup for pitanga.cloud

This guide explains how to set up HTTPS for `pitanga.cloud` using Cloudflare Origin Certificates.

## Why Cloudflare Origin Certificates?

- ✅ **Free** - No cost
- ✅ **No port forwarding** - Works behind NAT/firewall
- ✅ **No ACME challenges** - No need to expose ports 80/443
- ✅ **Long validity** - Up to 15 years
- ✅ **Trusted by Cloudflare** - Works with Cloudflare proxy
- ✅ **Infrastructure as Code** - Managed with Terraform
- ✅ **Version controlled** - Certificate configuration in Git
- ✅ **Easy updates** - Add new hostnames via Terraform

## Prerequisites

1. Domain `pitanga.cloud` added to Cloudflare
2. Cloudflare API token stored in Vault (for Terraform and External-DNS)
   - **IMPORTANT**: Token must have "SSL and Certificates:Edit" permission
   - See [ORIGIN_CERT_API_PERMISSIONS.md](../../terraform/ORIGIN_CERT_API_PERMISSIONS.md)
3. External-DNS configured for Cloudflare DNS
4. Terraform configured with `pitanga_cloud_zone_id` variable

## Setup Methods

### Method 1: Terraform (Recommended) ⭐

**Automated, Infrastructure as Code approach:**

1. **Configure Terraform Variables**

   Add to `terraform/terraform.tfvars` or set via environment:

   ```hcl
   pitanga_cloud_zone_id = "your-pitanga-cloud-zone-id"
   ```

   To find the zone ID:

   - Cloudflare Dashboard → Select `pitanga.cloud` → Overview → Zone ID

2. **Apply Terraform Configuration**

   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet/terraform
   ./run-terraform.sh plan   # Review changes
   ./run-terraform.sh apply  # Create certificate
   ```

   This automatically:

   - Creates Origin Certificate for `pitanga.cloud` and `*.pitanga.cloud`
   - Generates private key (RSA 2048-bit)
   - Sets validity to 15 years (maximum)

3. **Store Certificate in Vault**

   ```bash
   ./scripts/store-pitanga-cert-from-terraform.sh
   ```

   This automatically:

   - Retrieves the certificate from Terraform output
   - Validates certificate format
   - Stores in Vault at `secret/pitanga/cloudflare-origin-cert`
   - Verifies the certificate was stored correctly

4. **Verify Setup**

   ```bash
   # Check ExternalSecret sync
   kubectl get externalsecret pitanga-cloudflare-origin-cert -n pitanga

   # Check Kubernetes secret
   kubectl get secret pitanga-cloudflare-origin-tls -n pitanga

   # Check Terraform outputs
   terraform output pitanga_cloud_origin_certificate
   terraform output pitanga_cloud_certificate_id
   ```

**Benefits:**

- ✅ Fully automated
- ✅ Version controlled
- ✅ Reproducible
- ✅ Easy to add new hostnames (just update Terraform)
- ✅ Certificate automatically created with correct hostnames

### Method 2: Manual Setup

**Manual approach via Cloudflare Dashboard:**

### 1. Generate Cloudflare Origin Certificate

1. **Log in to Cloudflare Dashboard**

   - Go to https://dash.cloudflare.com
   - Select your `pitanga.cloud` domain

2. **Navigate to SSL/TLS Settings**

   - Go to **SSL/TLS** → **Origin Server**
   - Click **Create Certificate**

3. **Configure Certificate**

   - **Private key type**: RSA (2048)
   - **Hostnames**:
     - `pitanga.cloud` (root domain)
     - `*.pitanga.cloud` (wildcard - covers all subdomains including www.pitanga.cloud and northwaysignal.pitanga.cloud)
     - **Recommended**: Use wildcard to avoid forgetting hostnames
   - **Certificate Validity**: 15 years (maximum)
   - Click **Create**

4. **Download Certificate**
   - Cloudflare will show:
     - **Origin Certificate** (the certificate)
     - **Private Key** (keep this secret!)
   - Copy both values - you'll need them in the next step

### 2. Store Certificate in Vault

The certificate is managed via Vault and synced to Kubernetes using External Secrets Operator.

**Option A: From Terraform (Recommended if using Terraform)**

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/terraform
./scripts/store-pitanga-cert-from-terraform.sh
```

**Option B: Manual Vault storage (if certificate was created manually)**

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Get Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Store certificate in Vault
kubectl exec -n vault $VAULT_POD -- vault kv put secret/pitanga/cloudflare-origin-cert \
  certificate="$(cat origin.pem)" \
  private-key="$(cat origin.key)"
```

### 3. Apply ExternalSecret

The ExternalSecret resource automatically syncs the certificate from Vault to Kubernetes:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Apply ExternalSecret (if using GitOps, this is already applied)
kubectl apply -f pi-fleet/clusters/eldertree/pitanga/cloudflare-origin-cert-external.yaml

# Verify ExternalSecret sync
kubectl get externalsecret pitanga-cloudflare-origin-cert -n pitanga

# Check the created secret
kubectl get secret pitanga-cloudflare-origin-tls -n pitanga
```

The ExternalSecret will:

- Read certificate and private key from Vault (`secret/pitanga/cloudflare-origin-cert`)
- Create a TLS secret (`pitanga-cloudflare-origin-tls`) with type `kubernetes.io/tls`
- Automatically refresh every 24 hours

### 3. Configure Cloudflare SSL/TLS Mode

1. **In Cloudflare Dashboard**

   - Go to **SSL/TLS** → **Overview**
   - Set encryption mode to **Full (strict)**
   - This ensures Cloudflare validates your origin certificate

2. **Enable Proxy (Orange Cloud)**
   - Go to **DNS** → **Records**
   - Find the `pitanga.cloud` and `www.pitanga.cloud` records
   - Ensure the **proxy status** is **Proxied** (orange cloud icon)
   - This enables Cloudflare's automatic HTTPS

### 4. Verify DNS Record

External-DNS should automatically create the DNS records. Verify:

```bash
# Check External-DNS logs
kubectl logs -n external-dns deployment/external-dns-cloudflare -f

# Check DNS records exist
dig pitanga.cloud
dig www.pitanga.cloud

# Should show Cloudflare IP addresses (not your origin IP)
```

### 4. Deploy Ingress Changes

The ingress is already configured to use the Cloudflare Origin Certificate. Apply changes:

```bash
# If using FluxCD (automatic sync)
git add clusters/eldertree/pitanga/website-ingress.yaml
git commit -m "Configure pitanga.cloud with Cloudflare Origin Certificate"
git push origin main

# Or apply manually
kubectl apply -f clusters/eldertree/pitanga/website-ingress.yaml
```

### 5. Verify HTTPS Access

```bash
# Test HTTPS endpoint
curl -v https://pitanga.cloud
curl -v https://www.pitanga.cloud

# Should show:
# - Valid SSL certificate
# - HTTPS connection successful
# - No certificate warnings
```

## Troubleshooting

### Certificate Not Working

1. **Check secret exists:**

   ```bash
   kubectl get secret pitanga-cloudflare-origin-tls -n pitanga
   ```

2. **Verify certificate format:**

   ```bash
   kubectl get secret pitanga-cloudflare-origin-tls -n pitanga -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
   ```

3. **Check ingress is using the secret:**
   ```bash
   kubectl describe ingress pitanga-website-public -n pitanga
   ```

### Cloudflare SSL Errors

1. **Check SSL/TLS mode:**

   - Must be "Full" or "Full (strict)"
   - "Flexible" won't work (Cloudflare → Origin is HTTP)

2. **Verify proxy is enabled:**

   - DNS records must have orange cloud (proxied)
   - Gray cloud = DNS only (no HTTPS from Cloudflare)

3. **Check certificate matches domain:**
   - Certificate must include `pitanga.cloud`, `www.pitanga.cloud`, and `northwaysignal.pitanga.cloud`
   - Or use wildcard `*.pitanga.cloud` to cover all subdomains
   - Regenerate if domain doesn't match

### DNS Not Resolving

1. **Check External-DNS:**

   ```bash
   kubectl logs -n external-dns deployment/external-dns-cloudflare
   ```

2. **Verify Cloudflare API token:**

   ```bash
   # Check ExternalSecret sync status
   kubectl describe externalsecret external-dns-cloudflare-secret -n external-dns
   ```

3. **Manually create DNS records in Cloudflare Dashboard:**
   - Type: CNAME or A
   - Name: `pitanga` and `www`
   - Content: Your cluster's public IP (or use Cloudflare Tunnel)
   - Proxy: Enabled (orange cloud)

## Certificate Renewal

Cloudflare Origin Certificates are valid for up to 15 years. When renewal is needed:

1. Generate a new certificate in Cloudflare Dashboard
2. Update the Kubernetes secret:
   ```bash
   kubectl create secret tls pitanga-cloudflare-origin-tls \
     --cert=origin.pem \
     --key=origin.key \
     -n pitanga \
     --dry-run=client -o yaml | kubectl apply -f -
   ```
3. Traefik will automatically pick up the new certificate

## Security Notes

- **Keep private key secure** - Never commit to git
- **Use Vault** - Store secrets in Vault for production
- **Full (strict) mode** - Ensures end-to-end encryption validation
- **Wildcard certificates** - Can be used for multiple subdomains

## References

- [Cloudflare Origin Certificates Documentation](https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/)
- [Cloudflare SSL/TLS Modes](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)
