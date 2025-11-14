# VPN Testing Guide

## Current Setup ✅

- **Server**: Running on Raspberry Pi (192.168.2.83)
- **Public IP**: 184.147.64.214
- **Port**: UDP 51820
- **Mac Client Config**: Ready at `/opt/homebrew/etc/wireguard/wg0.conf`

## Testing Steps

### Step 1: Connect to Different Network

Switch your Mac to:
- **Phone's mobile hotspot** (LTE/5G), OR
- **Different WiFi network** (coffee shop, etc.)

### Step 2: Connect VPN

**Option A: Using WireGuard GUI App**
1. Open WireGuard app
2. Find "eldertree" tunnel
3. Click toggle switch to **ON** (should turn green)
4. Status should show "Active"

**Option B: Using Command Line**
```bash
sudo wg-quick up wg0
```

### Step 3: Verify Connection

```bash
# Check VPN status
sudo wg show

# Should show:
# - Interface: wg0 (or utunX)
# - Your IP: 10.8.0.2
# - Peer connection with handshake time
```

### Step 4: Test Cluster Access

```bash
# Test ping
ping 192.168.2.83

# Test Kubernetes
kubectl get nodes

# Test services
curl -k https://canopy.eldertree.local/api/v1/health

# Test DNS
nslookup canopy.eldertree.local 192.168.2.83
```

### Step 5: Verify You're on VPN

```bash
# Check routing
netstat -rn | grep "192.168.2"

# Should show route through utun interface

# Check your public IP (should be your home IP, not VPN IP)
curl ifconfig.me
```

## Expected Results

✅ **VPN Connected:**
- `sudo wg show` shows active connection
- `ping 192.168.2.83` works
- `kubectl get nodes` works
- Can access `https://canopy.eldertree.local`

❌ **If Not Working:**
- Check WireGuard app shows "Active"
- Verify server is running: `ssh raolivei@eldertree "sudo wg show"`
- Check firewall/router port forwarding (UDP 51820)
- Try disconnecting and reconnecting VPN

## Troubleshooting

**Can't connect?**
- Check server status: `ssh raolivei@eldertree "sudo systemctl status wg-quick@wg0"`
- Verify port forwarding on router
- Check mobile carrier isn't blocking VPN

**Connected but can't access services?**
- Check DNS: `nslookup canopy.eldertree.local 192.168.2.83`
- Try accessing by IP: `https://192.168.2.83`
- Check routing: `netstat -rn | grep 192.168.2`

**Slow connection?**
- Normal on mobile networks
- WireGuard adds minimal overhead (~5-10ms)

## Success Indicators

✅ WireGuard shows "Active"  
✅ `ping 192.168.2.83` works  
✅ `kubectl get nodes` works  
✅ Can access cluster services  
✅ Works from any network (WiFi, LTE, etc.)  

