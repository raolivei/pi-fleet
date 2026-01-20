# Network Configuration

## Current Setup (January 2026)

**Cluster Nodes:**

| Node   | Hostname                  | wlan0 IP       | eth0 IP   |
|--------|---------------------------|----------------|-----------|
| node-1 | node-1.eldertree.local    | 192.168.2.101  | 10.0.0.1  |
| node-2 | node-2.eldertree.local    | 192.168.2.102  | 10.0.0.2  |
| node-3 | node-3.eldertree.local    | 192.168.2.103  | 10.0.0.3  |

**kube-vip Virtual IPs (ARP Mode):**

kube-vip handles both the HA control plane VIP and LoadBalancer service VIPs.
This replaces MetalLB and provides reliable ARP-based IP assignment.

| VIP            | Service           | Description                    |
|----------------|-------------------|--------------------------------|
| 192.168.2.100  | K8s API Server    | HA control plane VIP           |
| 192.168.2.200  | Traefik Ingress   | HTTPS ingress for all services |
| 192.168.2.201  | Pi-hole           | DNS server                     |

**k3s Internal Networks:**

| Network        | CIDR            | Description          |
|----------------|-----------------|----------------------|
| Pod Network    | 10.42.0.0/16    | Container IPs        |
| Service Network| 10.43.0.0/16    | ClusterIP services   |
| Internal       | 10.0.0.0/24     | Node eth0 (internal) |

## Static IP Configuration

To ensure cluster stability, configure static IP via router DHCP reservation:

1. Access router admin panel
2. Find node MAC addresses in DHCP leases
3. Create DHCP reservations for:
   - node-1: `192.168.2.101` (wlan0)
   - node-2: `192.168.2.102` (wlan0)
   - node-3: `192.168.2.103` (wlan0)

## DNS Setup

### Pi-hole as Network DNS Server (Recommended)

Pi-hole is configured as a LoadBalancer service (kube-vip) on port 53, making it available as your network-wide DNS server.

**How it works:**

- kube-vip assigns a virtual IP (`192.168.2.201`) to the Pi-hole service.
- Pi-hole is configured to resolve `*.eldertree.local` to the Traefik VIP.
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
# ElderTree k8s Cluster VIP (Traefik Ingress)
192.168.2.200  grafana.eldertree.local
192.168.2.200  prometheus.eldertree.local
192.168.2.200  vault.eldertree.local
192.168.2.200  canopy.eldertree.local
192.168.2.200  visage.eldertree.local
192.168.2.200  minio.eldertree.local
192.168.2.200  swimto.eldertree.local
192.168.2.200  pitanga.eldertree.local
192.168.2.200  pushgateway.eldertree.local

# Cluster Nodes
192.168.2.101  node-1.eldertree.local
192.168.2.102  node-2.eldertree.local
192.168.2.103  node-3.eldertree.local
```

> **Note:** Pi-hole (192.168.2.201) handles DNS. Use /etc/hosts only as fallback.

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

### Tailscale VPN (Recommended)

Tailscale provides secure, zero-config VPN access with automatic HA failover. All 3 nodes are configured as subnet routers.

**Tailscale IPs (100.x.x.x network):**

| Node   | Tailscale IP     | Status        |
|--------|------------------|---------------|
| node-1 | 100.86.241.124   | Subnet Router |
| node-2 | 100.116.185.57   | Subnet Router |
| node-3 | 100.104.30.105   | Subnet Router |

**Advertised Subnets:**
- `192.168.2.0/24` - Home LAN
- `10.42.0.0/16` - Kubernetes pod network
- `10.43.0.0/16` - Kubernetes service network

**Client Setup:**

1. Install Tailscale on your device (Mac/iOS/Android/Windows/Linux)
2. Login with same Tailscale account
3. Enable "Accept Routes" in Tailscale settings
4. Access cluster via LAN IPs (192.168.2.x) from anywhere

**Automatic Failover:** If a node goes down, Tailscale automatically routes traffic through another subnet router (~15 seconds).

**Remote kubectl Access:**

```bash
# When at home (LAN)
export KUBECONFIG=~/.kube/config-eldertree

# When remote (mobile LTE, travel, etc.)
export KUBECONFIG=~/.kube/config-eldertree-remote
```

**Auth Key:** Stored in Vault at `secret/pi-fleet/tailscale`

**Ansible Playbook:** `ansible/playbooks/install-tailscale.yml`

**Full Documentation:** See `docs/TAILSCALE.md`

### Cloudflare Tunnel

For public-facing services, Cloudflare Tunnel provides secure access without port forwarding. See `clusters/eldertree/dns-services/cloudflare-tunnel/README.md` for setup instructions.

## Troubleshooting DNS

**DNS not resolving:**

```bash
kubectl get pods -n pihole
kubectl logs -n pihole deployment/pi-hole -c pihole
```
