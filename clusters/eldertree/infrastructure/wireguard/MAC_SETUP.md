# Mac WireGuard Setup

## Quick Setup

Your Mac client config is ready! Here's how to connect:

### Step 1: Start WireGuard VPN

```bash
sudo wg-quick up wg0
```

### Step 2: Verify Connection

```bash
sudo wg show
```

You should see:
- Interface: `wg0`
- Your IP: `10.8.0.2`
- Server peer with recent handshake

### Step 3: Test Cluster Access

```bash
# Test ping
ping 192.168.2.83

# Test Kubernetes
kubectl get nodes

# Test services
curl -k https://canopy.eldertree.local/api/v1/health
```

### Step 4: Disconnect When Done

```bash
sudo wg-quick down wg0
```

## Using Phone's Mobile Network

1. **Connect Mac to phone's hotspot** (USB, WiFi, or Bluetooth)
2. **Start WireGuard VPN** on Mac: `sudo wg-quick up wg0`
3. **Access cluster** - All `.eldertree.local` domains work!
4. **Use kubectl** - Full cluster access

## Auto-Start on Boot (Optional)

To start WireGuard automatically:

```bash
# Create launch daemon
sudo tee /Library/LaunchDaemons/com.wireguard.wg0.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.wireguard.wg0</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/wg-quick</string>
        <string>up</string>
        <string>wg0</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

# Load it
sudo launchctl load /Library/LaunchDaemons/com.wireguard.wg0.plist
```

## Status Check

```bash
# Check if connected
sudo wg show

# Check routing
ip route | grep 192.168.2

# Test connectivity
ping 192.168.2.83
```

## Troubleshooting

**Can't connect?**
- Check server is running: `ssh raolivei@eldertree "sudo wg show"`
- Verify config: `cat /usr/local/etc/wireguard/wg0.conf`
- Check firewall on Mac

**DNS not working?**
- Try accessing by IP: `https://192.168.2.83`
- Check DNS: `nslookup canopy.eldertree.local 192.168.2.83`

**Slow connection?**
- Normal on mobile networks
- WireGuard adds minimal overhead (~5-10ms)

