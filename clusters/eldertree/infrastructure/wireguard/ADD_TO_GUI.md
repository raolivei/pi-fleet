# Add VPN to WireGuard GUI App

## Method 1: Import Config File

1. **Open WireGuard app** (should be in Applications or Launchpad)
2. Click the **"+"** button (bottom left) or **"Add Empty Tunnel"**
3. Click **"Import tunnel(s) from file..."**
4. Navigate to and select: `~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/infrastructure/wireguard/client-mac.conf`
5. Click **"Import"**
6. Name it: `eldertree` (or any name you prefer)
7. Click **"Activate"** to connect

## Method 2: Manual Entry

1. **Open WireGuard app**
2. Click **"+"** → **"Add Empty Tunnel"**
3. Copy the config below and paste into the configuration field:

```
[Interface]
PrivateKey = ICRnN1EKeGmOJVJNOCp1Yxbd5tF+gSGIhWtwXiHnyFQ=
Address = 10.8.0.2/24
DNS = 192.168.2.83

[Peer]
PublicKey = AcxnYJk0nrZLq28iQoc6B8GTkPVU2VcDevc3LTj3/FQ=
Endpoint = 184.147.64.214:51820
AllowedIPs = 10.8.0.0/24, 192.168.2.0/24
PersistentKeepalive = 25
```

4. Name it: `eldertree`
5. Click **"Activate"**

## Verify Connection

Once activated:
- Status should show "Active" (green)
- Your IP should be: `10.8.0.2`
- Test: `ping 192.168.2.83`
- Test: `kubectl get nodes`

## Disconnect

Click the toggle switch in WireGuard app to disconnect.


