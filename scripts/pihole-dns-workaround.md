# Pi-hole DNS Workaround - Use Router with Fallback

## Problem

Setting `192.168.2.201` (Pi-hole) as the only DNS on MacBook causes DNS queries to timeout because MetalLB is not properly advertising the LoadBalancer IP.

## Immediate Solution: Use Router DNS with Fallback

Since Pi-hole LoadBalancer IP is not reachable from your MacBook, use this configuration:

### macOS DNS Configuration

1. **System Settings** → **Network**
2. Select your Wi-Fi connection
3. Click **Details** → **DNS**
4. Configure DNS servers in this order:
   - **Primary DNS**: `192.168.2.1` (Router - for external domains)
   - **Secondary DNS**: `1.1.1.1` (Cloudflare - fallback for external domains)
   - **Tertiary DNS**: `192.168.2.201` (Pi-hole - will be used when reachable)

### Why This Works

- **Router (192.168.2.1)**: Resolves external domains (google.com, etc.)
- **Cloudflare (1.1.1.1)**: Fallback if router fails
- **Pi-hole (192.168.2.201)**: Will be used automatically when MetalLB starts advertising properly

### For Local Domains (grafana.eldertree.local)

Since router doesn't forward to Pi-hole, you have two options:

#### Option A: Query Pi-hole Directly (When It Works)

When Pi-hole becomes reachable, you can query it directly:
```bash
nslookup grafana.eldertree.local 192.168.2.201
```

#### Option B: Add to /etc/hosts (Temporary)

Add local domains to `/etc/hosts`:
```bash
sudo nano /etc/hosts
# Add:
192.168.2.200 grafana.eldertree.local
192.168.2.200 prometheus.eldertree.local
192.168.2.200 vault.eldertree.local
192.168.2.200 pihole.eldertree.local
192.168.2.200 swimto.eldertree.local
192.168.2.200 pitanga.eldertree.local
192.168.2.200 flux-ui.eldertree.local
```

## Long-term Fix: Resolve MetalLB Issue

The root cause is MetalLB not advertising the LoadBalancer IP. Once fixed:

1. MetalLB will properly advertise `192.168.2.201`
2. ARP entry will be complete
3. DNS queries will work
4. You can use `192.168.2.201` as primary DNS

## Verification

After configuring DNS:

```bash
# Check DNS servers
scutil --dns | grep "nameserver\[0\]"
# Should show: nameserver[0] : 192.168.2.1

# Test external DNS
nslookup google.com
# Should resolve via router

# Test local domain (when Pi-hole is reachable)
nslookup grafana.eldertree.local 192.168.2.201
# Should resolve to 192.168.2.200
```

## Summary

**Current Status**: 
- ✅ Pi-hole is working inside cluster
- ❌ MetalLB not advertising IP to network
- ⚠️ Use router DNS with fallback until MetalLB is fixed

**Recommended DNS Order**:
1. `192.168.2.1` (Router)
2. `1.1.1.1` (Cloudflare fallback)
3. `192.168.2.201` (Pi-hole - will work when MetalLB is fixed)
