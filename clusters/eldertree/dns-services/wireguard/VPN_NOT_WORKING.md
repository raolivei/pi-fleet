# WireGuard VPN Not Working - Troubleshooting Guide

## Current Status
- ✅ WireGuard server is running on Pi
- ✅ VPN interface is up on client (utun6)
- ✅ Routing configured correctly
- ❌ **No handshake occurring** - packets not reaching server

## Most Likely Issues

### 1. Router Port Forwarding Not Configured

**Check:**
- Log into your router admin panel (usually `192.168.2.1` or `192.168.1.1`)
- Look for "Port Forwarding", "Virtual Server", or "NAT Forwarding"
- Verify UDP port 51820 is forwarded to `192.168.2.83`

**Fix:**
1. Add port forwarding rule:
   - **Protocol**: UDP
   - **External Port**: 51820
   - **Internal IP**: 192.168.2.83
   - **Internal Port**: 51820
2. Save and apply
3. Some routers require a restart

### 2. Router Firewall Blocking VPN

**Check:**
- Router admin panel → Firewall settings
- Look for "VPN Passthrough" or "PPTP/L2TP Passthrough"
- Check if UDP port 51820 is blocked

**Fix:**
- Enable VPN passthrough if available
- Add firewall exception for UDP 51820
- Temporarily disable firewall to test (then re-enable)

### 3. Public IP Changed

**Check:**
```bash
# From home network, check server's current public IP
sshpass -p 'Control01!' ssh raolivei@192.168.2.83 "curl -s ifconfig.me"
```

**Fix:**
- Update client configs with new public IP
- Update `Endpoint = NEW_IP:51820` in client-mac.conf and client-mobile.conf
- Re-import config into WireGuard app

### 4. Mobile Carrier Blocking VPN

**Test:**
- Try connecting from different WiFi network (coffee shop, etc.)
- If WiFi works but LTE doesn't → carrier blocking
- Some carriers block VPN connections

**Fix:**
- Contact carrier to unblock VPN traffic
- Try different mobile carrier
- Use WiFi instead of LTE

## Diagnostic Steps

### Step 1: Check Server Status (from home network)

```bash
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/check-wireguard-server.sh
```

This will show:
- Current public IP
- WireGuard status
- Firewall rules
- Connection attempts

### Step 2: Verify Router Port Forwarding

1. Log into router: `http://192.168.2.1` (or your router IP)
2. Find "Port Forwarding" section
3. Verify UDP 51820 → 192.168.2.83 exists
4. If missing, add it

### Step 3: Test Port from External Network

From mobile LTE (not home WiFi):
```bash
# Use online port checker
# Visit: https://www.yougetsignal.com/tools/open-ports/
# Check UDP port 51820 on your public IP
```

If port shows closed → router port forwarding issue

### Step 4: Update Client Config if IP Changed

```bash
# Get current public IP
sshpass -p 'Control01!' ssh raolivei@192.168.2.83 "curl -s ifconfig.me"

# Update client configs
cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/dns-services/wireguard
# Edit client-mac.conf and client-mobile.conf
# Change Endpoint = OLD_IP:51820 to Endpoint = NEW_IP:51820
```

### Step 5: Restart WireGuard on Server

```bash
sshpass -p 'Control01!' ssh raolivei@192.168.2.83 "sudo systemctl restart wg-quick@wg0"
```

### Step 6: Reconnect VPN

1. Disconnect VPN on client
2. Wait 5 seconds
3. Reconnect VPN
4. Check for handshake: `sudo wg show` (should show endpoint and handshake time)

## Quick Fix Checklist

- [ ] Router port forwarding configured (UDP 51820 → 192.168.2.83)
- [ ] Router firewall allows UDP 51820
- [ ] Client config has correct public IP
- [ ] Client config has correct server public key
- [ ] WireGuard service running on server
- [ ] Testing from external network (not home WiFi)

## Still Not Working?

1. **Check server logs:**
   ```bash
   sshpass -p 'Control01!' ssh raolivei@192.168.2.83 "sudo journalctl -u wg-quick@wg0 -n 50"
   ```

2. **Check if packets are reaching server:**
   ```bash
   sshpass -p 'Control01!' ssh raolivei@192.168.2.83 "sudo tcpdump -i any -n 'udp port 51820'"
   # Then try connecting VPN - if no packets appear, router is blocking
   ```

3. **Verify server config:**
   ```bash
   sshpass -p 'Control01!' ssh raolivei@192.168.2.83 "sudo cat /etc/wireguard/wg0.conf"
   ```

4. **Check client WireGuard logs:**
   - macOS: Check WireGuard app → View Log
   - Look for connection errors or handshake failures

## Common Router Issues

### Eero Routers
- Port forwarding: Settings → Network Settings → Reservations & Port Forwarding
- May require app instead of web interface

### Google WiFi
- Port forwarding: Google Home app → WiFi → Advanced networking → Port management

### Netgear/TP-Link
- Usually web interface: Advanced → Port Forwarding

### ISP Router
- May have limited port forwarding options
- May require calling ISP to enable
- Consider using bridge mode with your own router

