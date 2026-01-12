# Manual Cloudflare Tunnel Update for pitanga.cloud

## Issue
The Cloudflare Tunnel configuration needs to be updated to include routes for:
- `pitanga.cloud`
- `www.pitanga.cloud`
- `northwaysignal.pitanga.cloud`

## Current Status
- ✅ Terraform configuration updated (`cloudflare.tf`)
- ❌ Terraform apply blocked by API token permissions
- ❌ Direct API update blocked by authentication

## Solution: Update via Cloudflare Dashboard

Since the API token doesn't have tunnel permissions, update the tunnel configuration manually via the Cloudflare Dashboard:

### Steps

1. **Go to Cloudflare Dashboard**:
   - https://dash.cloudflare.com
   - Zero Trust → Networks → Tunnels
   - Click on `eldertree` tunnel

2. **Edit Tunnel Configuration**:
   - Click **Configure** next to the connector
   - Or go to **Configuration** tab

3. **Add Ingress Rules**:
   
   Add these rules (in order, before the catch-all):
   
   ```
   pitanga.cloud → http://10.43.23.214:80
   www.pitanga.cloud → http://10.43.23.214:80
   northwaysignal.pitanga.cloud → http://10.43.23.214:80
   ```

   **Full configuration should be:**
   ```
   1. swimto.eldertree.xyz/ → http://10.43.23.214:80
   2. swimto.eldertree.xyz/api/* → http://10.43.23.214:80
   3. pitanga.cloud/ → http://10.43.23.214:80
   4. www.pitanga.cloud/ → http://10.43.23.214:80
   5. northwaysignal.pitanga.cloud/ → http://10.43.23.214:80
   6. Catch-all → http_status:404
   ```

4. **Save Configuration**

5. **Wait 30-60 seconds** for the tunnel to reconnect

6. **Test**:
   ```bash
   curl -I https://pitanga.cloud
   curl -I https://northwaysignal.pitanga.cloud
   ```

## Alternative: Update API Token Permissions

If you want to use Terraform/API in the future:

1. Go to Cloudflare Dashboard → My Profile → API Tokens
2. Edit the token (or create new one with tunnel permissions)
3. Add permissions:
   - **Zero Trust:Edit** (for tunnels)
   - **Account:Cloudflare Tunnel:Edit**
4. Update token in Vault:
   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token="NEW_TOKEN_WITH_TUNNEL_PERMISSIONS"
   ```
5. Then run: `cd ~/WORKSPACE/raolivei/pi-fleet/terraform && ./run-terraform.sh apply -target=cloudflare_zero_trust_tunnel_cloudflared_config.eldertree`

## Current Traefik ClusterIP

The Traefik ClusterIP is: `10.43.23.214`

To verify:
```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get svc traefik -n kube-system -o jsonpath='{.spec.clusterIP}'
```

If it changes, update the tunnel configuration with the new IP.

