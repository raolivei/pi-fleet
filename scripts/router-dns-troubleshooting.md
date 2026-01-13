# Router DNS Troubleshooting Guide

## Problem

Router is configured with Pi-hole (192.168.2.201) as Primary DNS, but DNS queries to router (192.168.2.1) are not being forwarded to Pi-hole.

## Current Status

✅ **Pi-hole is reachable**: UDP port 53 is open and responding
✅ **Direct DNS queries work**: `nslookup grafana.eldertree.local 192.168.2.201` works
❌ **Router DNS forwarding**: Router (192.168.2.1) is not forwarding queries to Pi-hole

## Bell Giga Hub Router Configuration

The router DNS setting you configured (`192.168.2.201` as Primary DNS) might be for:
- **Router's own DNS** (what the router uses for its own queries)
- **NOT for forwarding client queries** (what devices get via DHCP)

### Check These Settings

1. **DHCP DNS Settings** (Most Important)
   - Look for "DHCP Settings" or "LAN Settings"
   - Find "DHCP DNS Server" or "DNS Server for Clients"
   - Set to: `192.168.2.201`
   - This is what gets handed out to devices via DHCP

2. **DNS Forwarding/Relay** (If Available)
   - Some routers have a separate "DNS Forwarding" or "DNS Relay" setting
   - Enable this to forward client queries to the configured DNS servers

3. **Router Restart**
   - After changing DNS settings, restart the router
   - This ensures DNS forwarding is properly initialized

## Testing

### Test 1: Direct Query to Router
```bash
dig @192.168.2.1 grafana.eldertree.local
# If this fails, router is not forwarding to Pi-hole
```

### Test 2: Check What DNS Your MacBook Got
```bash
scutil --dns | grep "nameserver\[0\]"
# Should show 192.168.2.201 if DHCP is configured correctly
```

### Test 3: Renew DHCP Lease
```bash
# Release current lease
sudo ipconfig set en0 DHCP

# Or restart network interface
sudo ifconfig en0 down && sudo ifconfig en0 up

# Or flush DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

## Bell Giga Hub Specific Steps

1. **Access Router Admin**: `http://192.168.2.1`

2. **Find DHCP Settings**:
   - Look for "DHCP" or "LAN" or "Network" settings
   - Find "DHCP Server" configuration
   - Look for "DNS Server" field in DHCP settings

3. **Set DHCP DNS to Pi-hole**:
   - Primary DNS: `192.168.2.201`
   - Secondary DNS: `1.1.1.1` (optional, fallback)

4. **Save and Restart Router**:
   - Save the configuration
   - Restart the router (may take 2-3 minutes)

5. **Renew DHCP on Devices**:
   - Restart network interface on MacBook
   - Or restart the device
   - Or manually renew DHCP lease

## Alternative: Configure MacBook Directly

If router DHCP DNS cannot be changed:

1. **System Settings** → **Network**
2. Select your Wi-Fi connection
3. Click **Details** → **DNS**
4. Click **+** and add: `192.168.2.201`
5. Remove `192.168.2.1` if present
6. Click **OK**

**Note**: This will be overridden by VPN if VPN sets its own DNS.

## Verification

After configuration:

```bash
# Check DNS servers
scutil --dns | grep "nameserver\[0\]"
# Should show: nameserver[0] : 192.168.2.201

# Test DNS resolution
nslookup grafana.eldertree.local
# Should resolve to 192.168.2.200

# Test external DNS
nslookup google.com
# Should resolve correctly
```

## Why Router DNS Setting Didn't Work

The "DNS" setting in the router admin panel (what you configured) is typically for:
- **Router's own DNS queries** (what the router uses to resolve domains for itself)
- **NOT for forwarding client queries** (what your devices use)

For client devices to use Pi-hole, you need to configure:
- **DHCP DNS settings** (what gets handed out to devices)
- Or **DNS forwarding/relay** (if the router supports it)

## Next Steps

1. ✅ Check if there's a separate "DHCP DNS" setting in router admin
2. ✅ Configure DHCP to hand out `192.168.2.201` as DNS
3. ✅ Restart router
4. ✅ Renew DHCP lease on MacBook
5. ✅ Test DNS resolution
