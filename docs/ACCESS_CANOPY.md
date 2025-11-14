# How to Access Canopy from Your Network

Canopy is now accessible at: **https://canopy.eldertree.local**

## Quick Start

### Option 1: Use Pi-hole DNS (Recommended)

Configure your device to use Pi-hole as its DNS server:

**DNS Server**: `192.168.2.83`

This will automatically resolve `canopy.eldertree.local` and give you ad-blocking too!

#### macOS

```bash
# Temporarily (until reboot)
sudo networksetup -setdnsservers Wi-Fi 192.168.2.83

# To revert:
sudo networksetup -setdnsservers Wi-Fi empty
```

#### Linux

```bash
# Edit /etc/resolv.conf
sudo nano /etc/resolv.conf

# Add this line at the top:
nameserver 192.168.2.83
```

#### Windows

1. Open Network Settings
2. Go to "Change adapter options"
3. Right-click your network adapter → Properties
4. Select "Internet Protocol Version 4 (TCP/IPv4)" → Properties
5. Select "Use the following DNS server addresses"
6. Enter `192.168.2.83` as Preferred DNS server
7. Click OK

#### Router-Wide (Best for whole network)

1. Login to your router admin panel
2. Find DHCP/DNS settings
3. Set Primary DNS to: `192.168.2.83`
4. Set Secondary DNS to: `8.8.8.8` (Google DNS as fallback)
5. Save and reboot router
6. Reconnect all devices

### Option 2: Edit Hosts File (Quick Test)

#### macOS/Linux

```bash
sudo nano /etc/hosts

# Add this line:
192.168.2.83 canopy.eldertree.local
```

#### Windows (Run as Administrator)

```powershell
notepad C:\Windows\System32\drivers\etc\hosts

# Add this line:
192.168.2.83 canopy.eldertree.local
```

## Accessing Canopy

Once DNS is configured, open your browser and navigate to:

### 🔒 **https://canopy.eldertree.local** (HTTPS - Recommended)

All HTTP traffic is automatically redirected to HTTPS for security.

### Important Notes

1. **Self-Signed Certificate**: The first time you visit, you'll see a security warning because we're using a self-signed certificate. This is normal and safe for local `.local` domains.

   **To proceed:**

   - **Chrome/Edge**: Click "Advanced" → "Proceed to canopy.eldertree.local (unsafe)"
   - **Firefox**: Click "Advanced" → "Accept the Risk and Continue"
   - **Safari**: Click "Show Details" → "visit this website"

2. **API Endpoints**: The API is available at:

   - `https://canopy.eldertree.local/api/`
   - `https://canopy.eldertree.local/api/v1/health` (health check)

3. **Automatic HTTPS Redirect**: HTTP requests are automatically redirected to HTTPS:

   ```bash
   # This will redirect to HTTPS
   curl -L http://canopy.eldertree.local

   # Test HTTPS directly (use -k to skip certificate verification)
   curl -k https://canopy.eldertree.local/api/v1/health
   ```

4. **Certificate Details**:
   - **Issuer**: Self-Signed (via cert-manager)
   - **Valid for**: 90 days
   - **Auto-renewal**: Yes (cert-manager handles this)
   - **Domains**: canopy.eldertree.local

## Troubleshooting

### Can't resolve canopy.eldertree.local

**Test DNS resolution:**

```bash
# macOS/Linux
nslookup canopy.eldertree.local 192.168.2.83

# or
dig @192.168.2.83 canopy.eldertree.local

# Windows
nslookup canopy.eldertree.local 192.168.2.83
```

**Expected output:**

```
Server:		192.168.2.83
Address:	192.168.2.83#53

Name:	canopy.eldertree.local
Address: 192.168.2.83
```

### Connection Refused

Check if Traefik is running:

```bash
kubectl get pods -n kube-system | grep traefik
kubectl get svc -n kube-system traefik
```

Check if Canopy pods are running:

```bash
kubectl get pods -n canopy
```

### HTTPS Certificate Warnings

The cluster uses a self-signed certificate for `.local` domains. This is expected and safe for internal use.

**Why you see this warning:**

- Self-signed certificates aren't trusted by browsers by default
- This is normal for internal/local services
- The connection is still encrypted

**To avoid warnings:**

1. **Accept once** - Browser will remember your choice
2. **Import the CA certificate** (Advanced - for permanent trust):

   ```bash
   # Export the CA cert
   kubectl get secret -n canopy canopy-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > canopy-ca.crt

   # Then import canopy-ca.crt into your browser's trusted certificates
   ```

3. **Use a real domain** - Configure with Let's Encrypt for a public domain (requires external access)

## Network Architecture

```
Your Device
    ↓
DNS Query for canopy.eldertree.local
    ↓
Pi-hole DNS (192.168.2.83:53)
    ↓
Returns: 192.168.2.83
    ↓
HTTP/HTTPS Request to 192.168.2.83:80/443
    ↓
Traefik Ingress Controller
    ↓
Routes to Canopy Frontend (port 3000) or API (port 8000)
```

## Other Services

Other services available via ingress on eldertree cluster:

- **Pi-hole**: https://pihole.eldertree.local/admin
- **Vault**: https://vault.eldertree.local
- **Grafana**: https://grafana.eldertree.local (when deployed)
- **Prometheus**: https://prometheus.eldertree.local (when deployed)

All resolve to `192.168.2.83` via Pi-hole DNS.

## Quick Test Script

Save this as `test-canopy-access.sh`:

```bash
#!/bin/bash

echo "Testing Canopy Access..."
echo ""

echo "1. Testing DNS resolution..."
nslookup canopy.eldertree.local 192.168.2.83 || dig @192.168.2.83 canopy.eldertree.local

echo ""
echo "2. Testing HTTPS endpoint..."
curl -I -k https://canopy.eldertree.local

echo ""
echo "3. Testing HTTP to HTTPS redirect..."
curl -I http://canopy.eldertree.local

echo ""
echo "4. Testing API health..."
curl -k https://canopy.eldertree.local/api/v1/health

echo ""
echo "If all tests pass, Canopy is accessible!"
echo "Open: https://canopy.eldertree.local in your browser"
```

```bash
chmod +x test-canopy-access.sh
./test-canopy-access.sh
```

## Mobile Devices

### iOS

1. Go to Settings → Wi-Fi
2. Tap the (i) icon next to your network
3. Scroll to DNS
4. Tap "Configure DNS"
5. Select "Manual"
6. Add Server: `192.168.2.83`
7. Save

### Android

1. Go to Settings → Network & Internet → Wi-Fi
2. Long press your network
3. Tap "Modify Network"
4. Show advanced options
5. Change IP settings to "Static"
6. Set DNS 1 to: `192.168.2.83`
7. Save

## Support

If you're still having issues:

1. Check that you're on the same network as the cluster (192.168.2.x)
2. Verify Pi-hole is running: `kubectl get pods -n pihole`
3. Check Traefik logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=traefik`
4. Check Canopy pod logs: `kubectl logs -n canopy -l app=canopy`
