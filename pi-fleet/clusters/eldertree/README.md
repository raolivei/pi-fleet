# Core Cluster

K3s control plane with embedded etcd.

## Status

✅ Control plane ready (eldertree)

## Deploy Apps

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl apply -f your-app.yaml
```

## Add Workers

```bash
cat ../../terraform/k3s-node-token
# On worker (fleet-worker-01, fleet-worker-02, etc.):
# curl -sfL https://get.k3s.io | K3S_URL=https://eldertree:6443 K3S_TOKEN=<token> sh -
```
