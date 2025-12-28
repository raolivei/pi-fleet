# Network Configuration

## Current Setup

**Control Plane:**

- Hostname: `eldertree`
- IP: `192.168.2.86` (node-0)
- Network: `192.168.2.0/24`

## Static IP Configuration

To ensure cluster stability, configure static IP via router DHCP reservation:

1. Access router admin panel
2. Find node MAC addresses in DHCP leases
3. Create DHCP reservations for:
   - node-0: `192.168.2.86`
   - node-1: `192.168.2.85`

## DNS Setup

### Option 1: Pi-hole with MetalLB (Recommended - Fully Automated)

Pi-hole is exposed via a LoadBalancer service (MetalLB) on port 53.

**How it works:**

- MetalLB assigns a virtual IP (`192.168.2.201`) to the Pi-hole service.
- Pi-hole is configured to resolve `*.eldertree.local` to this virtual IP.
- All cluster services are accessible via their `*.eldertree.local` hostnames.

**Configure macOS:**

1. Open **System Settings** → **Network** → **Wi-Fi/Ethernet** → **Details...** → **DNS**.
2. Add `192.168.2.201` as the only DNS server.
3. Click **OK** and **Apply**.

**Verify:**

```bash
# Test DNS resolution
nslookup vault.eldertree.local 192.168.2.201
# Or just
nslookup vault.eldertree.local
```

### Option 2: /etc/hosts (Manual)

Add to `/etc/hosts` on all machines:

```
192.168.2.201  grafana.eldertree.local
192.168.2.201  prometheus.eldertree.local
192.168.2.201  canopy.eldertree.local
192.168.2.201  pihole.eldertree.local
192.168.2.201  vault.eldertree.local
```

## Service Domains

Local services use `.eldertree.local` domain with self-signed TLS:

- `grafana.eldertree.local` - Monitoring dashboards (admin/admin)
- `prometheus.eldertree.local` - Metrics endpoint
- `vault.eldertree.local` - Secrets management
- `pihole.eldertree.local` - DNS management

## Accessing Services

Access services via HTTPS (accept self-signed certificate warnings):

- `https://grafana.eldertree.local`
- `https://prometheus.eldertree.local`
- `https://canopy.eldertree.local`
- `https://pihole.eldertree.local`
- `https://vault.eldertree.local`

## Remote Access via VPN

### WireGuard VPN

Access your cluster from anywhere (including mobile LTE) using WireGuard VPN.

**Quick Setup:**

```bash
cd clusters/eldertree/dns-services/wireguard
./setup-vpn.sh
```

See `clusters/eldertree/dns-services/wireguard/README.md` for detailed documentation.

## Troubleshooting DNS

**DNS not resolving:**

```bash
kubectl get pods -n pihole
kubectl logs -n pihole deployment/pi-hole -c pihole
```
