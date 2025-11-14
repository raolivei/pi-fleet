# WireGuard VPN Quick Start

Get your VPN running in 5 minutes!

## Prerequisites

- SSH access to `eldertree` (Raspberry Pi)
- Router access (for port forwarding, if behind NAT)
- Public IP address or dynamic DNS hostname

## Step 1: Install WireGuard on Raspberry Pi

```bash
ssh raolivei@eldertree
cd /tmp
curl -O https://raw.githubusercontent.com/raolivei/raolivei/main/pi-fleet/clusters/eldertree/infrastructure/wireguard/install-wireguard.sh
chmod +x install-wireguard.sh
sudo ./install-wireguard.sh
```

**Note:** The script will:
- Install WireGuard
- Generate server keys
- Create server configuration
- Enable IP forwarding
- Configure firewall rules
- Start WireGuard service

## Step 2: Configure Router (If Behind NAT)

If your Raspberry Pi is behind a router/NAT:

1. Log into your router admin panel
2. Find "Port Forwarding" or "Virtual Server" settings
3. Forward UDP port `51820` to `192.168.2.83`
4. Save and apply

**Note:** If you don't have a static public IP, consider using a dynamic DNS service (DuckDNS, No-IP, etc.)

## Step 3: Generate Client Configurations

On your Mac:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/infrastructure/wireguard
./generate-client.sh mac
./generate-client.sh mobile
```

This creates:
- `client-mac.conf` - For macOS
- `client-mobile.conf` - For iOS/Android
- `client-mobile.png` - QR code for mobile app

## Step 4: Connect from Mac

```bash
# Install WireGuard (if not already installed)
brew install wireguard-tools

# Copy config
sudo mkdir -p /usr/local/etc/wireguard
sudo cp client-mac.conf /usr/local/etc/wireguard/wg0.conf

# Start VPN
sudo wg-quick up wg0

# Check status
sudo wg show
```

**To stop VPN:**
```bash
sudo wg-quick down wg0
```

## Step 5: Connect from Mobile

### iOS
1. Install "WireGuard" from App Store
2. Open WireGuard app
3. Tap "+" → "Create from QR code"
4. Scan `client-mobile.png`
5. Tap "Add" → Toggle switch to connect

### Android
1. Install "WireGuard" from Play Store
2. Open WireGuard app
3. Tap "+" → "Create from QR code"
4. Scan `client-mobile.png`
5. Tap "Save" → Toggle switch to connect

## Step 6: Test Connection

```bash
# Ping the cluster
ping 192.168.2.83

# Access Kubernetes
kubectl get nodes

# Access cluster services
curl -k https://canopy.eldertree.local/api/v1/health
```

## Troubleshooting

### Can't Connect to VPN

1. **Check server status:**
   ```bash
   ssh raolivei@eldertree "sudo systemctl status wg-quick@wg0"
   ```

2. **Check firewall:**
   ```bash
   ssh raolivei@eldertree "sudo ufw status"
   # Should show UDP 51820 allowed
   ```

3. **Check server logs:**
   ```bash
   ssh raolivei@eldertree "sudo journalctl -u wg-quick@wg0 -n 50"
   ```

4. **Verify port forwarding:**
   - Test from external network: `nc -u -v YOUR_PUBLIC_IP 51820`
   - Or use online port checker

### Can't Access Cluster Services

1. **Check routing:**
   ```bash
   # On client
   ip route | grep 192.168.2
   # Should show route through wg0 interface
   ```

2. **Check DNS:**
   ```bash
   nslookup canopy.eldertree.local
   # Should resolve to 192.168.2.83
   ```

3. **Check WireGuard interface:**
   ```bash
   sudo wg show
   # Should show handshake times (recent)
   ```

### Update Public IP

If your public IP changes:

1. Update client configs:
   ```bash
   # Edit client configs and update Endpoint line
   nano client-mac.conf
   # Change: Endpoint = NEW_IP:51820
   ```

2. Or regenerate configs:
   ```bash
   ./generate-client.sh mac
   ./generate-client.sh mobile
   ```

## Security Notes

- ✅ Private keys are never shared
- ✅ Each client has unique keys
- ✅ Modern cryptography (ChaCha20, Poly1305)
- ✅ No certificate management needed
- ⚠️ Keep client config files secure (they contain private keys)
- ⚠️ Don't commit config files to git (use .gitignore)

## Next Steps

- Set up dynamic DNS for automatic IP updates
- Configure WireGuard to start on boot (already enabled)
- Add more clients as needed
- Set up split tunneling if desired

For detailed documentation, see [README.md](README.md)

