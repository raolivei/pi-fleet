# Deployment Checklist - Pitanga Namespace

## Pre-Deployment Checklist

### ✅ Completed
- [x] Created northwaysignal-website deployment manifest
- [x] Created northwaysignal-website service manifest
- [x] Created northwaysignal-website ingress manifest
- [x] Updated kustomization.yaml to include all resources
- [x] Verified health endpoint path (`/api/health`)
- [x] Created GHCR secret setup scripts
- [x] Cloudflare Origin Certificate stored in Vault (via Terraform)
- [x] Terraform resources for certificate management created

### ⏳ Waiting for Cluster Access
- [ ] Create GHCR secret in Kubernetes
- [ ] Verify ExternalSecret syncs certificate from Vault
- [ ] Apply all Kubernetes manifests
- [ ] Verify pods are running
- [ ] Verify services are accessible
- [ ] Verify ingress is configured correctly
- [ ] Test both websites are accessible

## Deployment Steps (When Cluster is Accessible)

### Step 1: Create GHCR Secret

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/pitanga
export KUBECONFIG=~/.kube/config-eldertree

# Option A: Use the direct script (recommended)
./create-ghcr-secret-direct.sh

# Option B: Manual command
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password="YOUR_GITHUB_TOKEN" \
  -n pitanga
```

### Step 2: Verify ExternalSecret Syncs

```bash
# Check if certificate secret exists
kubectl get secret pitanga-cloudflare-origin-tls -n pitanga

# If missing, check ExternalSecret status
kubectl get externalsecret -n pitanga
kubectl describe externalsecret pitanga-cloudflare-origin-cert -n pitanga

# If Vault connection is failing, check ClusterSecretStore
kubectl get clustersecretstore vault
kubectl describe clustersecretstore vault
```

### Step 3: Apply Kubernetes Manifests

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/pitanga
export KUBECONFIG=~/.kube/config-eldertree

# Apply all resources via kustomize
kubectl apply -k .

# Or apply individually
kubectl apply -f namespace.yaml
kubectl apply -f ghcr-secret-external.yaml
kubectl apply -f cloudflare-origin-cert-external.yaml
kubectl apply -f website-deployment.yaml
kubectl apply -f website-service.yaml
kubectl apply -f website-ingress.yaml
kubectl apply -f northwaysignal-deployment.yaml
kubectl apply -f northwaysignal-service.yaml
kubectl apply -f northwaysignal-ingress.yaml
kubectl apply -f image-automation.yaml
```

### Step 4: Verify Deployments

```bash
# Check deployments
kubectl get deployments -n pitanga

# Check pods
kubectl get pods -n pitanga -o wide

# Check services
kubectl get services -n pitanga

# Check ingress
kubectl get ingress -n pitanga

# View pod logs if needed
kubectl logs -n pitanga deployment/pitanga-website
kubectl logs -n pitanga deployment/northwaysignal-website
```

### Step 5: Test Health Endpoints

```bash
# Test pitanga-website health
kubectl port-forward -n pitanga deployment/pitanga-website 8080:80 &
curl http://localhost:8080/health

# Test northwaysignal-website health
kubectl port-forward -n pitanga deployment/northwaysignal-website 8081:5000 &
curl http://localhost:8081/api/health
```

### Step 6: Verify DNS and Ingress

```bash
# Check ingress configuration
kubectl describe ingress -n pitanga

# Check DNS records (should be managed by external-dns)
# Verify in Cloudflare dashboard:
# - pitanga.cloud → A record pointing to cluster IP
# - www.pitanga.cloud → CNAME to pitanga.cloud
# - northwaysignal.pitanga.cloud → A record pointing to cluster IP

# Test public access (once DNS propagates)
curl -I https://pitanga.cloud
curl -I https://www.pitanga.cloud
curl -I https://northwaysignal.pitanga.cloud
```

## Troubleshooting

### Issue: ImagePullBackOff

**Cause**: Missing or invalid GHCR secret

**Fix**:
```bash
# Verify secret exists
kubectl get secret ghcr-secret -n pitanga

# Recreate if needed
./create-ghcr-secret-direct.sh
```

### Issue: Certificate Secret Missing

**Cause**: ExternalSecret not syncing from Vault

**Fix**:
```bash
# Check Vault connection
kubectl get clustersecretstore vault
kubectl describe clustersecretstore vault

# If Vault is unreachable, manually create secret:
# (Get cert from Terraform output or Vault)
kubectl create secret tls pitanga-cloudflare-origin-tls \
  --cert=<cert.pem> \
  --key=<key.pem> \
  -n pitanga
```

### Issue: Pods Not Starting

**Check**:
```bash
# Describe pod for events
kubectl describe pod -n pitanga <pod-name>

# Check logs
kubectl logs -n pitanga <pod-name>

# Check resource constraints
kubectl top pods -n pitanga
```

### Issue: Ingress Not Routing

**Check**:
```bash
# Verify ingress is configured
kubectl get ingress -n pitanga
kubectl describe ingress -n pitanga

# Check Traefik routes
kubectl get ingressroute -n pitanga  # if using Traefik CRDs

# Verify DNS
dig pitanga.cloud
dig northwaysignal.pitanga.cloud
```

## Post-Deployment Verification

- [ ] Both websites accessible at their respective domains
- [ ] HTTPS working (Cloudflare Origin Certificate)
- [ ] Health endpoints responding
- [ ] No pod restarts or errors
- [ ] DNS records correct in Cloudflare
- [ ] External-DNS creating/updating records
- [ ] Image automation working (Flux)

## Rollback Plan

If deployment fails:

```bash
# Delete problematic resources
kubectl delete -f northwaysignal-deployment.yaml
kubectl delete -f northwaysignal-service.yaml
kubectl delete -f northwaysignal-ingress.yaml

# Or delete everything and start fresh
kubectl delete -k .
```

## Next Steps

1. Monitor deployments for 24 hours
2. Set up monitoring/alerting (if not already done)
3. Document any issues encountered
4. Update CHANGELOG.md with deployment notes

