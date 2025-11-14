# iPhone WireGuard Troubleshooting - DNS Not Working

## Quick Diagnosis Steps

### Step 1: Verify WireGuard is Connected

In WireGuard app on iPhone:
- ✅ Status shows "Connected" (green toggle)
- ✅ Shows IP address: `10.8.0.3`
- ✅ Shows data transferred (bytes sent/received increasing)

**If not connected:** See connection troubleshooting below.

### Step 2: Test Basic Connectivity (IP Address)

**In Safari on iPhone:**
1. Try accessing: `https://192.168.2.83`
2. Should see Traefik or get a response (certificate warning is OK)

**If IP works but domain doesn't:** DNS issue - continue to Step 3

**If IP doesn't work:** VPN routing issue - check AllowedIPs and server config

### Step 3: Verify DNS is Set Correctly

**In WireGuard app:**
1. Tap on your tunnel (eldertree)
2. Tap "Edit" (pencil icon)
3. Scroll to `[Interface]` section
4. Verify line shows: `DNS = 192.168.2.83`
5. If missing or different, add/update it
6. Save and reconnect

### Step 4: Test DNS Resolution

**Option A: Use Safari**
- Try: `https://canopy.eldertree.local`
- If it loads: ✅ DNS working!
- If "Safari can't open the page": DNS issue

**Option B: Use a DNS testing app**
- Install "Network Analyzer" or similar
- Test DNS lookup for `canopy.eldertree.local`
- Should resolve to `192.168.2.83`

## Common Issues and Fixes

### Issue 1: DNS Not Applied

**Symptoms:**
- WireGuard shows "Connected"
- Can access `https://192.168.2.83` (IP works)
- Cannot access `canopy.eldertree.local` (domain doesn't work)

**Fix:**
1. Open WireGuard app
2. Tap your tunnel → Edit
3. Make sure `DNS = 192.168.2.83` is in `[Interface]` section
4. Save
5. **Disconnect and reconnect** the tunnel (toggle off, wait 2 seconds, toggle on)
6. Try again

### Issue 2: DNS Server Not Reachable

**Symptoms:**
- WireGuard connected
- DNS is set correctly
- Domain still doesn't resolve

**Possible causes:**
- Pi-hole (192.168.2.83) not reachable from VPN
- Firewall blocking DNS port 53

**Fix:**
1. Test if Pi-hole is reachable:
   - Try: `https://192.168.2.83/admin` (Pi-hole admin)
   - If this works, Pi-hole is reachable
2. Check server firewall allows DNS:
   ```bash
   ssh raolivei@eldertree "sudo ufw status | grep 53"
   ```
3. If DNS port blocked, allow it:
   ```bash
   ssh raolivei@eldertree "sudo ufw allow 53/udp"
   ```

### Issue 3: iOS DNS Cache

**Symptoms:**
- DNS was working, then stopped
- Config looks correct

**Fix:**
1. Disconnect WireGuard
2. Close Safari completely (swipe up, swipe Safari away)
3. Reconnect WireGuard
4. Open Safari fresh
5. Try again

### Issue 4: Multiple DNS Servers Conflict

**Symptoms:**
- DNS sometimes works, sometimes doesn't
- Inconsistent behavior

**Fix:**
1. Edit WireGuard config
2. Use only one DNS server: `DNS = 192.168.2.83`
3. Don't add multiple DNS servers
4. Save and reconnect

## Step-by-Step Fix

### Complete Reset Procedure

1. **In WireGuard app:**
   - Disconnect tunnel (toggle OFF)
   - Delete the tunnel
   - Re-import `client-mobile.conf` (scan QR or import file)

2. **Verify config after import:**
   - Tap tunnel → Edit
   - Check `DNS = 192.168.2.83` is present
   - Check `Endpoint = 184.147.64.214:51820` is correct
   - Check `AllowedIPs = 10.8.0.0/24, 192.168.2.0/24`

3. **Connect:**
   - Toggle tunnel ON
   - Wait for "Connected" status
   - Check IP shows `10.8.0.3`

4. **Test:**
   - First try IP: `https://192.168.2.83` (should work)
   - Then try domain: `https://canopy.eldertree.local` (should work if DNS is correct)

## Alternative: Access by IP

If DNS continues to not work, you can access services by IP:

- **Canopy:** `https://192.168.2.83` (Traefik will route based on Host header)
- **Pi-hole:** `https://192.168.2.83/admin`
- **Grafana:** `https://192.168.2.83` (with Host header)

**Note:** Some services require the Host header, so IP-only access may be limited.

## Verify Server-Side DNS

Check if Pi-hole DNS is working on server:

```bash
# SSH to server
ssh raolivei@eldertree

# Test DNS resolution
nslookup canopy.eldertree.local 192.168.2.83

# Should return: 192.168.2.83 or service IP
```

If DNS doesn't work on server, fix Pi-hole configuration first.

## Still Not Working?

1. **Check WireGuard logs on iPhone:**
   - WireGuard app → Tap tunnel → "View Log"
   - Look for DNS-related errors

2. **Check server logs:**
   ```bash
   ssh raolivei@eldertree "sudo journalctl -u wg-quick@wg0 -n 50"
   ```

3. **Verify client is registered on server:**
   ```bash
   ssh raolivei@eldertree "sudo wg show wg0"
   ```
   Should show peer with IP `10.8.0.3` and recent handshake

4. **Test from Mac (for comparison):**
   - If Mac works but iPhone doesn't, it's iPhone-specific
   - If both don't work, it's server-side issue

