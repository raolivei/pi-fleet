# Pi-hole Ad Blocking - Working Status

**Date**: 2026-05-11  
**Status**: ✅ Pi-hole DNS Operational

## Summary

Pi-hole is successfully deployed and blocking ads at `192.168.2.201`. Your MacBook has Pi-hole configured as primary DNS, but AWS VPN may override it for VPN-connected traffic.

## Test Results

### Pi-hole DNS Working
```bash
$ dig @192.168.2.201 google.com +short
192.178.192.113  # ✅ DNS resolution works

$ dig @192.168.2.201 doubleclick.net +short
0.0.0.0  # ✅ Ad blocked

$ dig @192.168.2.201 ads.google.com +short
0.0.0.0  # ✅ Ad blocked
```

### MacBook DNS Configuration
```bash
$ networksetup -getdnsservers Wi-Fi
192.168.2.201  # ✅ Pi-hole configured
8.8.8.8        # Fallback
1.1.1.1        # Fallback
```

### System DNS (with VPN active)
```bash
$ scutil --dns | grep nameserver
nameserver[0] : 10.57.0.2  # VPN DNS takes precedence

$ dig doubleclick.net +short
209.85.203.113  # ❌ Not blocked (using VPN DNS)
```

## VPN DNS Behavior

AWS VPN is designed to override local DNS for security. This means:

**When VPN is CONNECTED:**
- System uses VPN DNS (10.57.0.2)
- Pi-hole is bypassed for VPN traffic
- Ads are NOT blocked

**When VPN is DISCONNECTED:**
- System uses Pi-hole (192.168.2.201)
- Ads ARE blocked
- All DNS queries go through Pi-hole

## Solutions

### Option 1: Accept VPN Behavior (Recommended)
- Use Pi-hole when not on VPN (home browsing)
- Accept no ad blocking during VPN work sessions
- This is the safest approach for work VPN

### Option 2: Split-Tunnel VPN DNS
Some VPN clients allow configuring which domains use VPN DNS. Check if AWS VPN client supports:
- DNS domain routing
- Custom DNS server override
- Split-tunnel DNS configuration

### Option 3: Browser Extension
Use uBlock Origin in your browser for ad blocking that works regardless of DNS:
- Works with VPN active
- More aggressive filtering
- Only blocks ads in browser (not system-wide)

### Option 4: Override VPN DNS (Not Recommended)
You can force macOS to ignore VPN DNS, but this may:
- Break access to internal corporate resources
- Violate company security policies
- Cause routing issues

## Cluster Status

### Nodes
```
node-1: ✅ Ready (K3s ServiceLB disabled, Pi-hole running here)
node-2: ✅ Ready (K3s ServiceLB still enabled but not causing issues)
node-3: ❌ NotReady (offline, network unreachable after reboot)
```

### Services
```
Pi-hole DNS: ✅ 192.168.2.201 (LoadBalancer)
Pi-hole Web:  https://pihole.eldertree.local/admin/
Control VIP:  ✅ 192.168.2.100 (stable)
```

## Testing Ad Blocking

### Quick Test
```bash
# Should return 0.0.0.0 if blocked:
dig @192.168.2.201 doubleclick.net +short
dig @192.168.2.201 ads.google.com +short
dig @192.168.2.201 googleads.g.doubleclick.net +short
```

### Browser Test
1. Disconnect from VPN
2. Visit: https://d3ward.github.io/toolz/adblock.html
3. Should show most ads blocked

### Check Active DNS
```bash
# See which DNS server is actually being used:
scutil --dns | grep nameserver | head -5
```

## Pi-hole Web Interface

Access the admin interface:
```
URL: https://pihole.eldertree.local/admin/
```

Password stored in Vault:
```bash
kubectl get secret pihole-secrets -n pihole -o jsonpath='{.data.webpassword}' | base64 -d
```

## node-3 Recovery

node-3 is still offline after reboot. Next steps:

1. **Check physical status**:
   - Power LED on?
   - Network LED blinking?
   - Can you see it on router?

2. **Connect via serial/monitor**:
   - Check boot logs
   - Verify network configuration
   - Check k3s service status

3. **If accessible via console**:
   ```bash
   # Check network
   ip addr show
   systemctl status k3s
   
   # Restart k3s
   systemctl restart k3s
   ```

4. **Disable ServiceLB on node-3** (when accessible):
   ```bash
   /tmp/disable-servicelb.py
   ```

## Maintenance

### Check Pi-hole Stats
```bash
kubectl exec -n pihole deployment/pi-hole -c pihole -- pihole -c -j
```

### Update Blocklists
```bash
kubectl exec -n pihole deployment/pi-hole -c pihole -- pihole -g
```

### View Logs
```bash
kubectl logs -n pihole deployment/pi-hole -c pihole --tail=100
```

## Success Metrics

✅ Pi-hole LoadBalancer IP assigned: `192.168.2.201`  
✅ DNS resolution working  
✅ Ad blocking functional  
✅ MacBook DNS configured  
✅ Cluster stable on 2 nodes  
⚠️ VPN overrides DNS (expected behavior)  
❌ node-3 offline (investigating)

## Next Steps

1. **Test ad blocking** without VPN to confirm it works
2. **Investigate node-3** network/hardware issue
3. **Disable K3s ServiceLB on node-2** (optional, when SSH works)
4. **Monitor Pi-hole** for performance and blocking effectiveness

---

**The main goal is achieved**: Pi-hole is operational and will block ads when VPN is disconnected!
