# Quick Setup Guide: Cloudflare Origin Certificate for pitanga.cloud

This guide walks you through setting up the Cloudflare Origin Certificate using Terraform.

## Prerequisites Check

1. ✅ Domain `pitanga.cloud` added to Cloudflare
2. ✅ Cloudflare API token in Vault with "SSL and Certificates:Edit" permission
3. ⚠️  Need to get Zone ID for pitanga.cloud

## Step 1: Get Zone ID

**Option A: Using the helper script (Recommended)**

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform
./scripts/get-pitanga-zone-id.sh
```

This will output the Zone ID. Copy it.

**Option B: From Cloudflare Dashboard**

1. Go to https://dash.cloudflare.com
2. Select `pitanga.cloud` domain
3. Scroll down to find "Zone ID" in the Overview section
4. Copy the Zone ID

## Step 2: Configure Terraform

**Option A: Add to terraform.tfvars (if file exists)**

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform

# If terraform.tfvars doesn't exist, create it from example
cp terraform.tfvars.example terraform.tfvars

# Add the zone ID
echo 'pitanga_cloud_zone_id = "YOUR_ZONE_ID_HERE"' >> terraform.tfvars
```

**Option B: Set as environment variable**

```bash
export TF_VAR_pitanga_cloud_zone_id="YOUR_ZONE_ID_HERE"
```

## Step 3: Verify API Token Permissions

The API token must have "SSL and Certificates:Edit" permission. Check:

1. Go to Cloudflare Dashboard → My Profile → API Tokens
2. Find your token (or create a new one)
3. Ensure it has:
   - **Zone** → **Zone** → **Read**
   - **Zone** → **DNS** → **Edit**
   - **Zone** → **SSL and Certificates** → **Edit** ← **Required**

If missing, create a new token with these permissions and update it in Vault.

## Step 4: Plan Terraform Changes

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform
./run-terraform.sh plan
```

Review the output. You should see:
- `cloudflare_origin_ca_certificate.pitanga_cloud` will be created
- Certificate will include `pitanga.cloud` and `*.pitanga.cloud`

## Step 5: Apply Terraform

```bash
./run-terraform.sh apply
```

This will:
- Create the Origin Certificate in Cloudflare
- Generate the certificate and private key
- Make them available via Terraform outputs

## Step 6: Store Certificate in Vault

```bash
./scripts/store-pitanga-cert-from-terraform.sh
```

This will:
- Retrieve certificate from Terraform output
- Validate the certificate format
- Store in Vault at `secret/pitanga/cloudflare-origin-cert`

## Step 7: Verify Setup

```bash
# Check ExternalSecret sync
kubectl get externalsecret pitanga-cloudflare-origin-cert -n pitanga

# Check Kubernetes secret
kubectl get secret pitanga-cloudflare-origin-tls -n pitanga

# View certificate details
kubectl get secret pitanga-cloudflare-origin-tls -n pitanga -o jsonpath='{.data.tls\.crt}' | \
    base64 -d | openssl x509 -text -noout | grep -E "(Subject:|Issuer:|Validity|DNS:)"
```

## Step 8: Configure Cloudflare SSL Mode

1. Go to Cloudflare Dashboard → Select `pitanga.cloud`
2. Navigate to **SSL/TLS** → **Overview**
3. Set encryption mode to **Full (strict)**
4. This ensures Cloudflare validates your origin certificate

## Troubleshooting

### Error: "User is not authorized to perform this action (1016)"

Your API token doesn't have "SSL and Certificates:Edit" permission. See Step 3 above.

### Error: "Zone not found"

- Verify domain is added to Cloudflare
- Check zone ID is correct
- Ensure API token has Zone:Read permission

### Certificate not syncing to Kubernetes

- Check ExternalSecret status: `kubectl describe externalsecret pitanga-cloudflare-origin-cert -n pitanga`
- Check Vault secret exists: Use `remove-cert-from-vault.sh` script to verify
- Re-apply ExternalSecret: `kubectl apply -f clusters/eldertree/pitanga/cloudflare-origin-cert-external.yaml`

## Next Steps

Once the certificate is set up:
- Both `pitanga.cloud` and `northwaysignal.pitanga.cloud` will work (wildcard covers all subdomains)
- Certificate is valid for 15 years
- To add more hostnames, update `cloudflare.tf` and run `terraform apply`


