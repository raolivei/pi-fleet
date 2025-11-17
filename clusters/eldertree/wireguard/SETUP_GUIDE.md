# 📱💻 WireGuard Setup Guide - Mac & iPhone

Complete guide to connect your Mac and iPhone to your eldertree k3s cluster via WireGuard VPN.

## 🌐 Network Details

- **Server Public IP**: `184.147.64.214`
- **WireGuard Port**: `51820 (UDP)`
- **Server VPN IP**: `10.8.0.1`
- **MacBook VPN IP**: `10.8.0.2`
- **iPhone VPN IP**: `10.8.0.3`

---

## 💻 Mac Setup

### Step 1: Install WireGuard

```bash
# Install WireGuard tools (command line)
brew install wireguard-tools

# Install WireGuard app (GUI - recommended)
brew install --cask wireguard
```

### Step 2: Import Configuration

**Option A: Using GUI (Easiest)**

1. Open **WireGuard** app from Applications or Spotlight
2. Click **"Import tunnel(s) from file..."**
3. Navigate to and select:
   ```
   ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/macbook.conf
   ```
4. The tunnel "macbook" will appear in the sidebar
5. Click **"Activate"** to connect

**Option B: Using Terminal**

```bash
# Copy config to WireGuard directory
sudo mkdir -p /usr/local/etc/wireguard
sudo cp ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/macbook.conf \
  /usr/local/etc/wireguard/

# Start the tunnel
sudo wg-quick up macbook

# Check status
sudo wg show
```

### Step 3: Verify Mac Connection

```bash
# Test VPN tunnel
ping 10.8.0.1

# Test cluster access
ping 10.43.0.1

# Verify split-tunnel (should NOT show wg/utun for 0.0.0.0)
netstat -rn | grep default

# Verify cluster routes
netstat -rn | grep 10.42
netstat -rn | grep 10.43

# Test internet (should work normally)
curl ifconfig.me
# Should show YOUR IP, not 184.147.64.214
```

---

## 📱 iPhone Setup

### Step 1: Install WireGuard App

1. Open **App Store** on your iPhone
2. Search for **"WireGuard"**
3. Install the official WireGuard app (by WireGuard Development Team)

### Step 2: Import Configuration

**Option A: Scan QR Code (Easiest)**

1. Open the WireGuard app on your iPhone
2. Tap the **"+"** button (top right)
3. Select **"Create from QR code"**
4. On your Mac, open the QR code image:
   ```bash
   open ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/iphone.png
   ```
5. Scan the QR code with your iPhone
6. Name the tunnel (e.g., "eldertree" or "Home Cluster")
7. Tap **"Save"**

**Option B: AirDrop Config File**

1. On your Mac:
   ```bash
   # Open Finder to the clients folder
   open ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/
   ```
2. Right-click `iphone.conf` → **Share** → **AirDrop** to your iPhone
3. On your iPhone, tap the notification
4. Choose **"WireGuard"** to open with
5. Tap **"Add Tunnel"**

**Option C: Manual Entry (Not Recommended)**

If QR code and AirDrop don't work:

1. Open WireGuard app
2. Tap **"+"** → **"Create from scratch"**
3. Name: `eldertree`
4. Copy the configuration from `~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/iphone.conf`

### Step 3: Verify iPhone Connection

1. In WireGuard app, toggle the tunnel **ON**
2. Status should show "Active"
3. You should see data transfer statistics

**Test from iPhone (while on cellular/LTE):**

1. Open Safari or any browser
2. Go to: `http://10.8.0.1` (should timeout but confirm routing)
3. Test internet: `https://google.com` (should work normally - split tunnel!)
4. Check your IP: `https://ifconfig.me`
   - Should show your cellular/LTE IP, NOT `184.147.64.214`

---

## ⚠️ CRITICAL: Router Port Forwarding

**You MUST configure port forwarding for external (LTE) access!**

### Router Configuration

1. Access your router admin panel:
   - Usually: `http://192.168.2.1` or `http://192.168.1.1`
   - Check router label for default gateway

2. Find **Port Forwarding** section:
   - May be called: "Virtual Servers", "NAT Forwarding", "Gaming", or "Applications"

3. Add this rule:
   - **Service Name**: `WireGuard`
   - **Protocol**: `UDP` (NOT TCP!)
   - **External Port**: `51820`
   - **Internal IP**: `192.168.2.83` (your Raspberry Pi)
   - **Internal Port**: `51820`
   - **Enable**: Yes/On

4. Save and reboot router if needed

### Verify Port Forwarding

From your Mac (while on LTE/cellular):

```bash
# Test if port is open
nc -vzu 184.147.64.214 51820
# Should say "Connection to 184.147.64.214 port 51820 [udp/*] succeeded!"
```

---

## 🧪 Testing & Verification

### Test on Home Network (Both Devices)

Before testing on LTE, verify everything works at home:

```bash
# Mac Terminal:
ping 10.8.0.1              # Ping VPN server
ping 10.43.0.1             # Ping k8s API
kubectl get nodes          # Should work!
```

iPhone: Open Safari and try accessing a k8s service.

### Test on LTE/Cellular

**Mac (tethered to iPhone hotspot):**

1. Connect Mac to iPhone's Personal Hotspot
2. Activate WireGuard on Mac
3. Run the verification commands above
4. Access cluster services

**iPhone (on cellular data):**

1. Disconnect from WiFi (use cellular only)
2. Activate WireGuard in the app
3. Test internet access (should work)
4. Test cluster access (if you have a web service)

---

## 🌍 What Traffic Goes Through VPN?

### ✅ Through VPN (Encrypted):

- `10.8.0.0/24` - WireGuard tunnel
- `10.42.0.0/16` - k3s Pod IPs
- `10.43.0.0/16` - k3s Service IPs
- `192.168.2.0/24` - Your home LAN

### ❌ Bypasses VPN (Normal Internet):

- Everything else!
- Netflix, YouTube, browsing, etc.
- **Your internet speed is NOT affected!**

This is called **split-tunneling** and it's the best of both worlds!

---

## 🔧 Troubleshooting

### Mac: Can't Connect

```bash
# Check if WireGuard is installed
which wg
which wg-quick

# Check config file
cat ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/macbook.conf

# Try manual connection
sudo wg-quick up macbook

# Check logs
sudo wg show macbook
```

### iPhone: Can't Import QR Code

- Make sure you're using the **official WireGuard app**
- Try AirDrop method instead
- Ensure QR code is clearly visible on screen
- Increase screen brightness

### Connected But Can't Access Cluster

```bash
# Check handshake (Mac)
sudo wg show macbook latest-handshakes
# Should show recent timestamp

# If no handshake:
# 1. Check port forwarding on router
# 2. Verify firewall isn't blocking UDP 51820
# 3. Restart WireGuard
```

### Internet Broken After Connecting

This means split-tunnel failed. Check your config:

```bash
# Should be:
AllowedIPs = 10.8.0.0/24, 10.42.0.0/16, 10.43.0.0/16, 192.168.2.0/24

# Should NOT be:
AllowedIPs = 0.0.0.0/0  # This routes ALL traffic!
```

### Router Port Forwarding Not Working

```bash
# Test from external network (Mac on LTE)
nc -vzu 184.147.64.214 51820

# If fails:
# 1. Double-check router config
# 2. Ensure protocol is UDP (not TCP)
# 3. Verify internal IP is 192.168.2.83
# 4. Check if ISP blocks VPN ports (rare)
# 5. Try different port (e.g., 51821) and update configs
```

### DNS Not Resolving

DNS (dnsmasq) is currently disabled. Use IP addresses instead:

```bash
# Instead of:
http://myservice.default.svc.cluster.local

# Use:
http://10.43.X.X:port
```

---

## 📊 Monitoring & Management

### Check Server Status

```bash
# WireGuard pod status
kubectl get pods -n wireguard

# WireGuard configuration
kubectl exec -n wireguard deployment/wireguard -- cat /config/wg_confs/wg0.conf

# Check peers and connections
kubectl exec -n wireguard deployment/wireguard -- wg show

# View logs
kubectl logs -n wireguard deployment/wireguard -f
```

### Disconnect VPN

**Mac GUI**: Click "Deactivate" in WireGuard app

**Mac Terminal**:
```bash
sudo wg-quick down macbook
```

**iPhone**: Toggle OFF in WireGuard app

### Reconnect VPN

**Mac GUI**: Click "Activate" in WireGuard app

**Mac Terminal**:
```bash
sudo wg-quick up macbook
```

**iPhone**: Toggle ON in WireGuard app

---

## 🔐 Security Best Practices

1. **Keep configs secure**
   - `macbook.conf` and `iphone.conf` contain private keys
   - Don't share or commit to git
   - Back up securely (encrypted)

2. **Router security**
   - Use strong admin password
   - Only forward port 51820 (UDP)
   - Enable router firewall

3. **Regular updates**
   - Keep WireGuard app updated
   - Rotate keys every 6-12 months

4. **Monitor access**
   - Check WireGuard logs periodically
   - Review connected peers

---

## 🎯 Use Cases

### Working Remotely

While traveling or at a coffee shop (on cellular or public WiFi):

1. Connect to VPN
2. Access your cluster: `kubectl get pods`
3. Access internal services
4. Internet browsing stays fast (bypasses VPN)

### iPhone as Admin Tool

On the go:

1. Connect to VPN from iPhone
2. Use apps like Termius or Working Copy
3. SSH to Pi via VPN: `ssh pi@192.168.2.83`
4. Manage cluster from anywhere

### Development While Traveling

On Mac tethered to iPhone:

1. Connect Mac to iPhone hotspot
2. Activate WireGuard
3. Access all cluster services
4. Push/pull from internal git, access databases, etc.

---

## 📚 Quick Reference

### Important Files

```
~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/
├── clients/
│   ├── macbook.conf        # Mac config file
│   ├── iphone.conf         # iPhone config file
│   └── iphone.png          # iPhone QR code
├── SETUP_GUIDE.md          # This file
└── MACBOOK_SETUP.md        # Mac-specific details
```

### Important Commands

```bash
# Mac: Connect
sudo wg-quick up macbook

# Mac: Disconnect
sudo wg-quick down macbook

# Mac: Status
sudo wg show

# Server: Check peers
kubectl exec -n wireguard deployment/wireguard -- wg show

# Test connection
ping 10.8.0.1

# Test cluster
kubectl get nodes
```

### Important IPs

- Server Public: `184.147.64.214`
- Server VPN: `10.8.0.1`
- Mac VPN: `10.8.0.2`
- iPhone VPN: `10.8.0.3`
- Pi LAN: `192.168.2.83`
- k8s API: `10.43.0.1`

---

## 🆘 Getting Help

1. **Check pod logs**: `kubectl logs -n wireguard deployment/wireguard`
2. **Verify port forwarding**: Test from external network
3. **Test on home network first**: Eliminate router issues
4. **Check WireGuard handshake**: Should show recent activity
5. **Verify configs**: Private key, public key, endpoint, AllowedIPs

---

## ✅ Setup Complete!

You're now ready to access your k3s cluster from anywhere! 🎉

**Next Steps:**

1. Install WireGuard on Mac
2. Install WireGuard on iPhone  
3. Configure router port forwarding
4. Test on home network
5. Test on cellular/LTE
6. Enjoy secure cluster access from anywhere!

---

**Remember**: Port forwarding is REQUIRED for external access!

