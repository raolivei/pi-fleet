# Eldertree cluster (K3s)

3-node HA control plane on Raspberry Pi 5. GitOps path: `clusters/eldertree/`.

## See the project

| Resource | Link |
|----------|------|
| **Project hub** | [docs/ELDERTREE.md](../../docs/ELDERTREE.md) |
| **Live dashboards** | https://grafana.eldertree.local/d/eldertree-ops-home |
| **Docs site** | https://docs.eldertree.xyz/project |
| **Quick open** | `../../scripts/operations/eldertree-open.sh` |

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
```

## Deploy apps

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl apply -f your-app.yaml
```

Flux reconciles manifests under this directory on the cluster.

## Physical hardware

Portable tower CAD: [eldertree-chassis](https://github.com/raolivei/eldertree-chassis) · [HARDWARE_CHASSIS.md](../../docs/HARDWARE_CHASSIS.md)
