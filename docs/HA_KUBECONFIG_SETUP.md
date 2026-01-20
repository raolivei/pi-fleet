# HA Kubeconfig Setup

## Current Setup ✅

The Eldertree cluster uses **kube-vip** for high availability:

- **Control Plane VIP**: `192.168.2.100` (API server endpoint)
- **LoadBalancer Services VIP Range**: `192.168.2.200-210`

kube-vip runs as a DaemonSet on all control plane nodes and provides:

- ✅ Automatic failover if one node goes down
- ✅ Single endpoint for kubectl (no need to switch configs)
- ✅ LoadBalancer service support (replaces MetalLB)
- ✅ ARP-based VIP that works with all routers

## Kubeconfig Configuration

Your kubeconfig should point to the VIP (`192.168.2.100`), not individual node IPs:

```yaml
clusters:
  - cluster:
      server: https://192.168.2.100:6443
    name: eldertree
```

To update an existing kubeconfig:

```bash
kubectl config set-cluster eldertree --server=https://192.168.2.100:6443
```

## kube-vip Architecture

kube-vip is deployed as a DaemonSet in `kube-system` namespace:

```bash
# Check kube-vip pods
kubectl get pods -n kube-system -l app=kube-vip

# View kube-vip configuration
kubectl get configmap -n kube-system kube-vip -o yaml
```

Configuration (`kube-vip-configmap.yaml`):

```yaml
data:
  vip: "192.168.2.100" # Control plane VIP
  interface: "wlan0" # Network interface
  enableControlPlane: "true"
  enableServices: "true" # LoadBalancer services
  servicesCIDR: "192.168.2.200/28" # Service VIP range
  arp: "true" # ARP mode (Layer 2)
  leaderElection: "true"
```

## Verification

1. **Check current endpoint**:

   ```bash
   kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
   # Should show: https://192.168.2.100:6443
   ```

2. **Test VIP reachability**:

   ```bash
   ping 192.168.2.100
   curl -k https://192.168.2.100:6443/healthz
   ```

3. **Test failover**: Shut down any control plane node and verify `kubectl` still works via the VIP.

## LoadBalancer Services

kube-vip also handles LoadBalancer services (replacing MetalLB):

| Service  | VIP             | Usage           |
| -------- | --------------- | --------------- |
| Traefik  | 192.168.2.200   | Ingress traffic |
| Pi-hole  | 192.168.2.201   | DNS server      |
| Reserved | 192.168.2.202-210 | Future services |

To request a specific LoadBalancer IP, set `spec.loadBalancerIP` in your Service:

```yaml
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.2.202
```

## Troubleshooting

### Cannot connect to cluster

```bash
# Check if VIP is responding
ping 192.168.2.100

# Check kube-vip leader
kubectl get lease -n kube-system | grep kube-vip

# Check kube-vip logs
kubectl logs -n kube-system -l app=kube-vip
```

### VIP not reachable

```bash
# Verify kube-vip is running on all nodes
kubectl get pods -n kube-system -l app=kube-vip -o wide

# Check if VIP is assigned to any node
ssh roliveira@192.168.2.101 "ip addr show wlan0 | grep 192.168.2.100"
```

## References

- [kube-vip Documentation](https://kube-vip.io/)
- [kube-vip Services](https://kube-vip.io/docs/usage/kubernetes-services/)
- [k3s High Availability](https://docs.k3s.io/installation/ha)
