# Cloudflare Tunnel Setup for pitanga.cloud

## Issue: Cloudflare 525 Error

**Error**: `SSL handshake failed` (Error code 525)

**Root Cause**: `pitanga.cloud` and `northwaysignal.pitanga.cloud` are using Cloudflare proxy (orange cloud), but the Cloudflare Tunnel doesn't have ingress rules configured for these domains. Cloudflare can't reach the origin server.

## Solution: Add Tunnel Ingress Rules

The Cloudflare Tunnel configuration has been updated in Terraform to include routes for:
- `pitanga.cloud`
- `www.pitanga.cloud`
- `northwaysignal.pitanga.cloud`

## Apply the Changes

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform

# Set required environment variables
export TF_VAR_cloudflare_api_token="your-api-token"
export TF_VAR_cloudflare_account_id="your-account-id"
export TF_VAR_pitanga_cloud_zone_id="your-zone-id"

# Apply the tunnel configuration changes
terraform apply -target=cloudflare_zero_trust_tunnel_cloudflared_config.eldertree
```

## Verify Tunnel Configuration

After applying, verify the tunnel has the new routes:

1. **Check Cloudflare Dashboard**:
   - Go to Zero Trust → Networks → Tunnels
   - Click on "eldertree" tunnel
   - Verify routes include:
     - `pitanga.cloud`
     - `www.pitanga.cloud`
     - `northwaysignal.pitanga.cloud`

2. **Check Tunnel Pod Logs**:
   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   kubectl logs -n dns-services -l app=cloudflared --tail=50
   ```
   
   Look for:
   - ✅ "Registered tunnel connection" - Tunnel is connected
   - ✅ No errors about routing

3. **Test the Sites**:
   ```bash
   curl -I https://pitanga.cloud
   curl -I https://northwaysignal.pitanga.cloud
   ```

## How It Works

1. **Cloudflare Tunnel**: Outbound connection from cluster to Cloudflare
2. **Tunnel Routes**: Routes `pitanga.cloud` → Traefik ClusterIP (`10.43.23.214:80`)
3. **Traefik**: Routes to Kubernetes ingress based on Host header
4. **Ingress**: Routes to appropriate service (pitanga-website or northwaysignal-website)
5. **TLS**: Origin Certificate is used for HTTPS between Cloudflare and Traefik

## Current Configuration

- **Tunnel ClusterIP**: `10.43.23.214` (Traefik service)
- **Tunnel Namespace**: `dns-services` (or `cloudflare-tunnel`)
- **Certificate Secret**: `pitanga-cloudflare-origin-tls` in `pitanga` namespace

## Troubleshooting

### If 525 error persists after applying:

1. **Check tunnel pod is running**:
   ```bash
   kubectl get pods -n dns-services -l app=cloudflared
   ```

2. **Check tunnel logs for errors**:
   ```bash
   kubectl logs -n dns-services -l app=cloudflared --tail=100
   ```

3. **Verify DNS records**:
   - Cloudflare Dashboard → DNS → Records
   - `pitanga.cloud` should be proxied (orange cloud)
   - `northwaysignal.pitanga.cloud` should be proxied (orange cloud)

4. **Check Cloudflare SSL/TLS mode**:
   - Cloudflare Dashboard → SSL/TLS → Overview
   - Should be set to **Full (strict)** to validate origin certificate

5. **Verify certificate secret exists**:
   ```bash
   kubectl get secret pitanga-cloudflare-origin-tls -n pitanga
   ```

## Related Files

- Terraform configuration: `pi-fleet/terraform/cloudflare.tf`
- Tunnel deployment: `pi-fleet/clusters/eldertree/dns-services/cloudflare-tunnel/`
- Certificate setup: `pi-fleet/clusters/eldertree/pitanga/CLOUDFLARE_ORIGIN_CERT_SETUP.md`

