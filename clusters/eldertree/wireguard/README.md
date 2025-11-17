# WireGuard Split-Tunnel for k3s Cluster Access

Complete setup for secure external access to the **eldertree** k3s cluster using WireGuard with split-tunneling.

## 🎯 What This Does

- **Split-tunnel VPN**: Only cluster traffic goes through VPN, internet traffic bypasses it
- **Access pod IPs** (10.42.0.0/16), **service IPs** (10.43.0.0/16), and **node IPs**
- **DNS resolution** for `*.cluster.local` and custom internal domains
- **No internet speed impact**: Normal browsing uses your regular connection

## 📦 What's Included

```
wireguard/
├── wg0.conf              # Server configuration template
├── client-template.conf  # Client configuration template
├── setup-server.sh       # Automated server setup
├── generate-client.sh    # Generate client configs + QR codes
├── setup-dns.sh          # Configure DNS forwarding
├── verify.sh             # Client-side verification script
└── README.md             # This file
```

## 🚀 Quick Start

### On the Raspberry Pi (Server)

```bash
# 1. Navigate to WireGuard directory
cd /path/to/pi-fleet/clusters/eldertree/wireguard

# 2. Run server setup (installs WireGuard, generates keys, configures)
sudo ./setup-server.sh

# 3. Setup DNS forwarding for cluster.local domains
sudo ./setup-dns.sh

# 4. Generate client configuration
./generate-client.sh iphone 2    # Creates config for client at 10.8.0.2
./generate-client.sh macbook 3   # Creates config for client at 10.8.0.3

# 5. Add the generated peer config to server (shown in output)
sudo nano /etc/wireguard/wg0.conf
# Add the [Peer] section printed by generate-client.sh

# 6. Restart WireGuard
sudo systemctl restart wg-quick@wg0

# 7. Open firewall port (if using ufw)
sudo ufw allow 51820/udp
```

### Network Setup

**CRITICAL**: Ensure UDP port **51820** is forwarded on your router to the Raspberry Pi.

Router configuration example:
- External Port: 51820
- Internal Port: 51820
- Protocol: UDP
- Internal IP: Your Pi's IP (e.g., 192.168.1.100)

### On Client Devices

#### iPhone/iPad

1. Install WireGuard app from App Store
2. Scan QR code from `clients/<name>.png` OR
3. Transfer `clients/<name>.conf` via AirDrop/email
4. Import configuration
5. Connect

#### Mac

```bash
# Install WireGuard
brew install wireguard-tools

# Copy client config
scp user@pi:/path/to/clients/macbook.conf /usr/local/etc/wireguard/

# Start WireGuard
sudo wg-quick up macbook

# Verify
./verify.sh
```

#### Windows

1. Download [WireGuard for Windows](https://www.wireguard.com/install/)
2. Import `clients/<name>.conf`
3. Activate tunnel

## 🔧 Configuration Details

### Network Layout

| Network | Purpose | Routes Through VPN |
|---------|---------|-------------------|
| 10.8.0.0/24 | WireGuard tunnel | ✅ Yes |
| 10.42.0.0/16 | k3s Pod IPs | ✅ Yes |
| 10.43.0.0/16 | k3s Service IPs | ✅ Yes |
| 192.168.1.0/24 | LAN network | ✅ Yes (optional) |
| 0.0.0.0/0 | Internet | ❌ No (bypasses VPN) |

### How Split-Tunnel Works

The client config uses `AllowedIPs` to route ONLY specific networks through the VPN:

```conf
AllowedIPs = 10.8.0.0/24, 10.42.0.0/16, 10.43.0.0/16, 192.168.1.0/24
```

**Key point**: We do NOT include `0.0.0.0/0`, so the default route stays unchanged. Your internet traffic flows normally while cluster traffic is tunneled.

### DNS Configuration

The DNS setup forwards cluster-specific queries to k3s CoreDNS:

```
*.cluster.local    → k3s CoreDNS (10.43.0.10)
*.swimto.local     → k3s CoreDNS
*.canopy.local     → k3s CoreDNS
everything else    → System default DNS
```

This is handled by dnsmasq on the WireGuard server.

## 🧪 Verification

Run on client after connecting:

```bash
# Check connection status
sudo wg show

# Verify split-tunnel (should NOT show wg0)
ip route | grep default

# Verify cluster routes (should show wg0)
ip route get 10.43.0.1

# Test DNS
dig @10.8.0.1 kubernetes.default.svc.cluster.local

# Run full verification suite
./verify.sh
```

### Expected Results

```bash
# Default route should bypass VPN
$ ip route | grep default
default via 192.168.1.1 dev eth0  # NOT wg0

# Cluster routes should use VPN
$ ip route get 10.43.0.1
10.43.0.1 dev wg0 src 10.8.0.2

# Internet should work normally
$ curl ifconfig.me
<Your real public IP, NOT the Pi's IP>

# Cluster DNS should resolve
$ dig @10.8.0.1 kubernetes.default.svc.cluster.local +short
10.43.0.1
```

## 🔒 Security Notes

1. **Private keys**: Never commit private keys to git
2. **Firewall**: Only expose UDP 51820, block everything else
3. **Key rotation**: Regenerate keys periodically
4. **Peer isolation**: Each client gets unique IP and keys
5. **HTTPS still required**: WireGuard encrypts transport, but use HTTPS for application layer

## 🐛 Troubleshooting

### Can't connect to VPN

```bash
# Check server status
sudo systemctl status wg-quick@wg0
sudo wg show

# Check firewall
sudo ufw status | grep 51820

# Check logs
journalctl -u wg-quick@wg0 -f
```

### Connected but can't reach cluster

```bash
# Check IP forwarding
sysctl net.ipv4.ip_forward  # Should be 1

# Check iptables rules
sudo iptables -t nat -L -n -v | grep 10.42
sudo iptables -L FORWARD -n -v | grep wg0

# Check routes on client
ip route get 10.43.0.1  # Should show wg0
```

### DNS not working

```bash
# Check dnsmasq on server
sudo systemctl status dnsmasq
sudo journalctl -u dnsmasq -f

# Test direct query
dig @10.8.0.1 kubernetes.default.svc.cluster.local

# Check CoreDNS in cluster
kubectl get svc -n kube-system kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### Internet broken after connecting

This means split-tunnel is NOT working. Check client config:

```bash
# Your AllowedIPs should NOT include 0.0.0.0/0
grep AllowedIPs <your-config>.conf

# Should be:
AllowedIPs = 10.8.0.0/24, 10.42.0.0/16, 10.43.0.0/16, 192.168.1.0/24

# NOT:
AllowedIPs = 0.0.0.0/0
```

### Can ping services but HTTP doesn't work

This is usually a DNS issue. Services use DNS names, not IPs:

```bash
# Instead of: http://10.43.x.x:8080
# Use: http://myservice.default.svc.cluster.local:8080

# Or configure ingress with custom domain
```

## 📚 Technical Deep Dive

### Why This Works

1. **Server iptables rules** NAT traffic from WireGuard subnet to cluster subnets
2. **Client AllowedIPs** tell WireGuard which networks to route through tunnel
3. **dnsmasq** on server forwards cluster DNS queries to CoreDNS
4. **IP forwarding** on server allows packets to traverse from wg0 to cluster network

### Architecture Flow

```
Client Device
    ↓ (Routes 10.43.0.0/16 to wg0)
WireGuard Tunnel (10.8.0.0/24)
    ↓
Raspberry Pi wg0 (10.8.0.1)
    ↓ (iptables NAT)
k3s cni0 / flannel.1
    ↓
k3s Pod Network (10.42.0.0/16)
k3s Service Network (10.43.0.0/16)
```

### Key Components

- **WireGuard**: Encrypted tunnel (UDP 51820)
- **iptables NAT**: Routes traffic from tunnel to cluster
- **dnsmasq**: Forwards DNS queries to CoreDNS
- **k3s CNI**: Handles pod networking (flannel/cilium)
- **CoreDNS**: Resolves cluster.local domains

## 🔄 Adding More Clients

```bash
# Generate new client config
./generate-client.sh newclient 4

# Add peer to server
sudo nano /etc/wireguard/wg0.conf
# Paste [Peer] section from script output

# Reload server config
sudo wg syncconf wg0 <(wg-quick strip wg0)
# OR restart
sudo systemctl restart wg-quick@wg0
```

## 🎓 Additional Resources

- [WireGuard Official Docs](https://www.wireguard.com/)
- [k3s Networking](https://docs.k3s.io/networking)
- [iptables NAT Tutorial](https://www.karlrupp.net/en/computer/nat_tutorial)

## 📝 Maintenance

### Regular Tasks

- **Monitor logs**: `journalctl -u wg-quick@wg0 -f`
- **Check connections**: `sudo wg show`
- **Rotate keys**: Every 6-12 months
- **Update clients**: When changing server IP/port

### Backup Important Files

```bash
# Backup these files
/etc/wireguard/wg0.conf
/etc/wireguard/privatekey
/etc/wireguard/publickey
/etc/dnsmasq.d/k3s-cluster.conf
```

## 🆘 Support

Check these files for project-specific networking:
- `pi-fleet/NETWORK.md` - Cluster networking details
- `pi-fleet/clusters/eldertree/README.md` - Cluster overview

## 📋 Version

This configuration is tested with:
- **OS**: Debian Bookworm (Raspberry Pi 5)
- **k3s**: v1.28+ (cluster: eldertree)
- **WireGuard**: Latest via apt
- **Clients**: iOS 17+, macOS 14+, Windows 11

---

**Remember**: This is a split-tunnel setup. Your internet traffic stays fast and private while cluster access is secured through the VPN. Best of both worlds! 🚀

