# iPhone WireGuard DNS Configuration

## How DNS Works on iPhone with WireGuard

Unlike macOS, iPhone doesn't have `/etc/hosts` file access. However, WireGuard on iPhone handles DNS differently and **safely**:

### Key Points:

1. **Tunnel-Specific DNS**: WireGuard's DNS setting **only applies when that specific WireGuard tunnel is active**
   - When WireGuard is **OFF**: Uses your normal system DNS (carrier, WiFi router, etc.)
   - When WireGuard is **ON**: Uses the DNS specified in WireGuard config (Pi-hole: `192.168.2.83`)
   - When WireGuard is **OFF again**: Returns to system DNS

2. **Doesn't Interfere with Other VPNs**: 
   - Each VPN manages its own DNS settings independently
   - AWS VPN and WireGuard can coexist - each uses its own DNS when active
   - If both are connected, iOS prioritizes based on VPN order/configuration

3. **Current Mobile Config**:
   ```
   DNS = 192.168.2.83
   ```
   This is correct and safe for iPhone - it only applies when WireGuard is connected.

## Setup Instructions

### Option 1: Use DNS in WireGuard (Recommended for iPhone)

The `client-mobile.conf` already has DNS configured. Just:

1. **Import the config** into WireGuard app (scan QR code or import file)
2. **Connect** - DNS will automatically use Pi-hole (`192.168.2.83`)
3. **Access services**: `https://canopy.eldertree.local` will work!

**When WireGuard is disconnected**: Your iPhone returns to normal DNS (carrier/WiFi DNS).

### Option 2: Access by IP (No DNS needed)

If you prefer not to use DNS:

1. Edit the tunnel in WireGuard app
2. Remove or comment out the `DNS = 192.168.2.83` line
3. Access services by IP: `https://192.168.2.83` (Traefik will route based on Host header)

## Testing on iPhone

Once connected to WireGuard:

1. **Open Safari**
2. Navigate to: `https://canopy.eldertree.local`
3. Should load the Canopy dashboard!

If DNS doesn't work:
- Try accessing by IP: `https://192.168.2.83`
- Check WireGuard app shows "Connected" (green)
- Verify Pi-hole is reachable: `ping 192.168.2.83` (if you have a terminal app)

## Why This is Safe

- **Tunnel-specific**: DNS only applies when WireGuard is connected
- **Non-persistent**: When you disconnect WireGuard, DNS returns to normal
- **Isolated**: Doesn't affect other VPNs or system DNS settings
- **Reversible**: Disconnect WireGuard = back to normal DNS

## Comparison: Mac vs iPhone

| Platform | DNS Method | Persistence |
|----------|-----------|------------|
| **Mac** | `/etc/hosts` or WireGuard DNS | `/etc/hosts` persists; WireGuard DNS only when connected |
| **iPhone** | WireGuard DNS only | Only when WireGuard is connected |

## Summary

✅ **Use DNS in WireGuard config for iPhone** - It's safe and tunnel-specific  
✅ **DNS only applies when WireGuard is connected**  
✅ **Won't interfere with AWS VPN** - Each VPN manages its own DNS  
✅ **Access `.eldertree.local` domains** when WireGuard is active  

The current `client-mobile.conf` is already configured correctly!

