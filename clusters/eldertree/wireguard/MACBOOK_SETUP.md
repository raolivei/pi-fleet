# MacBook WireGuard Setup

## ✅ Deployment Complete!

WireGuard is deployed and running in your eldertree cluster. Your MacBook is configured as a client.

## 📋 Connection Details

- **Server Public IP**: `184.147.64.214`
- **WireGuard Port**: `51820 (UDP)`
- **Your VPN IP**: `10.8.0.2`
- **Server VPN IP**: `10.8.0.1`
- **Client Config**: `/Users/roliveira/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/macbook.conf`

## 🚀 Setup Steps

### 1. Install WireGuard on Mac

```bash
# Install WireGuard tools
brew install wireguard-tools

# Install WireGuard GUI app
brew install --cask wireguard
```

### 2. Import Configuration

**Option A: Using GUI (Recommended)**

1. Open WireGuard app (from Applications or Spotlight)
2. Click "Import tunnel(s) from file..."
3. Select: `/Users/roliveira/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/macbook.conf`
4. Click "Activate"

**Option B: Using Terminal**

```bash
# Copy config to WireGuard directory
sudo mkdir -p /usr/local/etc/wireguard
sudo cp ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/macbook.conf /usr/local/etc/wireguard/

# Start the tunnel
sudo wg-quick up macbook

# Check status
sudo wg show
```

### 3. Configure Router Port Forwarding ⚠️  **CRITICAL**

You MUST forward UDP port 51820 to your Raspberry Pi for external access:

**Router Settings:**
- **Service Name**: WireGuard
- **External Port**: 51820
- **Internal Port**: 51820
- **Protocol**: UDP only
- **Internal IP**: 192.168.2.83 (your Pi)
- **Enable**: Yes

**To access your router:**
- Usually at: http://192.168.2.1 or http://192.168.1.1
- Look for "Port Forwarding" or "Virtual Servers" section

### 4. Test Connection

Once connected to VPN (while on LTE from your phone):

```bash
# Test tunnel connectivity
ping 10.8.0.1

# Test cluster access
ping 10.43.0.1

# Verify split-tunnel (should NOT show wg0)
ip route | grep default

# Verify cluster routes (should show utun interface on Mac)
ip route get 10.43.0.1

# Test internet (should work normally)
curl ifconfig.me

# Test cluster DNS (after reconnecting to home network or when DNS is fixed)
dig @10.8.0.1 kubernetes.default.svc.cluster.local
```

## 🔍 Verification Checklist

- [ ] WireGuard installed on Mac
- [ ] Config imported successfully
- [ ] Router port forwarding configured (UDP 51820)
- [ ] Connected to WireGuard
- [ ] Can ping 10.8.0.1 (VPN server)
- [ ] Can ping 10.43.0.1 (k3s API)
- [ ] Internet still works (split-tunnel verified)
- [ ] Can access k8s services

## 📱 Testing on LTE

When you tether from your phone (Bell LTE):

1. Connect Mac to iPhone hotspot
2. Activate WireGuard tunnel
3. Run tests above
4. You should be able to access your cluster as if you're at home!

## 🌐 What Gets Routed Through VPN

**YES - Through VPN:**
- `10.8.0.0/24` - WireGuard tunnel network
- `10.42.0.0/16` - k3s Pod IPs
- `10.43.0.0/16` - k3s Service IPs
- `192.168.2.0/24` - Your home LAN

**NO - Bypasses VPN:**
- Everything else (normal internet traffic)
- This means your internet speed is NOT affected!

## 🔧 Troubleshooting

### Can't Connect

```bash
# Check if WireGuard is running
sudo wg show

# Check if port forwarding works
nc -vzu 184.147.64.214 51820

# Check router logs for blocked connections
```

### Connected But Can't Access Cluster

```bash
# Verify routes
netstat -rn | grep 10.42
netstat -rn | grep 10.43

# Check WireGuard handshake
sudo wg show macbook latest-handshakes

# If no handshake, check router port forwarding!
```

### Internet Not Working

This means split-tunnel failed. Check your `AllowedIPs` in config:

```bash
# Should be:
AllowedIPs = 10.8.0.0/24, 10.42.0.0/16, 10.43.0.0/16, 192.168.2.0/24

# Should NOT be:
AllowedIPs = 0.0.0.0/0  # This routes ALL traffic through VPN
```

### DNS Not Working

DNS (dnsmasq) is currently disabled due to ARM64 compatibility issues. You can:

1. Use IP addresses directly: `http://10.43.x.x:port`
2. Use k8s DNS from within the cluster
3. Set up CoreDNS forwarding manually later

## 📊 Monitoring

Check server status:

```bash
# WireGuard status
kubectl exec -n wireguard deployment/wireguard -- wg show

# Pod status
kubectl get pods -n wireguard

# Service status
kubectl get svc -n wireguard

# Logs
kubectl logs -n wireguard deployment/wireguard -f
```

## 🔐 Security Notes

1. **Private Key**: Keep `macbook.conf` secure - it contains your private key
2. **Router Access**: Ensure your router admin password is strong
3. **Firewall**: Only UDP 51820 should be forwarded, nothing else
4. **Key Rotation**: Change keys every 6-12 months

## 🎯 Next Steps

1. **Test locally first**: Before going to LTE, test while on home network
2. **Configure port forwarding**: This is required for external access
3. **Test on LTE**: Tether from phone and verify connectivity
4. **Add more clients**: iPhone, iPad, etc. using the same process

## 📚 Useful Commands

```bash
# Disconnect
sudo wg-quick down macbook

# Reconnect
sudo wg-quick up macbook

# Show status
sudo wg show

# Show active tunnels (GUI)
# Just open the WireGuard app

# Test specific service
curl -k https://10.43.x.x:port
```

## 🆘 Getting Help

If you have issues:

1. Check pod logs: `kubectl logs -n wireguard deployment/wireguard`
2. Verify port forwarding on router
3. Test from home network first, then LTE
4. Check WireGuard handshake times

---

**Remember**: You MUST configure router port forwarding for this to work from outside your network (LTE)!

