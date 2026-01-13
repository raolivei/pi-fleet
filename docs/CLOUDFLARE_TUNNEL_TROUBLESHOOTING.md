<!-- MIGRATED TO RUNBOOK -->
> **📚 This document has been migrated to the Eldertree Runbook**
>
> For the latest version, see: [CF-001](https://docs.eldertree.xyz/runbook/issues/cloudflare/CF-001)
>
> The runbook provides searchable troubleshooting guides with improved formatting.

---


# Cloudflare Tunnel Troubleshooting Guide

This document covers common issues with the Cloudflare Tunnel deployment and how to resolve them.

## Architecture Overview

The Cloudflare Tunnel is deployed as a Kubernetes Deployment that:

- Connects to Cloudflare using a token stored in Vault
- Routes traffic from `swimto.eldertree.xyz` to the Traefik ingress controller
- Uses ExternalSecret to automatically sync the token from Vault to Kubernetes

## Common Issues

### 1. "Unauthorized: Invalid tunnel secret" Error

**Symptoms:**

- Tunnel pod logs show: `ERR Register tunnel error from server side error="Unauthorized: Invalid tunnel secret"`
- Site returns 530 errors
- Tunnel status shows "DOWN" in Cloudflare dashboard

**Cause:**
The tunnel token in Vault doesn't match the token configured in Cloudflare.

**Solution:**

1. **Get the correct token from Cloudflare Dashboard:**

   ```bash
   # Option 1: Use the helper script
   cd pi-fleet/terraform
   ./scripts/get-tunnel-token.sh eldertree

   # Option 2: Get from Cloudflare Dashboard
   # 1. Go to https://dash.cloudflare.com
   # 2. Zero Trust → Networks → Tunnels
   # 3. Click on "eldertree" tunnel
   # 4. Click "Configure" next to your connector
   # 5. Copy the token (starts with eyJ...)
   ```

2. **Update the token in Vault:**

   ```bash
   export KUBECONFIG=~/.kube/config-eldertree

   # Using root token (you'll need your Vault root token)
   kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN='YOUR_ROOT_TOKEN' vault kv put secret/pi-fleet/cloudflare-tunnel/token token='YOUR_TOKEN_HERE'"
   ```

3. **Force ExternalSecret to refresh:**

   ```bash
   # Delete the Kubernetes secret (ExternalSecret will recreate it)
   kubectl delete secret cloudflared-credentials -n cloudflare-tunnel

   # Wait a few seconds for ExternalSecret to sync
   sleep 10

   # Verify the token was updated
   kubectl get secret cloudflared-credentials -n cloudflare-tunnel -o jsonpath='{.data.token}' | base64 -d && echo
   ```

4. **Restart the tunnel pod:**

   ```bash
   kubectl delete pod -n cloudflare-tunnel -l app=cloudflared

   # Wait for pod to restart and check logs
   sleep 20
   kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=50
   ```

5. **Verify tunnel is connected:**

   ```bash
   # Check logs for "Registered tunnel connection"
   kubectl logs -n cloudflare-tunnel -l app=cloudflared | grep "Registered"

   # Test the site
   curl -I https://swimto.eldertree.xyz
   ```

### 2. Error 530: Origin is unreachable

**Symptoms:**

- Site returns 530 errors
- Tunnel is authenticated but can't reach backend
- Logs show tunnel is registered

**Cause:**
The tunnel can't reach the Traefik service at the configured ClusterIP.

**Solution:**

1. **Verify Traefik ClusterIP matches Terraform config:**

   ```bash
   export KUBECONFIG=~/.kube/config-eldertree

   # Get current Traefik ClusterIP
   TRAEFIK_IP=$(kubectl get svc traefik -n kube-system -o jsonpath='{.spec.clusterIP}')
   echo "Current Traefik IP: $TRAEFIK_IP"

   # Check Terraform config
   grep -A 5 "service.*http://" pi-fleet/terraform/cloudflare.tf
   ```

2. **If IPs don't match, update Terraform:**

   ```bash
   cd pi-fleet/terraform

   # Update cloudflare.tf with the correct ClusterIP
   # Replace 10.43.81.2 with the actual Traefik ClusterIP

   # Apply changes
   terraform apply
   ```

3. **Test connectivity from within cluster:**
   ```bash
   # Test if Traefik is reachable
   kubectl run -it --rm test-curl --image=curlimages/curl:latest --restart=Never -- \
     curl -s -H "Host: swimto.eldertree.xyz" http://10.43.81.2:80 | head -20
   ```

### 3. DNS Resolution Issues

**Symptoms:**

- Tunnel can't resolve Kubernetes service DNS names
- Errors like "lookup traefik.kube-system.svc.cluster.local: no such host"
- 530 errors even though tunnel is authenticated

**Cause:**
The cluster uses IP addresses instead of DNS names (gigabit network configuration). Kubernetes service DNS may not be available or reliable.

**Solution:**
The configuration is set up for IP-based networking:

1. **Terraform uses ClusterIP directly** - The ingress rules use `http://10.43.81.2:80` instead of DNS names
2. **Deployment includes DNS upstream** - The tunnel pod has `TUNNEL_DNS_UPSTREAM` configured:
   ```yaml
   env:
     - name: TUNNEL_DNS_UPSTREAM
       value: "10.43.0.10,8.8.8.8,1.1.1.1" # Cluster DNS first, then public DNS
   ```

**Important:** If the Traefik ClusterIP changes, you must update the Terraform configuration:

```bash
# Get current Traefik ClusterIP
TRAEFIK_IP=$(kubectl get svc traefik -n kube-system -o jsonpath='{.spec.clusterIP}')

# Update terraform/cloudflare.tf with the new IP
# Replace all instances of http://10.43.81.2:80 with http://$TRAEFIK_IP:80
```

### 4. Tunnel Not Registering

**Symptoms:**

- Pod is running but tunnel shows "DOWN" in Cloudflare dashboard
- No "Registered tunnel connection" in logs

**Solution:**

1. **Check pod logs:**

   ```bash
   kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=100
   ```

2. **Verify token is correct:**

   ```bash
   # Decode token to check tunnel ID
   TOKEN=$(kubectl get secret cloudflared-credentials -n cloudflare-tunnel -o jsonpath='{.data.token}' | base64 -d)
   echo "$TOKEN" | base64 -d | jq -r '.t'  # Extract tunnel ID

   # Compare with Terraform output
   cd pi-fleet/terraform
   terraform output cloudflare_tunnel_id
   ```

3. **Check ExternalSecret status:**
   ```bash
   kubectl get externalsecret cloudflared-credentials -n cloudflare-tunnel -o yaml
   kubectl describe externalsecret cloudflared-credentials -n cloudflare-tunnel
   ```

## Maintenance

### Updating the Tunnel Token

The tunnel token may need to be updated if:

- The token expires or is rotated
- The tunnel is recreated in Cloudflare
- You need to regenerate the token for security reasons

See the "Unauthorized: Invalid tunnel secret" section above for the update procedure.

### Finding the Traefik ClusterIP

If the Traefik ClusterIP changes (e.g., after cluster recreation), update the Terraform configuration:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Get current IP
TRAEFIK_IP=$(kubectl get svc traefik -n kube-system -o jsonpath='{.spec.clusterIP}')
echo "Update cloudflare.tf with: $TRAEFIK_IP"

# Update terraform/cloudflare.tf
# Replace all instances of http://10.43.81.2:80 with http://$TRAEFIK_IP:80

# Apply changes
cd pi-fleet/terraform
terraform apply
```

## Monitoring

### Check Tunnel Status

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Pod status
kubectl get pods -n cloudflare-tunnel

# Recent logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=50

# Check for registered connections
kubectl logs -n cloudflare-tunnel -l app=cloudflared | grep "Registered"
```

### Test Site Accessibility

```bash
# Test HTTP response
curl -I https://swimto.eldertree.xyz

# Test full page load
curl -s https://swimto.eldertree.xyz | head -20
```

## Related Files

- **Terraform Config:** `pi-fleet/terraform/cloudflare.tf`
- **Kubernetes Deployment:** `pi-fleet/clusters/eldertree/dns-services/cloudflare-tunnel/deployment.yaml`
- **ExternalSecret:** Managed by External Secrets Operator, syncs from Vault
- **Vault Secret Path:** `secret/pi-fleet/cloudflare-tunnel/token`
- **Helper Script:** `pi-fleet/terraform/scripts/get-tunnel-token.sh`

## Additional Resources

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [External Secrets Operator](https://external-secrets.io/)
- [Vault Documentation](../VAULT.md)
