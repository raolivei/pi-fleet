# iOS WireGuard DNS Issue - Internal IP Not Working

## The Problem

iOS WireGuard might not route DNS queries to internal IPs (like `192.168.2.83`) through the VPN tunnel properly, even though `AllowedIPs` includes `192.168.2.0/24`.

## Why This Happens

iOS WireGuard may try to resolve DNS using the normal network interface before routing it through the VPN tunnel, causing DNS queries to fail when the DNS server is only reachable through the VPN.

## Solutions

### Solution 1: Ensure DNS Queries Go Through VPN (Recommended)

The `AllowedIPs` already includes `192.168.2.0/24`, so DNS queries should be routed through VPN. However, iOS might need explicit routing.

**Try this:**

1. **In WireGuard app, edit the tunnel:**

   - Make sure `AllowedIPs` includes `192.168.2.0/24` ✅ (it does)
   - DNS is set to `192.168.2.83` ✅

2. **Force DNS refresh:**

   - Delete DNS: `192.168.2.83`
   - Re-enter: `192.168.2.83`
   - Save
   - Disconnect and reconnect

3. **Test DNS resolution:**
   - Use a network tool app to test DNS lookup
   - Or try accessing `https://192.168.2.83/admin` (Pi-hole admin)

### Solution 2: Set Up DNS Forwarding on VPN Server

If Solution 1 doesn't work, set up DNS forwarding on the VPN server (10.8.0.1) to forward queries to Pi-hole.

**On the VPN server (Raspberry Pi):**

```bash
# Install dnsmasq or use systemd-resolved
sudo apt-get install dnsmasq

# Configure dnsmasq to forward to Pi-hole
sudo nano /etc/dnsmasq.conf
# Add:
server=192.168.2.83
listen-address=10.8.0.1

# Restart dnsmasq
sudo systemctl restart dnsmasq
```

Then update mobile config:

```
DNS = 10.8.0.1
```

### Solution 3: Use VPN IP Range for DNS (If Pi-hole is on VPN)

If Pi-hole was on the VPN network (10.8.0.x), DNS would work automatically. But Pi-hole is on the local network (192.168.2.83), so this doesn't apply.

### Solution 4: Access by IP (Workaround)

If DNS continues to not work:

1. Access services by IP: `https://192.168.2.83`
2. Traefik will route based on Host header if available
3. Some services might not work without proper Host header

## Current Config Analysis

**Mobile Config:**

- `DNS = 192.168.2.83` ✅ (Pi-hole IP)
- `AllowedIPs = 10.8.0.0/24, 192.168.2.0/24` ✅ (includes DNS server network)

**The config is correct** - iOS WireGuard should route DNS queries through VPN since `192.168.2.83` is in `AllowedIPs`.

## Testing

**Test if DNS queries are going through VPN:**

1. Install a network tool app (Network Analyzer, Fing, etc.)
2. Test DNS lookup for `canopy.eldertree.local`
3. Check if it resolves to `192.168.2.83` or service IP

**If DNS lookup fails:**

- iOS is not routing DNS through VPN
- Try Solution 2 (DNS forwarding on VPN server)

**If DNS lookup succeeds but Safari doesn't work:**

- Safari DNS cache issue
- Force close Safari and try again

## Recommended Next Steps

1. **First, try Solution 1** (force DNS refresh)
2. **If that doesn't work**, verify DNS queries are routed:

   - Use network tool app to test DNS
   - If DNS queries fail → iOS routing issue → Use Solution 2
   - If DNS queries succeed → Safari cache issue → Clear Safari cache

3. **As last resort**, set up DNS forwarding on VPN server (Solution 2)

