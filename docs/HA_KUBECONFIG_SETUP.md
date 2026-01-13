# HA Kubeconfig Setup

## Problem

When you have a 3-node HA control plane, the kubeconfig is typically hardcoded to a single node's IP address (e.g., `https://192.168.2.101:6443`). If that node goes down, `kubectl` cannot connect to the cluster, even though the cluster is still operational with the other 2 nodes.

**Additional Issue**: The API servers on node-2 and node-3 may not be accessible from external networks (192.168.2.x). They might only be listening on internal IPs (10.0.0.x) or have firewall restrictions. This means even if you update the kubeconfig to point to node-2 or node-3, you still can't connect from your Mac.

## Current Workaround

Use the `update-kubeconfig-ha.sh` script to automatically retrieve the kubeconfig from any available control plane node:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
./scripts/update-kubeconfig-ha.sh
```

This script:

1. Tries to connect to each control plane node in order (node-1, node-2, node-3)
2. Retrieves the kubeconfig from the first available node
3. Updates the kubeconfig to use that node's IP

**Limitation**: If the node you're connected to goes down, you need to run the script again to switch to another node.

## Proper HA Solution: Load Balancer ⚠️ REQUIRED

**IMPORTANT**: For true HA without manual intervention, you **MUST** set up a load balancer in front of all API servers. This is required because:

- Node-2 and node-3 API servers are not accessible from external networks
- Without a load balancer, you can only connect via node-1
- When node-1 goes down, you lose all external access to the cluster

A load balancer provides:

- ✅ Automatic failover if one node goes down
- ✅ Single endpoint for kubectl (no need to switch configs)
- ✅ External access to all API servers
- ✅ Better performance (load distribution)

### Option 1: kube-vip (Recommended for k3s)

kube-vip provides a virtual IP that floats between control plane nodes.

**Installation**:

```bash
# Install kube-vip
kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip/main/manifests/static.yaml

# Configure VIP (e.g., 192.168.2.100)
# Update kubeconfig to use VIP instead of node IP
```

**Benefits**:

- Works well with k3s
- Lightweight
- Automatic failover

### Option 2: MetalLB

MetalLB provides load balancing for bare-metal Kubernetes clusters.

**Installation**:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml

# Configure IP pool (e.g., 192.168.2.100-192.168.2.100)
# Create LoadBalancer service for kubernetes API
```

**Benefits**:

- Industry standard
- More features (BGP, L2)
- Good for larger clusters

### Option 3: External Load Balancer

If you have an external load balancer (hardware or software), you can configure it to load balance across all control plane nodes:

```
Backend servers:
- 192.168.2.101:6443 (node-1)
- 192.168.2.102:6443 (node-2)
- 192.168.2.103:6443 (node-3)

Frontend VIP: 192.168.2.100:6443
```

Then update kubeconfig to use the VIP:

```bash
kubectl config set-cluster eldertree --server=https://192.168.2.100:6443
```

## Quick Fix: Update Kubeconfig Manually

If a node goes down and you need immediate access:

```bash
# Get kubeconfig from another node
ssh roliveira@192.168.2.102 "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config-eldertree

# Update server IP
sed -i '' 's|server: https://0.0.0.0:6443|server: https://192.168.2.102:6443|g' ~/.kube/config-eldertree

# Test connection
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
```

## Verification

After setting up HA kubeconfig, test failover:

1. **Check current endpoint**:

   ```bash
   kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
   ```

2. **Test with node down**: Shut down the node your kubeconfig points to and verify you can still connect (if using load balancer) or run the update script to switch to another node.

## References

- [kube-vip Documentation](https://kube-vip.io/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [k3s High Availability](https://docs.k3s.io/installation/ha)
