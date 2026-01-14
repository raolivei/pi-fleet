# Quick Start - Get Pitanga Deployments Running

## Current Status

✅ Image published: `ghcr.io/raolivei/pitanga-website:latest`  
✅ Deployments created  
❌ **BLOCKING**: GHCR secret missing (pods can't pull images)

## Quick Fix (2 minutes)

### Step 1: Get GitHub Token

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Name: `pitanga-ghcr-read`
4. Permissions: Check `read:packages`
5. Generate and copy the token

### Step 2: Create GHCR Secret

**Option A: Use the script (easiest)**

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/pitanga
./setup-ghcr-secret.sh YOUR_GITHUB_TOKEN
```

**Option B: Manual command**

```bash
export KUBECONFIG=~/.kube/config-eldertree

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password='YOUR_GITHUB_TOKEN' \
  -n pitanga

# Restart deployments
kubectl rollout restart deployment/pitanga-website -n pitanga
kubectl rollout restart deployment/northwaysignal-website -n pitanga
```

### Step 3: Verify

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Watch pods starting
kubectl get pods -n pitanga -w

# Check deployments
kubectl get deployments -n pitanga

# Check services
kubectl get services -n pitanga
```

## Expected Result

After ~30 seconds:

- ✅ Pods status: `Running`
- ✅ Deployments: `READY 1/1`
- ✅ Services accessible (HTTP)

## Next Steps (After pods are running)

1. **Fix certificate sync** (for HTTPS)
2. **Test domains**: `pitanga.cloud` and `northwaysignal.pitanga.cloud`
3. **Verify HTTPS** (once certificate is synced)

## Troubleshooting

**If pods still fail:**

```bash
# Check pod events
kubectl describe pod -n pitanga -l app=pitanga-website

# Check logs
kubectl logs -n pitanga -l app=pitanga-website

# Verify secret exists
kubectl get secret ghcr-secret -n pitanga
```

**If image pull still fails:**

- Verify token has `read:packages` permission
- Check image exists: https://github.com/users/raolivei/packages
- Verify image is not private (or token has access)
