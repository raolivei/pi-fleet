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

### Option 1: Pi-hole DNS (Recommended - Automatic)

Pi-hole automatically resolves `*.eldertree.local` domains via Kubernetes ConfigMap.

**Configure macOS/Router:**
- Set DNS to `192.168.2.83:30053` (Pi-hole NodePort)
- Or configure router DNS for network-wide access

**Verify:**
```bash
nslookup canopy.eldertree.local 192.168.2.83
dig @192.168.2.83 canopy.eldertree.local
```

**Add new services:**
Update ConfigMap: `clusters/eldertree/infrastructure/pihole/configmap.yaml`
```yaml
data:
  05-custom-dns.conf: |
    address=/newservice.eldertree.local/192.168.2.83
```
Then: `kubectl apply -f ... && kubectl rollout restart deployment/pihole -n pihole`

### Option 2: /etc/hosts (Manual)

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

## Troubleshooting DNS

**DNS not resolving:**
```bash
kubectl get pods -n pihole
kubectl exec -it deployment/pihole -n pihole -- cat /etc/dnsmasq.d/05-custom-dns.conf
kubectl logs -n pihole deployment/pihole
```
