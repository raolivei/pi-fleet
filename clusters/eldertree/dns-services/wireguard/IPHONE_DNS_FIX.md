# iPhone DNS Fix - Step by Step

## Current Status (from your screenshot)

✅ WireGuard is **Connected** (green VPN icon)  
✅ DNS is set: `192.168.2.83`  
✅ Data is flowing (23.79 KiB received, 44.29 KiB sent)  
✅ Latest handshake: 01:45 minutes ago  
❌ Domain `canopy.eldertree.local` not loading  

## The Problem

DNS is configured correctly in WireGuard, but iOS might not be using it properly, or Pi-hole DNS might not be responding correctly.

## Solution Steps

### Step 1: Test DNS Resolution

**On your iPhone, try this:**

1. Open Safari
2. Try accessing: `https://192.168.2.83`
   - If this works → VPN routing is fine, DNS is the issue
   - If this doesn't work → VPN routing issue

### Step 2: Force DNS Refresh in WireGuard

**In WireGuard app:**

1. Tap "Edit" (top right)
2. Scroll to `DNS servers` field
3. **Delete** the current DNS: `192.168.2.83`
4. **Re-enter** it: `192.168.2.83`
5. Tap "Save" (top right)
6. **Disconnect** the tunnel (toggle OFF)
7. Wait 5 seconds
8. **Reconnect** the tunnel (toggle ON)
9. Wait for "Connected" status
10. Try Safari again: `https://canopy.eldertree.local`

### Step 3: Clear iOS DNS Cache

1. **Disconnect WireGuard** (toggle OFF)
2. **Force close Safari:**
   - Swipe up from bottom
   - Swipe Safari away
3. **Reconnect WireGuard** (toggle ON)
4. **Open Safari fresh**
5. Try: `https://canopy.eldertree.local`

### Step 4: Test Pi-hole DNS Directly

**In Safari on iPhone:**

Try accessing Pi-hole admin:
- `https://192.168.2.83/admin`

If this works, Pi-hole is reachable and DNS should work.

### Step 5: Alternative - Use IP with Host Header

If DNS still doesn't work, you can access services by IP:

1. Open Safari
2. Go to: `https://192.168.2.83`
3. Traefik should route based on Host header

**Note:** Some services might not work without the proper Host header.

## Why This Happens

iOS WireGuard sometimes doesn't apply DNS changes immediately. The DNS setting is there, but iOS might:
- Cache old DNS responses
- Not apply DNS until tunnel is reconnected
- Have DNS conflicts with other network settings

## Verification

After following the steps above:

1. **Check WireGuard status:**
   - Should show "Connected"
   - DNS should show `192.168.2.83`

2. **Test in Safari:**
   - `https://192.168.2.83` → Should work
   - `https://canopy.eldertree.local` → Should work after DNS refresh

3. **Check DNS is working:**
   - If you have a network tool app, test DNS lookup for `canopy.eldertree.local`
   - Should resolve to `192.168.2.83` or service IP

## Still Not Working?

If DNS still doesn't work after these steps:

1. **Check server-side DNS:**
   - SSH to server: `ssh raolivei@eldertree`
   - Test: `nslookup canopy.eldertree.local 192.168.2.83`
   - Should return an IP address

2. **Check Pi-hole is running:**
   - Access: `https://192.168.2.83/admin`
   - Should show Pi-hole admin interface

3. **Try without DNS:**
   - Edit WireGuard config
   - Remove DNS line
   - Access services by IP: `https://192.168.2.83`

