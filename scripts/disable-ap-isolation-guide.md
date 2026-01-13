# Disable AP Isolation on Bell GigaHub Router

## Purpose

AP Isolation (Access Point Isolation) or Client Isolation prevents Wi-Fi clients from communicating with each other at Layer 2 (ARP). This blocks MetalLB LoadBalancer IPs from working properly.

**Current Issue:**
- MetalLB assigns `192.168.2.200` to Traefik
- ARP responses don't reach your MacBook
- Services are only accessible via NodePort (32474/31801)

**Solution:** Disable AP Isolation to allow Layer 2 communication between Wi-Fi clients.

---

## Step-by-Step Guide for Bell GigaHub

### Step 1: Access Router Admin Interface

1. Open browser: `http://192.168.2.1`
2. **Login** with your router admin credentials
   - Default username is often `admin`
   - Password is usually on the router label or set during initial setup

### Step 2: Navigate to Wireless Settings

The exact path depends on your GigaHub model/firmware version. Try these locations:

#### Option A: Direct Wireless Settings
1. Look for **"Wi-Fi"** or **"Wireless"** in the main menu
2. Click on your Wi-Fi network (usually 2.4GHz or 5GHz)
3. Look for **"Advanced Settings"** or **"Advanced"** tab

#### Option B: Advanced Tools (Your URL)
1. Navigate to: `http://192.168.2.1/?c=advancedtools`
2. Look for **"Wireless"** or **"Wi-Fi Settings"** section
3. Click on your network name

#### Option C: Network Settings
1. Go to **"Network"** or **"Network Settings"**
2. Click **"Wireless"** or **"Wi-Fi"**
3. Select your network (2.4GHz or 5GHz)
4. Click **"Advanced"** or **"Advanced Settings"**

### Step 3: Find AP Isolation Setting

Look for one of these settings (names vary by firmware):

- ✅ **"AP Isolation"**
- ✅ **"Client Isolation"**
- ✅ **"Wireless Isolation"**
- ✅ **"Station Isolation"**
- ✅ **"AP Client Isolation"**
- ✅ **"Wireless Client Isolation"**
- ✅ **"Isolate Wireless Clients"**

**Location in settings:**
- Usually in **"Advanced"** or **"Security"** section
- May be under **"Wireless Advanced"** or **"Wi-Fi Advanced"**
- Sometimes in **"Guest Network"** settings (if you're using guest network)

### Step 4: Disable AP Isolation

1. **Find the toggle/checkbox** for AP Isolation
2. **Uncheck/Disable** it (set to OFF)
3. **Save** or **Apply** changes
4. Router may restart Wi-Fi (brief disconnection is normal)

### Step 5: Verify the Fix

After disabling AP Isolation, test if MetalLB LoadBalancer IP works:

```bash
# Clear ARP cache
sudo arp -d 192.168.2.200

# Test ping (should work now)
ping -c 2 192.168.2.200

# Test service access (should work now)
curl -k https://192.168.2.200 -H 'Host: vault.eldertree.local'
```

**Expected Result:**
- ✅ Ping to `192.168.2.200` succeeds
- ✅ Services accessible via `https://vault.eldertree.local` (without NodePort)
- ✅ ARP entry shows MAC address (not "incomplete")

---

## Alternative: If Setting Not Found

If you can't find AP Isolation setting:

### Option 1: Check Router Model/Firmware

1. Check router label for **model number** (e.g., "Giga Hub 3000", "Giga Hub 4000")
2. Check firmware version in router admin (usually in "System" or "About")
3. Search online: `"[Your Model] disable AP isolation"`

### Option 2: Contact Bell Support

Some Bell GigaHub models may not expose this setting in the web UI. Contact Bell support and ask:
- "How do I disable AP Isolation or Client Isolation on my GigaHub?"
- "I need to allow Wi-Fi clients to communicate with each other"

### Option 3: Use NodePort Workaround (Current Solution)

If you can't disable AP Isolation, continue using NodePort access:

```bash
# Update /etc/hosts to use node IPs
sudo /Users/roliveira/WORKSPACE/raolivei/pi-fleet/scripts/add-services-to-hosts.sh

# Access services via NodePort
curl -k https://192.168.2.101:32474 -H 'Host: vault.eldertree.local'
```

---

## Verification Script

Run this script to check if AP Isolation is disabled:

```bash
# Test MetalLB LoadBalancer IP
./scripts/test-metallb-connectivity.sh
```

The script will:
1. Clear ARP cache
2. Ping `192.168.2.200`
3. Test service access
4. Report if AP Isolation is still blocking

---

## Troubleshooting

### Still Can't Access After Disabling

1. **Restart router** (power cycle)
2. **Restart Wi-Fi** on your MacBook
3. **Clear ARP cache**: `sudo arp -d 192.168.2.200`
4. **Check firewall** on MacBook (System Settings → Firewall)
5. **Verify MetalLB** is still running: `kubectl get pods -n metallb-system`

### Router Doesn't Have This Setting

Some routers don't expose AP Isolation in the UI. Options:
- Use NodePort workaround (current solution)
- Check if router firmware update adds this setting
- Consider using wired connection (ethernet) for cluster access
- Use a different router that supports this setting

---

## Notes

- **Security**: Disabling AP Isolation allows Wi-Fi clients to communicate. This is usually safe on a home network.
- **Guest Network**: If you're using a guest network, AP Isolation may be enabled by default and cannot be disabled (by design).
- **Both Networks**: If you have 2.4GHz and 5GHz networks, you may need to disable AP Isolation on **both**.

---

## Success Indicators

After disabling AP Isolation, you should see:

```bash
$ ping -c 2 192.168.2.200
PING 192.168.2.200 (192.168.2.200): 56 data bytes
64 bytes from 192.168.2.200: icmp_seq=0 ttl=64 time=5.123 ms
64 bytes from 192.168.2.200: icmp_seq=1 ttl=64 time=4.987 ms

$ arp -a | grep 192.168.2.200
ip-192-168-2-200.us-west-2.compute.internal (192.168.2.200) at 88:a2:9e:0d:ea:21 on en0

$ curl -k https://vault.eldertree.local
<a href="/ui/">Temporary Redirect</a>.
```

All services should now be accessible via their LoadBalancer IPs without needing NodePort!
