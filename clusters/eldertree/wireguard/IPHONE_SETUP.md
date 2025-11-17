# 📱 iPhone WireGuard Setup - Quick Guide

Your iPhone VPN is **already connected and working!** 🎉

## ✅ Current Status

- **Connected**: Handshake 55 seconds ago
- **Data Transfer**: 37 KiB received, 7 KiB sent
- **Endpoint**: Connected from cellular (184.151.190.243)
- **VPN IP**: 10.8.0.3

## 📋 Setup Steps (If You Need to Reconfigure)

### Step 1: Install WireGuard App

1. Open **App Store** on iPhone
2. Search for **"WireGuard"**
3. Install the official app (by WireGuard Development Team)

### Step 2: Import Configuration

**Option A: Scan QR Code (Easiest)**

1. Open **WireGuard** app
2. Tap **"+"** (top right)
3. Select **"Create from QR code"**
4. Scan the QR code:
   ```
   ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/iphone-fixed.png
   ```
5. Name it: **"eldertree"** or **"Home Cluster"**
6. Tap **"Save"**

**Option B: AirDrop Config File**

1. On your Mac:
   ```bash
   open ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/
   ```
2. Right-click `iphone.conf` → **Share** → **AirDrop** → Select your iPhone
3. On iPhone, tap the notification
4. Choose **"WireGuard"** to open
5. Tap **"Add Tunnel"**

### Step 3: Activate VPN

1. In WireGuard app, find your tunnel
2. Toggle the switch **ON**
3. Status should show **"Active"** with green dot

## 🧪 Testing

### Test VPN Connection

1. Make sure you're on **cellular data** (not WiFi)
2. Activate WireGuard tunnel
3. Open Safari
4. Test internet: `https://google.com` (should work - split-tunnel!)
5. Check your IP: `https://ifconfig.me` (should show YOUR cellular IP, not VPN server)

### Test Cluster Access

If you have apps that can access your cluster:

- SSH apps (Termius, Prompt)
- Kubernetes apps (kubectl mobile)
- Or just verify VPN is active in WireGuard app

## 📊 What Traffic Goes Through VPN?

### ✅ Through VPN (Encrypted):

- `10.8.0.0/24` - WireGuard tunnel
- `10.42.0.0/16` - k3s Pod IPs
- `10.43.0.0/16` - k3s Service IPs
- `192.168.2.0/24` - Your home LAN

### ❌ Bypasses VPN (Normal Speed):

- **Everything else!** (Safari, apps, streaming, etc.)
- Your internet speed is NOT affected!

## 🔧 Troubleshooting

### Internet Not Working After Connecting

**Problem**: DNS issue

**Fix**:

1. In WireGuard app, tap your tunnel
2. Tap **"Edit"** (bottom right)
3. Find **"DNS servers"**
4. Change to: `1.1.1.1, 8.8.8.8`
5. Tap **"Save"**
6. Toggle OFF then ON

### Can't Connect

**Check**:

1. Router port forwarding is enabled (UDP 51820)
2. You're on cellular (not home WiFi)
3. WireGuard app is updated

### Connected But Can't Access Cluster

**Check**:

1. VPN is active (green dot)
2. Latest handshake is recent (< 5 minutes)
3. Data transfer is increasing

## 📱 Quick Reference

**Config File**: `~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/iphone.conf`

**QR Code**: `~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/wireguard/clients/iphone-fixed.png`

**VPN IP**: `10.8.0.3`

**Server Endpoint**: `184.147.64.214:51820`

## ✅ Verification

Your iPhone is already connected! To verify:

1. Open WireGuard app
2. Check tunnel shows **"Active"**
3. **Latest handshake** should be recent (< 2 minutes)
4. **Data received/sent** should be increasing

## 🎯 Use Cases

### Access Cluster from Anywhere

- Connect to VPN from coffee shop, airport, etc.
- Access your k3s cluster securely
- Manage services remotely

### Admin Access on the Go

- Use SSH apps to connect to Pi
- Access cluster via kubectl mobile apps
- Monitor services remotely

---

**Your iPhone VPN is working perfectly!** Just make sure the WireGuard app is installed and the tunnel is active. 🚀
