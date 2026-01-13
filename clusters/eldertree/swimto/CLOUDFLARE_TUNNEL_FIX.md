# Fix Cloudflare Tunnel Error 1033 for swimto.eldertree.xyz

## Error
**Error 1033: Cloudflare Tunnel error** - Cloudflare cannot resolve the tunnel for `swimto.eldertree.xyz`

## Root Cause
The Cloudflare Tunnel connector (cloudflared pod) is either:
1. Not running
2. Not authenticated (invalid/expired token)
3. Not properly registered with Cloudflare

## Diagnostic Steps

### 1. Check if cloudflared pod is running

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check pod status
kubectl get pods -n cloudflare-tunnel

# Expected output:
# NAME                         READY   STATUS    RESTARTS   AGE
# cloudflared-xxxxxxxxxx-xxxxx 1/1     Running   0          5m
```

**If pod is not running or in Error/CrashLoopBackOff:**
- Check logs: `kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=50`
- Check events: `kubectl describe pod -n cloudflare-tunnel -l app=cloudflared`

### 2. Check tunnel logs for errors

```bash
# View recent logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=100

# Look for:
# ✅ "Registered tunnel connection" - Good, tunnel is connected
# ❌ "Unauthorized: Invalid tunnel secret" - Token is wrong
# ❌ "Failed to register tunnel" - Connection issue
# ❌ "error from server side" - Cloudflare API issue
```

### 3. Verify tunnel token is valid

```bash
# Check if secret exists
kubectl get secret cloudflared-credentials -n cloudflare-tunnel

# Decode token (should start with eyJ...)
kubectl get secret cloudflared-credentials -n cloudflare-tunnel -o jsonpath='{.data.token}' | base64 -d && echo

# Check ExternalSecret status
kubectl get externalsecret cloudflared-credentials -n cloudflare-tunnel
kubectl describe externalsecret cloudflared-credentials -n cloudflare-tunnel
```

### 4. Verify tunnel is registered in Cloudflare

```bash
# Get tunnel ID from Terraform
cd ~/WORKSPACE/raolivei/pi-fleet/terraform
terraform output cloudflare_tunnel_id

# Compare with token (token contains tunnel ID)
TOKEN=$(kubectl get secret cloudflared-credentials -n cloudflare-tunnel -o jsonpath='{.data.token}' | base64 -d)
echo "$TOKEN" | base64 -d 2>/dev/null | jq -r '.t' || echo "Token format may be different"
```

## Fix Procedures

### Fix 1: Update Tunnel Token (Most Common)

If the token is invalid or expired:

1. **Get new token from Cloudflare Dashboard:**
   - Go to https://dash.cloudflare.com
   - Zero Trust → Networks → Tunnels
   - Click on "eldertree" tunnel
   - Click "Configure" next to your connector
   - Copy the token (starts with `eyJ...`)

2. **Update token in Vault:**
   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   
   # Get Vault pod name
   VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
   
   # Update token (replace YOUR_TOKEN_HERE with actual token)
   kubectl exec -n vault $VAULT_POD -- sh -c "VAULT_TOKEN='YOUR_VAULT_ROOT_TOKEN' vault kv put secret/pi-fleet/cloudflare-tunnel/token token='YOUR_CLOUDFLARE_TUNNEL_TOKEN'"
   ```

3. **Force ExternalSecret to refresh:**
   ```bash
   # Delete the Kubernetes secret (ExternalSecret will recreate it)
   kubectl delete secret cloudflared-credentials -n cloudflare-tunnel
   
   # Wait for ExternalSecret to sync (usually 10-30 seconds)
   sleep 15
   
   # Verify token was updated
   kubectl get secret cloudflared-credentials -n cloudflare-tunnel -o jsonpath='{.data.token}' | base64 -d | head -c 50 && echo "..."
   ```

4. **Restart cloudflared pod:**
   ```bash
   kubectl delete pod -n cloudflare-tunnel -l app=cloudflared
   
   # Wait for pod to restart
   sleep 20
   
   # Check logs for successful registration
   kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=50 | grep -i "registered\|error"
   ```

### Fix 2: Verify Traefik ClusterIP

The tunnel routes to Traefik at `10.43.23.214:80`. Verify this is correct:

```bash
# Get current Traefik ClusterIP
TRAEFIK_IP=$(kubectl get svc traefik -n kube-system -o jsonpath='{.spec.clusterIP}')
echo "Current Traefik IP: $TRAEFIK_IP"

# Check Terraform config
grep -A 2 "service.*http://" ~/WORKSPACE/raolivei/pi-fleet/terraform/cloudflare.tf

# If IPs don't match, update Terraform:
cd ~/WORKSPACE/raolivei/pi-fleet/terraform
# Edit cloudflare.tf and replace 10.43.23.214 with $TRAEFIK_IP
terraform apply
```

### Fix 3: Recreate Tunnel (If Token is Completely Invalid)

If the tunnel token is completely invalid and can't be regenerated:

1. **Recreate tunnel in Terraform:**
   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet/terraform
   
   # Taint the tunnel resource to force recreation
   terraform taint cloudflare_zero_trust_tunnel_cloudflared.eldertree
   
   # Apply (this will create a new tunnel)
   terraform apply
   ```

2. **Get new token:**
   ```bash
   # Use helper script if available
   ./scripts/get-tunnel-token.sh eldertree
   
   # Or get from Cloudflare Dashboard (see Fix 1, step 1)
   ```

3. **Update token in Vault** (see Fix 1, step 2)

4. **Restart cloudflared pod** (see Fix 1, step 4)

## Verification

After applying fixes, verify the tunnel is working:

```bash
# 1. Check pod is running
kubectl get pods -n cloudflare-tunnel

# 2. Check logs show "Registered tunnel connection"
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=20 | grep -i "registered"

# 3. Test the site
curl -I https://swimto.eldertree.xyz

# Expected: HTTP/2 200 or 301/302 (not Error 1033)
```

## Quick Fix Script

If you have the tunnel token ready:

```bash
#!/bin/bash
set -e

export KUBECONFIG=~/.kube/config-eldertree

# Set these variables
VAULT_TOKEN="YOUR_VAULT_ROOT_TOKEN"
TUNNEL_TOKEN="YOUR_CLOUDFLARE_TUNNEL_TOKEN"

# Get Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Update token in Vault
echo "Updating tunnel token in Vault..."
kubectl exec -n vault $VAULT_POD -- sh -c "VAULT_TOKEN='$VAULT_TOKEN' vault kv put secret/pi-fleet/cloudflare-tunnel/token token='$TUNNEL_TOKEN'"

# Force ExternalSecret refresh
echo "Refreshing ExternalSecret..."
kubectl delete secret cloudflared-credentials -n cloudflare-tunnel || true
sleep 15

# Restart pod
echo "Restarting cloudflared pod..."
kubectl delete pod -n cloudflare-tunnel -l app=cloudflared || true
sleep 20

# Check status
echo "Checking tunnel status..."
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=20 | grep -i "registered\|error" || echo "Check logs manually"

echo "Done! Test: curl -I https://swimto.eldertree.xyz"
```

## Related Files

- **Terraform Config**: `pi-fleet/terraform/cloudflare.tf`
- **Kubernetes Deployment**: `pi-fleet/clusters/eldertree/dns-services/cloudflare-tunnel/deployment.yaml`
- **ExternalSecret**: `pi-fleet/clusters/eldertree/dns-services/cloudflare-tunnel/externalsecret.yaml`
- **Troubleshooting Guide**: `pi-fleet/docs/CLOUDFLARE_TUNNEL_TROUBLESHOOTING.md`



