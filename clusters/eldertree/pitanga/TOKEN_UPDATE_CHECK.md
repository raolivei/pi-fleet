# Token Permission Update Check

## Issue

After updating token permissions, Terraform still shows:

```
Error: error creating origin certificate: User is not authorized to perform this action (1016)
```

## Possible Causes

1. **Token Value Changed**: When editing permissions, Cloudflare may have generated a new token value
2. **Permission Scope**: The permission might need to be set at Account level, not just Zone level
3. **Token Not Refreshed**: The token cache might need to be cleared

## Solutions

### Option 1: Check if Token Value Changed

When you edit a token in Cloudflare, check if a new token value was generated:

- If the token value changed, you'll need to update it in Vault
- If it stayed the same, the permissions should work

### Option 2: Verify Permission Scope

The "SSL and Certificates:Edit" permission might need to be:

- **Zone-level**: For specific zones (pitanga.cloud)
- **Account-level**: For all zones in the account

Try setting it at **Account level** if Zone level doesn't work.

### Option 3: Regenerate Token

If editing didn't work, create a new token:

1. **Create New Token:**

   - Name: `eldertree-terraform-full-v2` (or similar)
   - Permissions:
     - **Account** → **Cloudflare Tunnel** → **Edit**
     - **Zone** → **Zone** → **Read**
     - **Zone** → **DNS** → **Edit**
     - **Zone** → **SSL and Certificates** → **Edit** ✅
   - Zone Resources: Include `pitanga.cloud` (or All zones)
   - Account Resources: All accounts

2. **Update in Vault:**

   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token='NEW_TOKEN_VALUE'
   ```

3. **Re-run Terraform:**
   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet/terraform
   export TF_VAR_pitanga_cloud_zone_id="4d674555d7344d4b5d46681fd17b49bd"
   export TF_VAR_cloudflare_api_token="NEW_TOKEN_VALUE"
   terraform apply -target='cloudflare_origin_ca_certificate.pitanga_cloud[0]' -auto-approve
   ```

## Quick Test

To verify the token has the right permissions, you can test with curl:

```bash
# Test token (should show permissions)
curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_TOKEN" | jq '.result'
```

The response should show the token's permissions. Look for SSL/Certificate permissions in the output.
