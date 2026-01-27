# Network Architecture for Eldertree Cluster

## Overview

The eldertree cluster is a 3-node fully HA Raspberry Pi cluster using a dual-network architecture:
- **WiFi (192.168.2.x)**: Management and external access
- **Gigabit Ethernet (10.0.0.x)**: Primary network for k8s and node-to-node communication

## Network Layers

### 1. Physical Network Layer

**WiFi Network (wlan0) - Management:**

- **Network**: 192.168.2.0/24
- **Gateway**: 192.168.2.1
- **DNS**: 192.168.2.1, 8.8.8.8

**Gigabit Network (eth0) - Primary for k8s:**

- **Network**: 10.0.0.0/24 (isolated switch)
- **No gateway** - dedicated for cluster traffic only

**Node IP Assignment:**

| Node | WiFi (wlan0) | Gigabit (eth0) | Role |
|------|--------------|----------------|------|
| node-1 | 192.168.2.101 | 10.0.0.1 | control-plane, etcd |
| node-2 | 192.168.2.102 | 10.0.0.2 | control-plane, etcd |
| node-3 | 192.168.2.103 | 10.0.0.3 | control-plane, etcd |

**kube-vip VIP**: 192.168.2.100 (HA API server access)

### 1.1 k3s API Server Binding Configuration

**Critical Configuration** for kube-vip to work:

The k3s API server must bind to `0.0.0.0` (all interfaces) for the VIP to function properly.

**Why this matters:**

- kube-vip provides a floating VIP (192.168.2.100) on the WiFi network
- The API server `node-ip` and `advertise-address` are set to gigabit IPs (10.0.0.x)
- If `bind-address` is set to a specific IP (e.g., `10.0.0.1`), the API server only listens on that interface
- Traffic from the WiFi VIP cannot reach the API server because it's not listening on wlan0

**Correct `/etc/rancher/k3s/config.yaml`:**

```yaml
node-ip: 10.0.0.X           # Gigabit network for internal comms
bind-address: 0.0.0.0       # CRITICAL: Listen on ALL interfaces
advertise-address: 10.0.0.X # Advertise gigabit IP to other nodes
tls-san:
  - 192.168.2.100           # VIP
  - 192.168.2.10X           # WiFi IP
  - 10.0.0.X                # Gigabit IP
  - node-X.eldertree.local  # Hostname
```

**Ansible Playbook:** `ansible/playbooks/configure-k3s-gigabit.yml`

**Variable:** `k3s_bind_address` in `ansible/group_vars/all.yml`

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

- Server running on control plane (node-1)
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
Pod on node-1 → Flannel VXLAN → Pod on node-1
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
- Assign WiFi IPs: 192.168.2.104, 192.168.2.105, etc.
- Assign Gigabit IPs: 10.0.0.4, 10.0.0.5, etc.
- Configure k3s with `--node-ip` pointing to gigabit network

**Different Networks:**

- Consider WireGuard site-to-site VPN
- Or use k3s with WireGuard backend
- Or use cloud-managed VPN solution

### Scaling Considerations

**Current (3 nodes, HA):**

- Flannel is perfect
- etcd has quorum (3 nodes)
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








