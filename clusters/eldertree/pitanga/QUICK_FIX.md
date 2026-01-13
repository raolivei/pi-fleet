# Quick Fix Guide - GHCR Secret & Deployments

When the Kubernetes cluster is accessible, use these commands to fix the deployments.

## Option 1: Direct Script (Recommended)

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/pitanga
export KUBECONFIG=~/.kube/config-eldertree
./create-ghcr-secret-direct.sh
```

## Option 2: Manual kubectl Commands

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Create GHCR secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=raolivei \
  --docker-password="YOUR_GITHUB_TOKEN" \
  -n pitanga

# Restart deployments
kubectl rollout restart deployment/pitanga-website -n pitanga
kubectl rollout restart deployment/northwaysignal-website -n pitanga

# Check status
kubectl get pods -n pitanga
```

## Option 3: Using Existing Setup Script

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/pitanga
export KUBECONFIG=~/.kube/config-eldertree
./setup-ghcr-secret.sh "YOUR_GITHUB_TOKEN"
```

## Verify Everything Works

```bash
# Check pods are running
kubectl get pods -n pitanga

# Check deployments
kubectl get deployments -n pitanga

# Check services
kubectl get services -n pitanga

# Check ingress
kubectl get ingress -n pitanga

# View pod logs if needed
kubectl logs -n pitanga deployment/pitanga-website
kubectl logs -n pitanga deployment/northwaysignal-website
```

## Troubleshooting

### If secret already exists:
```bash
kubectl delete secret ghcr-secret -n pitanga
# Then run Option 1 or 2 again
```

### If pods are still in ImagePullBackOff:
```bash
# Check the secret exists
kubectl get secret ghcr-secret -n pitanga

# Check pod events
kubectl describe pod -n pitanga <pod-name>

# Force delete and recreate pods
kubectl delete pods -n pitanga -l app=pitanga-website
kubectl delete pods -n pitanga -l app=northwaysignal-website
```

