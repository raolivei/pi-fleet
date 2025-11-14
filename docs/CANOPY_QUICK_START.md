# Canopy Quick Start - Network Access

## 🚀 Quick Access (5 Minutes)

### Step 1: Configure DNS on Your Device

**Set DNS Server to**: `192.168.2.83`

<details>
<summary><b>macOS</b></summary>

```bash
sudo networksetup -setdnsservers Wi-Fi 192.168.2.83
```

</details>

<details>
<summary><b>Windows</b></summary>

1. Network Settings → Change adapter options
2. Right-click adapter → Properties
3. IPv4 → Properties → Use DNS: `192.168.2.83`
</details>

<details>
<summary><b>Linux</b></summary>

```bash
# Add to /etc/resolv.conf
nameserver 192.168.2.83
```

</details>

<details>
<summary><b>iOS</b></summary>

Settings → Wi-Fi → (i) → DNS → Manual → Add `192.168.2.83`

</details>

<details>
<summary><b>Android</b></summary>

Settings → Wi-Fi → Modify Network → Static IP → DNS1: `192.168.2.83`

</details>

### Step 2: Open Canopy

Navigate to: **https://canopy.eldertree.local**

### Step 3: Accept Certificate

Click "Advanced" → "Proceed" (one-time only)

---

## ✅ Status Check

```bash
# Test from terminal
curl -k https://canopy.eldertree.local/api/v1/health
```

**Expected**: `{"status":"ok"}` or similar

---

## 🔐 HTTPS Details

| Feature           | Status                              |
| ----------------- | ----------------------------------- |
| **URL**           | https://canopy.eldertree.local      |
| **Certificate**   | Self-signed (valid 90 days)         |
| **HTTP Redirect** | ✅ Auto-redirects to HTTPS          |
| **API Endpoint**  | https://canopy.eldertree.local/api/ |
| **Encryption**    | ✅ TLS enabled                      |

---

## 🌐 Network Info

- **Cluster IP**: `192.168.2.83`
- **DNS Server**: Pi-hole @ `192.168.2.83:53`
- **Ingress**: Traefik @ `192.168.2.83:80/443`
- **Domain**: `*.eldertree.local`

---

## ⚠️ Troubleshooting

### Can't connect?

1. **Check DNS**: `nslookup canopy.eldertree.local 192.168.2.83`
2. **Ping cluster**: `ping 192.168.2.83`
3. **Check pods**: `kubectl get pods -n canopy`

### Certificate error?

This is expected! Self-signed certificates show warnings. The connection is still encrypted and safe for local use.

**One-time fix**: Accept the certificate in your browser.

---

## 📱 Mobile Access

Works on any device on the same network! Just configure DNS to `192.168.2.83` and visit `https://canopy.eldertree.local`

---

## 🔧 Advanced

<details>
<summary>Export & Trust Certificate (removes browser warnings)</summary>

```bash
# Export CA certificate
kubectl get secret -n canopy canopy-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > canopy-ca.crt

# Import into system/browser trust store
# macOS: Keychain Access → Import → Trust for SSL
# Windows: certmgr.msc → Trusted Root → Import
# Linux: Copy to /usr/local/share/ca-certificates/ and run update-ca-certificates
```

</details>

<details>
<summary>Set Router DNS (network-wide access)</summary>

1. Login to router admin
2. DHCP Settings → Primary DNS: `192.168.2.83`
3. Secondary DNS: `8.8.8.8` (fallback)
4. Save and reboot router

All devices will automatically use Pi-hole DNS!

</details>

---

## 📖 Full Documentation

See [ACCESS_CANOPY.md](./ACCESS_CANOPY.md) for complete setup guide.

---

**Need help?** Check cluster status:

```bash
kubectl get pods -n canopy
kubectl get ingress -n canopy
kubectl get certificate -n canopy
```



