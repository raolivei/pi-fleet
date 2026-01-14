# Cloudflare API Token Permissions for Origin Certificates

## Required Permissions

When creating or editing your `eldertree-terraform-full` token, you need these **exact** permissions:

### Account-Level Permissions (CRITICAL)

1. **Account** → **Cloudflare Tunnel** → **Edit** ✅
   - Required for managing Cloudflare Tunnels

2. **Account** → **SSL and Certificates** → **Edit** ✅ **← THIS IS THE KEY ONE**
   - **Required for creating Origin Certificates**
   - This is often the missing permission that causes error 1016

### Zone-Level Permissions

3. **Zone** → **Zone** → **Read** ✅
   - Required to read zone information

4. **Zone** → **DNS** → **Edit** ✅
   - Required for DNS record management

5. **Zone** → **SSL and Certificates** → **Edit** ✅ (Optional but recommended)
   - Additional zone-level SSL permission

## Resource Configuration

### Account Resources
- **Include** → **All accounts** (or your specific account)

### Zone Resources
- **Include** → **Specific zone** → `pitanga.cloud`
- OR **Include** → **All zones** (if you manage multiple domains)

## Step-by-Step in Cloudflare Dashboard

1. Go to: https://dash.cloudflare.com/profile/api-tokens
2. Find your token: `eldertree-terraform-full`
3. Click the `...` button → **Edit**
4. Scroll to **Permissions** section

5. **Add Account Permissions:**
   - Click **Add** under Account permissions
   - Select: **Account** → **SSL and Certificates** → **Edit**
   - Click **Add permission**

6. **Verify Zone Permissions:**
   - Make sure **Zone** → **Zone** → **Read** is present
   - Make sure **Zone** → **DNS** → **Edit** is present
   - Add **Zone** → **SSL and Certificates** → **Edit** if missing

7. **Verify Resources:**
   - Account Resources: Should include your account
   - Zone Resources: Should include `pitanga.cloud`

8. Click **Continue to summary** → **Save**

## Important Notes

- **Account-level SSL permission is critical** - Zone-level alone may not be enough
- The token value usually stays the same when you edit permissions (unless you regenerate it)
- After saving, wait a few seconds for permissions to propagate
- Then re-run Terraform with the same token

## Verify Token Works

After updating permissions, test with:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform
export TF_VAR_pitanga_cloud_zone_id="4d674555d7344d4b5d46681fd17b49bd"
export TF_VAR_cloudflare_api_token="YOUR_CLOUDFLARE_API_TOKEN"
terraform apply -target='cloudflare_origin_ca_certificate.pitanga_cloud[0]' -auto-approve
```

If it still fails, the token may need to be regenerated with all permissions from the start.


