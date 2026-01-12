# Verify Token Permissions

## Current Status

The token is active, but Terraform still reports permission error (1016) when creating Origin Certificates.

## What to Check

1. **In Cloudflare Dashboard:**
   - Go to: https://dash.cloudflare.com/profile/api-tokens
   - Find: `eldertree-terraform-full`
   - Click `...` → **View** (to see current permissions)
   - Verify **Zone** → **SSL and Certificates** → **Edit** is listed

2. **Permission Scope:**
   - Make sure the permission is set for the correct zone (`pitanga.cloud`)
   - Or set it for "All zones" if you want it to work for all domains

3. **Token Value:**
   - When you edit permissions, Cloudflare sometimes keeps the same token value
   - But if it generated a new token, you'll need to copy the new value
   - Check if there's a "Token value changed" message

## If Token Value Changed

If Cloudflare generated a new token value when you edited permissions:

1. **Copy the new token value** from Cloudflare Dashboard
2. **Update in Vault:**
   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token='NEW_TOKEN_VALUE_HERE'
   ```

3. **Re-run Terraform with new token:**
   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet/terraform
   export TF_VAR_pitanga_cloud_zone_id="4d674555d7344d4b5d46681fd17b49bd"
   export TF_VAR_cloudflare_api_token="NEW_TOKEN_VALUE_HERE"
   terraform apply -target='cloudflare_origin_ca_certificate.pitanga_cloud[0]' -auto-approve
   ```

## Alternative: Use Account-Level Permission

Sometimes Zone-level permissions don't work for Origin Certificates. Try:

1. **Edit Token:**
   - Add **Account** → **SSL and Certificates** → **Edit** (in addition to Zone-level)
   - Or use Account-level instead of Zone-level

2. **Account Resources:**
   - Set to "All accounts" or your specific account

## Manual Certificate Creation (Fallback)

If token permissions continue to be an issue, you can create the certificate manually:

1. Use the CSR from `/tmp/pitanga.csr`
2. Create certificate in Cloudflare Dashboard
3. Store in Vault using the script

This is acceptable since Origin Certificates are long-lived (15 years).


