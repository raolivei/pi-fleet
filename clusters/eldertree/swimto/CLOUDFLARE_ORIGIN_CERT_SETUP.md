# Cloudflare Origin Certificate Setup for swimto.eldertree.xyz

This guide explains how to set up HTTPS for `swimto.eldertree.xyz` using Cloudflare Origin Certificates instead of Let's Encrypt.

## Why Cloudflare Origin Certificates?

- ✅ **Free** - No cost
- ✅ **No port forwarding** - Works behind NAT/firewall
- ✅ **No ACME challenges** - No need to expose ports 80/443
- ✅ **Long validity** - Up to 15 years
- ✅ **Trusted by Cloudflare** - Works with Cloudflare proxy
- ✅ **Simple setup** - Generate once, use for years
- ✅ **Infrastructure as Code** - Managed with Terraform

## Prerequisites

1. Domain `eldertree.xyz` added to Cloudflare
2. Cloudflare API token stored in Vault (for Terraform and External-DNS)
3. Terraform configured (recommended) OR manual setup
4. External-DNS configured for Cloudflare DNS

## Setup Methods

### Method 1: Terraform (Recommended) ⭐

**Automated, Infrastructure as Code approach:**

1. **Apply Terraform Configuration**
   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet/terraform
   terraform init
   terraform plan
   terraform apply
   ```

2. **Store Certificate in Kubernetes**
   ```bash
   ./scripts/store-swimto-cert-from-terraform.sh swimto
   ```

   This automatically:
   - Retrieves the certificate from Terraform output
   - Validates certificate format
   - Creates Kubernetes secret `swimto-cloudflare-origin-tls`
   - Verifies the secret was created correctly

3. **Verify Setup**
   ```bash
   # Check secret exists
   kubectl get secret swimto-cloudflare-origin-tls -n swimto
   
   # Check Terraform outputs
   terraform output swimto_origin_certificate
   terraform output swimto_certificate_id
   ```

**Benefits:**
- ✅ Fully automated
- ✅ Version controlled
- ✅ Reproducible
- ✅ Certificate automatically created
- ✅ DNS record automatically created with proxy enabled

### Method 2: Manual Setup

**Manual approach via Cloudflare Dashboard:**

### 1. Generate Cloudflare Origin Certificate

1. **Log in to Cloudflare Dashboard**
   - Go to https://dash.cloudflare.com
   - Select your `eldertree.xyz` domain

2. **Navigate to SSL/TLS Settings**
   - Go to **SSL/TLS** → **Origin Server**
   - Click **Create Certificate**

3. **Configure Certificate**
   - **Private key type**: RSA (2048)
   - **Hostnames**: 
     - `*.eldertree.xyz` (wildcard for all subdomains)
     - `eldertree.xyz` (root domain)
   - **Certificate Validity**: 15 years (maximum)
   - Click **Create**

4. **Download Certificate**
   - Cloudflare will show:
     - **Origin Certificate** (the certificate)
     - **Private Key** (keep this secret!)
   - Copy both values - you'll need them in the next step

### 2. Store Certificate in Kubernetes Secret (Manual Method)

Create a Kubernetes secret with the certificate and private key:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Create secret from certificate files
kubectl create secret tls swimto-cloudflare-origin-tls \
  --cert=origin.pem \
  --key=origin.key \
  -n swimto \
  --dry-run=client -o yaml | kubectl apply -f -

# OR create secret directly from values (replace with your actual certificate/key)
kubectl create secret tls swimto-cloudflare-origin-tls \
  --cert=<(echo "YOUR_ORIGIN_CERTIFICATE_HERE") \
  --key=<(echo "YOUR_PRIVATE_KEY_HERE") \
  -n swimto
```

**Alternative: Store in Vault and sync via External Secrets**

If you prefer to manage secrets via Vault:

```bash
# Get Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Store certificate
kubectl exec -n vault $VAULT_POD -- vault kv put secret/swimto/cloudflare-origin-cert \
  certificate="$(cat origin.pem)" \
  private-key="$(cat origin.key)"
```

Then create an ExternalSecret resource (see External Secrets Operator documentation).

### 3. Configure Cloudflare SSL/TLS Mode

1. **In Cloudflare Dashboard**
   - Go to **SSL/TLS** → **Overview**
   - Set encryption mode to **Full (strict)**
   - This ensures Cloudflare validates your origin certificate

2. **Enable Proxy (Orange Cloud)**
   - Go to **DNS** → **Records**
   - Find the `swimto.eldertree.xyz` record
   - Ensure the **proxy status** is **Proxied** (orange cloud icon)
   - This enables Cloudflare's automatic HTTPS

### 4. Verify DNS Record

External-DNS should automatically create the DNS record. Verify:

```bash
# Check External-DNS logs
kubectl logs -n external-dns deployment/external-dns-cloudflare -f

# Check DNS record exists
dig swimto.eldertree.xyz

# Should show Cloudflare IP addresses (not your origin IP)
```

### 5. Deploy Ingress Changes

The ingress is already configured to use the Cloudflare Origin Certificate. Apply changes:

```bash
# If using FluxCD (automatic sync)
git add clusters/eldertree/swimto/ingress.yaml
git commit -m "Configure swimto.eldertree.xyz with Cloudflare Origin Certificate"
git push origin main

# Or apply manually
kubectl apply -f clusters/eldertree/swimto/ingress.yaml
```

### 6. Verify HTTPS Access

```bash
# Test HTTPS endpoint
curl -v https://swimto.eldertree.xyz

# Should show:
# - Valid SSL certificate
# - HTTPS connection successful
# - No certificate warnings
```

## Troubleshooting

### Certificate Not Working

1. **Check secret exists:**
   ```bash
   kubectl get secret swimto-cloudflare-origin-tls -n swimto
   ```

2. **Verify certificate format:**
   ```bash
   kubectl get secret swimto-cloudflare-origin-tls -n swimto -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
   ```

3. **Check ingress is using the secret:**
   ```bash
   kubectl describe ingress swimto-web-public -n swimto
   ```

### Cloudflare SSL Errors

1. **Check SSL/TLS mode:**
   - Must be "Full" or "Full (strict)"
   - "Flexible" won't work (Cloudflare → Origin is HTTP)

2. **Verify proxy is enabled:**
   - DNS record must have orange cloud (proxied)
   - Gray cloud = DNS only (no HTTPS from Cloudflare)

3. **Check certificate matches domain:**
   - Certificate must include `swimto.eldertree.xyz` or `*.eldertree.xyz`
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

3. **Manually create DNS record in Cloudflare Dashboard:**
   - Type: CNAME or A
   - Name: swimto
   - Content: Your cluster's public IP (or use Cloudflare Tunnel)
   - Proxy: Enabled (orange cloud)

## Certificate Renewal

Cloudflare Origin Certificates are valid for up to 15 years. When renewal is needed:

1. Generate a new certificate in Cloudflare Dashboard
2. Update the Kubernetes secret:
   ```bash
   kubectl create secret tls swimto-cloudflare-origin-tls \
     --cert=origin.pem \
     --key=origin.key \
     -n swimto \
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

