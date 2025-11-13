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

## Troubleshooting DNS

**DNS not resolving:**

```bash
kubectl get pods -n pihole
kubectl exec -it deployment/pihole -n pihole -- cat /etc/dnsmasq.d/05-custom-dns.conf
kubectl logs -n pihole deployment/pihole
```
