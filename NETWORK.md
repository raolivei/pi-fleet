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

### Pi-hole as Network DNS Server (Recommended)

Pi-hole is configured as a LoadBalancer service (MetalLB) on port 53, making it available as your network-wide DNS server.

**How it works:**

- MetalLB assigns a virtual IP (`192.168.2.201`) to the Pi-hole service.
- Pi-hole is configured to resolve `*.eldertree.local` to this virtual IP.
- All cluster services are accessible via their `*.eldertree.local` hostnames.
- **Router DNS Configuration**: Set your router's DNS server to `192.168.2.201` so all devices on your network automatically use Pi-hole.

**Configure Router DNS (Network-Wide):**

1. Access your router's admin panel (usually `192.168.2.1` or `192.168.1.1`)
2. Navigate to **Network Settings** → **DHCP Settings** or **DNS Settings**
3. Set **Primary DNS Server** to: `192.168.2.201`
4. Set **Secondary DNS Server** to: `8.8.8.8` (Google DNS) or `1.1.1.1` (Cloudflare DNS) as fallback
5. Save and apply changes
6. **Restart devices** or renew DHCP leases to pick up the new DNS settings

**Configure macOS (Device-Level - Optional):**

If you prefer device-level DNS configuration instead of router-level:

1. Open **System Settings** → **Network** → **Wi-Fi/Ethernet** → **Details...** → **DNS**.
2. Add `192.168.2.201` as the primary DNS server.
3. Add `8.8.8.8` or `1.1.1.1` as secondary DNS server.
4. Click **OK** and **Apply**.

**Verify DNS Resolution:**

```bash
# Test DNS resolution
nslookup vault.eldertree.local 192.168.2.201
# Or just (if router DNS is configured)
nslookup vault.eldertree.local

# Test from any device on the network
dig canopy.eldertree.local
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

## Remote Access

### Cloudflare Tunnel

For secure remote access to your cluster services, use Cloudflare Tunnel. See `clusters/eldertree/dns-services/cloudflare-tunnel/README.md` for setup instructions.

**Note:** WireGuard VPN is disabled. Use Cloudflare Tunnel for remote access instead.

## Troubleshooting DNS

**DNS not resolving:**

```bash
kubectl get pods -n pihole
kubectl logs -n pihole deployment/pi-hole -c pihole
```
