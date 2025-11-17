# Test DNS on iPhone - Step by Step

## Current Status ✅

- ✅ VPN Connected
- ✅ Can reach `https://192.168.2.83` (404 is expected - Traefik needs Host header)
- ❌ DNS not resolving `canopy.eldertree.local`

## The Issue

iOS WireGuard has DNS set to `192.168.2.83`, but DNS queries might not be reaching Pi-hole, or Pi-hole might not be responding correctly.

## Solution: Test DNS Resolution

### Option 1: Test Pi-hole Admin (Verify DNS Server Works)

**In Safari on iPhone:**
1. Try: `https://192.168.2.83/admin`
2. Should show Pi-hole admin interface
3. If this works → Pi-hole is reachable, DNS should work

### Option 2: Force DNS Refresh (Most Common Fix)

**In WireGuard app:**

1. Tap "Edit" (top right)
2. Scroll to "DNS servers"
3. **Delete** `192.168.2.83`
4. **Re-enter** `192.168.2.83` 
5. Tap "Save"
6. **Disconnect** tunnel (toggle OFF)
7. Wait 10 seconds
8. **Reconnect** tunnel (toggle ON)
9. Wait for "Connected"
10. **Force close Safari** (swipe up, swipe Safari away)
11. **Open Safari fresh**
12. Try: `https://canopy.eldertree.local`

### Option 3: Use IP with Host Header Workaround

Since `https://192.168.2.83` works, you can access services by IP:

**For Canopy:**
- Try: `https://192.168.2.83`
- Traefik should detect the service

**Better method - Use Host header:**
Unfortunately, Safari on iPhone doesn't easily let you set Host headers. You might need to:
1. Access services by IP
2. Or fix DNS (see Option 2)

### Option 4: Check if DNS is Actually Being Used

**Test DNS resolution:**

1. Install a network tool app like "Network Analyzer" or "Fing"
2. Test DNS lookup for `canopy.eldertree.local`
3. Should resolve to `192.168.2.83` or a service IP

If DNS lookup fails → DNS not working
If DNS lookup succeeds → Safari cache issue

## Why "404 page not found" is Expected

When you access `https://192.168.2.83` directly:
- Traefik receives the request
- But without the `Host: canopy.eldertree.local` header
- Traefik doesn't know which service to route to
- So it returns 404

This confirms:
- ✅ VPN routing works
- ✅ Traefik is reachable
- ❌ DNS needs to work so Safari sends the Host header

## Next Steps

1. **Try Option 2 first** (Force DNS refresh) - This fixes it 90% of the time
2. **If that doesn't work**, try Option 1 to verify Pi-hole is reachable
3. **If Pi-hole admin works**, DNS should work - might be Safari cache
4. **As last resort**, access services by IP (limited functionality)

