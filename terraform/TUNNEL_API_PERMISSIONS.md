# Cloudflare Tunnel API Token Permissions

## Issue

When trying to create Cloudflare Tunnels via Terraform, you may encounter:

```
Error: failed to create Argo Tunnel: Authentication error (10000)
```

## Cause

The Cloudflare API token doesn't have permission to create Zero Trust Tunnels. Standard DNS tokens only have:

- Zone:Read
- DNS:Edit

But Cloudflare Tunnels require **Zero Trust API permissions**.

## Solution: Create New API Token with Tunnel Permissions

### Step 1: Create New API Token

1. Go to Cloudflare Dashboard → **My Profile** → **API Tokens**
2. Click **"Create Token"**
3. Click **"Create Custom Token"** (or use "Edit zone DNS" template and modify)

4. **Configure Permissions:**

   **Account Permissions:**

   - **Cloudflare Tunnel** → **Edit** ✅ (Required for tunnel creation)
   - **Account** → **Read** ✅ (May be required)

   **Zone Permissions:**

   - **Zone** → **Zone** → **Read** ✅
   - **Zone** → **DNS** → **Edit** ✅

5. **Account Resources:**

   - Select **"Include"** → **All accounts** (or specific account)

6. **Zone Resources:**

   - Select **"Include"** → **Specific zone** → `eldertree.xyz`

7. **Client IP Address Filtering:** (Optional)

   - Leave empty unless you want to restrict by IP

8. **TTL:** (Optional)

   - Leave empty for no expiration

9. Click **"Continue to summary"** → **"Create Token"**

10. **Copy the token immediately** (you won't be able to see it again!)

### Step 2: Update Token in Vault

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# Get Vault pod
export KUBECONFIG=~/.kube/config-eldertree
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Store new token for Terraform
kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token="YOUR_NEW_TOKEN_HERE"

# Also update for External-DNS (same token works)
kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/external-dns/cloudflare-api-token api-token="YOUR_NEW_TOKEN_HERE"
```

### Step 3: Retry Terraform Apply

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/terraform
./run-terraform.sh apply
```

## Required Permissions Summary

For Cloudflare Tunnels via Terraform, your API token needs:

✅ **Account Permissions:**

- Cloudflare Tunnel → Edit
- Account → Read (recommended)

✅ **Zone Permissions:**

- Zone → Zone → Read
- Zone → DNS → Edit

## Alternative: Use Cloudflare API Key (Not Recommended)

If you prefer using API Key + Email instead of API Token:

- Not recommended for security reasons
- API Tokens are more secure and scoped
- See Terraform Cloudflare provider docs for details

## Verification

After updating the token, verify it works:

```bash
# Test API token has tunnel permissions
export KUBECONFIG=~/.kube/config-eldertree
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
API_TOKEN=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=api-token secret/pi-fleet/terraform/cloudflare-api-token)

# List tunnels (should work if token has permissions)
curl -X GET "https://api.cloudflare.com/client/v4/accounts/YOUR_ACCOUNT_ID/cfd_tunnel" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json"
```
