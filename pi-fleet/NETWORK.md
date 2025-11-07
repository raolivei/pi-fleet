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

## Local DNS Setup

### Option 1: Router DNS (Recommended)
Configure in router if supported (most home routers with custom firmware).

### Option 2: /etc/hosts
Add to `/etc/hosts` on all machines accessing the cluster:

```
192.168.2.83  eldertree
192.168.2.83  longhorn.eldertree.local
192.168.2.83  grafana.eldertree.local
192.168.2.83  prometheus.eldertree.local
```

## Service Domains

Local services will use `.eldertree.local` domain:
- `longhorn.eldertree.local` - Storage UI
- `grafana.eldertree.local` - Monitoring dashboards
- `prometheus.eldertree.local` - Metrics endpoint

All services use self-signed TLS certificates.

