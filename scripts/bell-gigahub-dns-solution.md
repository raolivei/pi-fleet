# Bell Giga Hub DNS Configuration Solution

## Problem

The Bell Giga Hub router's DHCP settings page **does not have a DNS server field**. This means:
- The router hands out its own IP (192.168.2.1) as DNS to clients via DHCP
- The router is configured to use Pi-hole (192.168.2.201) as its DNS
- **BUT** the router is NOT forwarding client DNS queries to Pi-hole

## Current Situation

✅ Router DNS setting: `192.168.2.1` → `192.168.2.201` (Pi-hole)
❌ Router is NOT forwarding client queries to Pi-hole
❌ Devices get `192.168.2.1` as DNS via DHCP
❌ Router resolves external domains but not local domains

## Solutions

### Option 1: Enable DNS Forwarding/Relay (If Available)

Some routers have a hidden or advanced setting for DNS forwarding. Check:

1. **Modem → DNS** settings page
   - Look for "DNS Forwarding" or "DNS Relay" option
   - Enable it if available

2. **Advanced/Expert Mode**
   - Some routers have an "Expert Mode" or "Advanced Mode"
   - Look for DNS forwarding settings there

3. **Check Router Firmware/Model**
   - Some Bell Giga Hub models support DNS forwarding
   - May require firmware update

### Option 2: Configure Devices Manually (Recommended for Now)

Since the router doesn't support DHCP DNS configuration, configure DNS manually on each device:

#### macOS (Your MacBook)

1. **System Settings** → **Network**
2. Select your Wi-Fi connection
3. Click **Details** → **DNS**
4. Click **+** and add: `192.168.2.201`
5. Remove `192.168.2.1` if present
6. Click **OK**

**Note**: This will be overridden by VPN if VPN sets its own DNS. You may need to configure DNS in VPN settings separately.

#### Other Devices

- **iOS/Android**: Settings → Wi-Fi → (i) → Configure DNS → Manual → Add `192.168.2.201`
- **Linux**: Edit `/etc/resolv.conf` or use NetworkManager
- **Windows**: Network Settings → Change adapter options → Properties → IPv4 → Use custom DNS

### Option 3: Use Router as DNS Forwarder (If Supported)

If the router supports DNS forwarding, you need to:

1. **Enable DNS Forwarding/Relay** in router settings
2. **Configure router to forward** queries to `192.168.2.201`
3. This way, clients can still use `192.168.2.1` as DNS, and router forwards to Pi-hole

### Option 4: Replace Router DHCP with Pi-hole DHCP (Advanced)

This requires:
- Disabling router DHCP
- Enabling DHCP server in Pi-hole
- Configuring Pi-hole DHCP to hand out `192.168.2.201` as DNS

**⚠️ Warning**: This is complex and can break network connectivity if misconfigured.

## Recommended Approach

**For now**: Configure DNS manually on your MacBook (Option 2)

**Long-term**: 
1. Check if router firmware update adds DHCP DNS support
2. Or consider using a router that supports DHCP DNS configuration
3. Or set up Pi-hole as DHCP server (advanced)

## Verification

After configuring DNS manually on MacBook:

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

## Why This Happens

Consumer routers like Bell Giga Hub often:
- Don't expose DHCP DNS settings in web UI
- Use router IP as DNS for clients by default
- May not forward DNS queries (depends on firmware/model)
- Are designed for simplicity, not advanced networking

## Next Steps

1. ✅ Configure DNS manually on MacBook to use `192.168.2.201`
2. ✅ Test DNS resolution
3. ⏳ Check router firmware for DNS forwarding option
4. ⏳ Consider long-term solution (router upgrade or Pi-hole DHCP)
