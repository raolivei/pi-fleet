# WireGuard Helm Chart

A Helm chart for deploying WireGuard VPN server in Kubernetes with split-tunnel support for k3s cluster access.

## Features

- 🔐 **Split-tunnel VPN**: Only cluster traffic routed through VPN
- 🌐 **DNS forwarding**: Automatic resolution of `*.cluster.local` domains
- 📦 **Persistent storage**: Keeps keys and configs across restarts
- 🎛️ **Configurable**: Easy peer management via `values.yaml`
- 🔄 **Auto key generation**: Generates server keys on first deployment
- 📊 **Monitoring**: Optional Prometheus ServiceMonitor

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- LoadBalancer service support (MetalLB, cloud provider, etc.)
- Kernel modules: `wireguard`, `iptable_nat`

## Installation

### Quick Start

```bash
# Install with default values
helm install wireguard ./helm/wireguard \
  --namespace wireguard \
  --create-namespace

# Install with custom values
helm install wireguard ./helm/wireguard \
  --namespace wireguard \
  --create-namespace \
  --values my-values.yaml
```

### Using Kustomization

Add to your cluster's `kustomization.yaml`:

```yaml
helmCharts:
  - name: wireguard
    namespace: wireguard
    releaseName: wireguard
    repo: ""  # Local chart
    valuesFile: wireguard-values.yaml
```

## Configuration

### Basic Configuration

Create a `values.yaml` file:

```yaml
wireguard:
  serverAddress: "10.8.0.1/24"
  port: 51820
  
  # Add your clients here
  peers:
    - name: iphone
      publicKey: "YOUR_CLIENT_PUBLIC_KEY"
      allowedIPs: "10.8.0.2/32"
      persistentKeepalive: 25

service:
  type: LoadBalancer
  loadBalancerIP: "192.168.1.100"  # Your Pi's IP
```

### Advanced Configuration

```yaml
# Custom network routing
wireguard:
  allowedNetworks:
    - "10.42.0.0/16"    # Pod network
    - "10.43.0.0/16"    # Service network
    - "192.168.1.0/24"  # LAN network

# DNS configuration
dns:
  enabled: true
  coreDNSIP: "10.43.0.10"
  customDomains:
    - "cluster.local"
    - "swimto.local"
    - "myapp.local"

# Node selection (run on specific node)
nodeSelector:
  kubernetes.io/hostname: pi-node-01

# Resource limits
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

## Managing Clients

### Adding a Client

1. Generate client keys:

```bash
wg genkey | tee privatekey | wg pubkey > publickey
```

2. Add peer to `values.yaml`:

```yaml
wireguard:
  peers:
    - name: new-client
      publicKey: "<PASTE_PUBLIC_KEY_HERE>"
      allowedIPs: "10.8.0.4/32"
      persistentKeepalive: 25
```

3. Upgrade the release:

```bash
helm upgrade wireguard ./helm/wireguard \
  --namespace wireguard \
  --values values.yaml
```

4. Create client config:

```ini
[Interface]
Address = 10.8.0.4/32
PrivateKey = <CLIENT_PRIVATE_KEY>
DNS = 10.8.0.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = <YOUR_PUBLIC_IP>:51820
AllowedIPs = 10.8.0.0/24, 10.42.0.0/16, 10.43.0.0/16, 192.168.1.0/24
PersistentKeepalive = 25
```

### Getting Server Public Key

```bash
kubectl exec -n wireguard deployment/wireguard -- cat /config/publickey
```

## Verification

### Check Deployment Status

```bash
# Check pod status
kubectl get pods -n wireguard

# Check service
kubectl get svc -n wireguard

# Check WireGuard interface
kubectl exec -n wireguard deployment/wireguard -- wg show
```

### Test from Client

After connecting:

```bash
# Test VPN connectivity
ping 10.8.0.1

# Test cluster access
ping 10.43.0.1

# Test DNS
nslookup kubernetes.default.svc.cluster.local 10.8.0.1
```

## Disabling via Kustomization

To disable WireGuard, comment out the helm chart in your `kustomization.yaml`:

```yaml
helmCharts:
  # Disabled WireGuard
  # - name: wireguard
  #   namespace: wireguard
  #   releaseName: wireguard
  #   valuesFile: wireguard-values.yaml
```

Or delete the release:

```bash
helm uninstall wireguard --namespace wireguard
```

## Troubleshooting

### Pod not starting

```bash
# Check logs
kubectl logs -n wireguard deployment/wireguard -c wireguard

# Check events
kubectl describe pod -n wireguard <pod-name>

# Common issues:
# - Kernel modules not loaded (check node)
# - Insufficient permissions (check securityContext)
# - Port already in use
```

### Clients can't connect

```bash
# Check service external IP
kubectl get svc -n wireguard

# Check firewall on router
# UDP port 51820 must be forwarded

# Check WireGuard status
kubectl exec -n wireguard deployment/wireguard -- wg show

# Check for handshakes
kubectl exec -n wireguard deployment/wireguard -- wg show wg0 latest-handshakes
```

### DNS not working

```bash
# Check dnsmasq container
kubectl logs -n wireguard deployment/wireguard -c dnsmasq

# Check CoreDNS IP
kubectl get svc -n kube-system kube-dns

# Test DNS from pod
kubectl exec -n wireguard deployment/wireguard -- nslookup kubernetes.default.svc.cluster.local
```

### Routing issues

```bash
# Check iptables rules
kubectl exec -n wireguard deployment/wireguard -- iptables -t nat -L -n -v

# Check IP forwarding
kubectl exec -n wireguard deployment/wireguard -- sysctl net.ipv4.ip_forward
```

## Values Reference

See [values.yaml](values.yaml) for complete configuration options.

## Security Considerations

1. **Private Keys**: Never commit private keys to git
2. **Use Secrets**: Store keys in Kubernetes secrets
3. **RBAC**: Limit access to the wireguard namespace
4. **Network Policies**: Restrict pod-to-pod communication
5. **Regular Updates**: Keep WireGuard image updated

## Uninstallation

```bash
# Delete the release
helm uninstall wireguard --namespace wireguard

# Delete the namespace
kubectl delete namespace wireguard
```

## Support

- Chart Issues: https://github.com/raolivei/pi-fleet/issues
- WireGuard Docs: https://www.wireguard.com/
- k3s Networking: https://docs.k3s.io/networking

## License

See [LICENSE](../../../LICENSE) in the repository root.

