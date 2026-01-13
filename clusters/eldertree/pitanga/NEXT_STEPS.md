# Next Steps After Image Publication

## Current Status

✅ **Image Published**: `ghcr.io/raolivei/pitanga-website:latest` is now available  
✅ **Certificate Created**: Cloudflare Origin Certificate stored in Vault  
✅ **Build Fixed**: All build issues resolved

## Next Steps

### 1. Fix ExternalSecret Sync (Certificate)

The ExternalSecret is showing `SecretSyncedError` due to Vault connection issues.

**Check Vault connection:**

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get clustersecretstore vault
```

**If Vault is accessible, manually sync:**

```bash
# Check ExternalSecret details
kubectl describe externalsecret pitanga-cloudflare-origin-cert -n pitanga

# If needed, delete and recreate (Flux will recreate from Git)
kubectl delete externalsecret pitanga-cloudflare-origin-cert -n pitanga
```

**Verify certificate in Vault:**

```bash
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- vault kv get secret/pitanga/cloudflare-origin-cert
```

### 2. Deploy/Update Applications

The deployments should be managed by Flux CD. Check if they exist:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check if namespace exists
kubectl get namespace pitanga

# Check if deployments exist
kubectl get deployments -n pitanga

# Check Flux sync status
kubectl get kustomizations -n flux-system | grep pitanga
```

**If deployments don't exist, apply them:**

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/pitanga
kubectl apply -k .
```

**Or let Flux sync automatically** (if kustomization is configured):

```bash
# Force Flux to reconcile
kubectl annotate kustomization pitanga -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

### 3. Update Image References

The deployment uses ImagePolicy for automatic updates. Check if it's working:

```bash
# Check ImagePolicy
kubectl get imagepolicy pitanga-website-policy -n pitanga

# Check ImageRepository
kubectl get imagerepository pitanga-website -n pitanga

# Manually trigger update if needed
kubectl annotate imagerepository pitanga-website -n pitanga reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

**Or manually update the image:**

```bash
kubectl set image deployment/pitanga-website website=ghcr.io/raolivei/pitanga-website:latest -n pitanga
```

### 4. Verify HTTPS/TLS

Once the certificate is synced:

```bash
# Check TLS secret exists
kubectl get secret pitanga-cloudflare-origin-tls -n pitanga

# Check ingress TLS configuration
kubectl get ingress -n pitanga -o yaml | grep -A 5 tls

# Test HTTPS
curl -vI https://pitanga.cloud
curl -vI https://northwaysignal.pitanga.cloud
```

### 5. Verify DNS and Cloudflare

**Check DNS records:**

```bash
# Check DNS resolution
dig pitanga.cloud
dig northwaysignal.pitanga.cloud

# Check Cloudflare proxy status (should be proxied - orange cloud)
# Visit: https://dash.cloudflare.com → pitanga.cloud → DNS
```

**Verify Cloudflare SSL/TLS mode:**

- Go to: SSL/TLS → Overview
- Mode should be: **Full (strict)** ✅
- This ensures Cloudflare validates the Origin Certificate

### 6. Monitor Deployment

```bash
# Watch deployment rollout
kubectl rollout status deployment/pitanga-website -n pitanga

# Check pods
kubectl get pods -n pitanga -w

# Check logs
kubectl logs -f deployment/pitanga-website -n pitanga

# Check ingress
kubectl get ingress -n pitanga
```

## Quick Verification Checklist

- [ ] ExternalSecret synced (certificate in Kubernetes)
- [ ] TLS secret exists: `pitanga-cloudflare-origin-tls`
- [ ] Deployments running: `pitanga-website` and `northwaysignal-website`
- [ ] Ingress configured with TLS
- [ ] DNS records point to Cloudflare (proxied)
- [ ] Cloudflare SSL/TLS mode: Full (strict)
- [ ] HTTPS works: `https://pitanga.cloud`
- [ ] HTTPS works: `https://northwaysignal.pitanga.cloud`
- [ ] Images are up to date (using latest from GHCR)

## Troubleshooting

### Certificate Not Syncing

1. **Check Vault connection:**

   ```bash
   kubectl describe clustersecretstore vault
   ```

2. **Check ExternalSecret events:**

   ```bash
   kubectl describe externalsecret pitanga-cloudflare-origin-cert -n pitanga
   ```

3. **Manually sync if needed:**

   ```bash
   # Get certificate from Vault
   VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
   CERT=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=certificate secret/pitanga/cloudflare-origin-cert)
   KEY=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=private-key secret/pitanga/cloudflare-origin-cert)

   # Create secret manually
   kubectl create secret tls pitanga-cloudflare-origin-tls \
     --cert=<(echo "$CERT") \
     --key=<(echo "$KEY") \
     -n pitanga
   ```

### Deployments Not Updating

1. **Check ImagePolicy:**

   ```bash
   kubectl get imagepolicy -n pitanga
   kubectl describe imagepolicy pitanga-website-policy -n pitanga
   ```

2. **Force image update:**

   ```bash
   kubectl set image deployment/pitanga-website website=ghcr.io/raolivei/pitanga-website:latest -n pitanga
   ```

3. **Check image pull secrets:**
   ```bash
   kubectl get secret ghcr-secret -n pitanga
   ```

## Summary

The main tasks are:

1. **Fix certificate sync** (ExternalSecret → Kubernetes secret)
2. **Deploy/update applications** (if not already deployed)
3. **Verify HTTPS** (test both domains)
4. **Monitor** (ensure everything is running)

Once these are complete, both `pitanga.cloud` and `northwaysignal.pitanga.cloud` should be live with HTTPS!
