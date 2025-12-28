# Network Architecture for Eldertree Cluster

## Overview

The eldertree cluster uses a simple, efficient network architecture optimized for a 2-node Raspberry Pi cluster on the same LAN.

## Network Layers

### 1. Physical Network Layer

**LAN Configuration:**
- **Network**: 192.168.2.0/24
- **Gateway**: 192.168.2.1
- **DNS**: 192.168.2.1, 8.8.8.8

**Node IP Assignment:**
- **node-0**: 192.168.2.80 (control plane)
- **node-1**: 192.168.2.81 (worker)
- **Future nodes**: 192.168.2.8N (where N is node number)

See [Node IP Assignment](./NODE_IP_ASSIGNMENT.md) for details.

### 2. Kubernetes Pod Network (Flannel)

**CNI Plugin**: Flannel (default with k3s)

**Purpose:**
- Pod-to-pod communication across nodes
- Service networking (ClusterIP)
- Network policies support

**Configuration:**
- Automatically configured by k3s
- Uses VXLAN backend by default
- Pod network: 10.42.0.0/16 (default)

**Why Flannel:**
- ✅ Lightweight and simple
- ✅ Works out of the box with k3s
- ✅ Low overhead for small clusters
- ✅ Sufficient for 2-node setup

**No changes needed** - Flannel is the right choice for this cluster.

### 3. Remote Access Network (WireGuard VPN)

**Purpose:**
- Secure remote access to cluster
- Mobile device access
- External connectivity

**Configuration:**
- Server running on control plane (node-0)
- Clients connect via WireGuard app
- VPN network: 10.8.0.0/24 (typical)

**Why WireGuard:**
- ✅ Modern, fast VPN protocol
- ✅ Low overhead
- ✅ Easy mobile device setup
- ✅ Secure encrypted tunnel

**Location**: `clusters/eldertree/dns-services/wireguard/`

### 4. Service Discovery (CoreDNS)

**Purpose:**
- Kubernetes service DNS resolution
- Custom DNS aliases (.local domains)
- External DNS forwarding

**Configuration:**
- Built into k3s
- Custom ConfigMap for service aliases
- Integrates with Pi-hole for ad-blocking

## Architecture Decision: No WireGuard Mesh

**Decision**: Do NOT create a WireGuard mesh between nodes.

**Rationale:**
- ✅ Nodes are on the same trusted LAN (192.168.2.x)
- ✅ Flannel already provides secure pod networking
- ✅ WireGuard mesh adds unnecessary overhead
- ✅ No performance benefit for 2-node cluster
- ✅ Simpler configuration and maintenance

**When to Reconsider:**
- Adding nodes on different networks (remote sites)
- Need for encrypted node-to-node traffic
- Regulatory/compliance requirements for encryption

## Network Traffic Flow

### Pod-to-Pod Communication
```
Pod on node-0 → Flannel VXLAN → Pod on node-1
```

### Service Access
```
Client → Traefik Ingress → Service → Pod
```

### Remote Access
```
Mobile Device → WireGuard VPN → Cluster Services
```

### External Access
```
Internet → Cloudflare Tunnel → Cluster Services (if configured)
```

## Security Considerations

### Current Setup
- **Pod networking**: Isolated via Flannel (10.42.0.0/16)
- **Node networking**: On private LAN (192.168.2.0/24)
- **Remote access**: Encrypted via WireGuard
- **Ingress**: Traefik with TLS (when configured)

### Recommendations
- ✅ Keep nodes on private LAN
- ✅ Use WireGuard for remote access
- ✅ Enable TLS for all ingress
- ✅ Use network policies for pod isolation (if needed)
- ❌ Skip WireGuard mesh (unnecessary overhead)

## Future Considerations

### Adding More Nodes

**Same LAN:**
- Continue using Flannel
- Assign IPs: 192.168.2.82, 192.168.2.83, etc.
- No overlay network changes needed

**Different Networks:**
- Consider WireGuard site-to-site VPN
- Or use k3s with WireGuard backend
- Or use cloud-managed VPN solution

### Scaling Considerations

**Current (2 nodes):**
- Flannel is perfect
- No performance concerns

**Future (5+ nodes):**
- Flannel still works well
- Consider Calico if you need advanced network policies
- Monitor network performance

## Troubleshooting

### Pod Networking Issues
```bash
# Check Flannel pods
kubectl get pods -n kube-system | grep flannel

# Check pod network
kubectl get pods -o wide

# Test pod-to-pod connectivity
kubectl run test-pod --image=busybox --rm -it -- ping <pod-ip>
```

### WireGuard Issues
See: `clusters/eldertree/dns-services/wireguard/TROUBLESHOOTING.md`

### DNS Issues
```bash
# Check CoreDNS
kubectl get pods -n kube-system | grep coredns

# Test DNS resolution
kubectl run test-dns --image=busybox --rm -it -- nslookup <service-name>
```

## Related Documentation

- [Node IP Assignment](./NODE_IP_ASSIGNMENT.md)
- [WireGuard Setup](../clusters/eldertree/dns-services/wireguard/README.md)
- [CoreDNS Capabilities](./COREDNS_CAPABILITIES.md)
- [Network Configuration](./IP_BASED_NETWORKING.md)


