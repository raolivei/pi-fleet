# Network Configuration

## Current Setup

**Control Plane:**

- Hostname: `eldertree`
- IP: `192.168.2.83`
- Network: `192.168.2.0/24`

## Static IP Configuration

To ensure cluster stability, configure static IP via router DHCP reservation:

1. Access router admin panel
2. Find eldertree MAC address in DHCP leases
3. Create DHCP reservation for `192.168.2.83`

## DNS Setup

### Option 1: External-DNS with RFC2136 (Recommended - Fully Automated)

External-DNS automatically creates DNS records when Ingress resources are created.

**How it works:**

- Create Ingress with hostname → External-DNS creates DNS record automatically
- Delete Ingress → DNS record removed automatically
- No manual ConfigMap updates needed

**Configure macOS/Router:**

- Set DNS to `192.168.2.83:30053` (Pi-hole NodePort)
- Or configure router DNS for network-wide access

**Add new services:**
Simply create an Ingress resource - External-DNS handles DNS automatically:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-service
spec:
  rules:
    - host: myservice.eldertree.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

**Verify:**

```bash
kubectl get pods -n external-dns
kubectl logs -n external-dns deployment/external-dns
nslookup myservice.eldertree.local 192.168.2.83
```

**Note:** Pi-hole uses dnsmasq which has limited RFC2136 support. See `clusters/eldertree/infrastructure/external-dns/README.md` for configuration details.

### Option 2: Pi-hole DNS (Manual ConfigMap)

Pi-hole resolves `*.eldertree.local` domains via Kubernetes ConfigMap.

**Add new services:**
Update ConfigMap: `clusters/eldertree/infrastructure/pihole/configmap.yaml`

```yaml
data:
  05-custom-dns.conf: |
    address=/newservice.eldertree.local/192.168.2.83
```

Then: `kubectl apply -f ... && kubectl rollout restart deployment/pihole -n pihole`

### Option 3: /etc/hosts (Manual)

Add to `/etc/hosts` on all machines:

```
192.168.2.83  eldertree
192.168.2.83  grafana.eldertree.local
192.168.2.83  prometheus.eldertree.local
192.168.2.83  canopy.eldertree.local
192.168.2.83  pihole.eldertree.local
192.168.2.83  vault.eldertree.local
```

## Service Domains

Local services use `.eldertree.local` domain with self-signed TLS:

- `grafana.eldertree.local` - Monitoring dashboards (admin/admin)
- `prometheus.eldertree.local` - Metrics endpoint

## Accessing Services

Access services via HTTPS (accept self-signed certificate warnings):

- `https://grafana.eldertree.local` - Monitoring dashboards (admin/admin)
- `https://prometheus.eldertree.local` - Metrics endpoint
- `https://canopy.eldertree.local` - Finance dashboard
- `https://pihole.eldertree.local` - DNS server
- `https://vault.eldertree.local` - Secrets management

## Remote Access via VPN

### WireGuard VPN

Access your cluster from anywhere (including mobile LTE) using WireGuard VPN.

**Quick Setup:**

```bash
cd clusters/eldertree/infrastructure/wireguard
./setup-vpn.sh
```

**Manual Setup:**

1. **Install WireGuard on Raspberry Pi:**
   ```bash
   ssh raolivei@eldertree
   cd /tmp
   curl -O https://raw.githubusercontent.com/raolivei/raolivei/main/pi-fleet/clusters/eldertree/infrastructure/wireguard/install-wireguard.sh
   sudo bash install-wireguard.sh
   ```

2. **Generate client configs:**
   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/infrastructure/wireguard
   ./generate-client.sh mac
   ./generate-client.sh mobile
   ```

3. **Connect from Mac:**
   ```bash
   brew install wireguard-tools
   sudo cp client-mac.conf /usr/local/etc/wireguard/wg0.conf
   sudo wg-quick up wg0
   ```

4. **Connect from Mobile:**
   - Install WireGuard app
   - Scan QR code (`client-mobile.png`) or import config

**VPN Details:**
- **VPN Network**: `10.8.0.0/24`
- **Server IP**: `10.8.0.1`
- **Port**: UDP `51820`
- **Access**: Full access to `192.168.2.0/24` network

**Once connected, you can access:**
- Kubernetes API: `kubectl get nodes`
- Cluster services: `https://canopy.eldertree.local`
- SSH: `ssh raolivei@192.168.2.83`

See `clusters/eldertree/infrastructure/wireguard/README.md` for detailed documentation.

## Troubleshooting DNS

**DNS not resolving:**

```bash
kubectl get pods -n pihole
kubectl exec -it deployment/pihole -n pihole -- cat /etc/dnsmasq.d/05-custom-dns.conf
kubectl logs -n pihole deployment/pihole
```
