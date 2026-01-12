# Manual Commands to Run

Since the cluster was unreachable, run these commands **when the cluster is back online**:

## Quick Command (All-in-one)

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Create GHCR secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password='YOUR_GITHUB_TOKEN' \
  -n pitanga

# Restart deployments
kubectl rollout restart deployment/pitanga-website -n pitanga
kubectl rollout restart deployment/northwaysignal-website -n pitanga

# Watch pods
kubectl get pods -n pitanga -w
```

## Or Use the Script

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/pitanga
./create-ghcr-secret-now.sh
```

## Verify Everything Works

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check secret exists
kubectl get secret ghcr-secret -n pitanga

# Check pods are running
kubectl get pods -n pitanga

# Check deployments
kubectl get deployments -n pitanga

# Check services
kubectl get services -n pitanga

# Check ingress
kubectl get ingress -n pitanga
```

## Expected Result

After running the commands:
- ✅ `ghcr-secret` exists
- ✅ Pods status: `Running` (not `ImagePullBackOff`)
- ✅ Deployments: `READY 1/1`
- ✅ Services accessible

## If Cluster Still Unreachable

Check:
1. **Cluster nodes are running**: SSH to nodes and check `systemctl status k3s`
2. **Network connectivity**: `ping 192.168.2.101`
3. **Kubeconfig**: Verify `~/.kube/config-eldertree` points to correct cluster


