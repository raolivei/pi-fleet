# Fixed NAT Configuration

## Issue
The WireGuard server was configured to use `eth0` for NAT masquerading, but the Raspberry Pi is using `wlan0` (WiFi) as its network interface.

## Fix Applied
Updated `/etc/wireguard/wg0.conf` to use `wlan0` instead of `eth0` for the MASQUERADE rule.

## Test Connection

Now try accessing from your phone:

1. **Test direct IP**: `https://192.168.2.83`
2. **Test services**: `https://canopy.eldertree.local`
3. **Test DNS**: The phone should use `192.168.2.83` as DNS (Pi-hole)

## If Still Not Working

Check DNS on phone:
- WireGuard config shows DNS: `192.168.2.83`
- But phone might be using carrier DNS
- Try accessing by IP first: `https://192.168.2.83`

## Verify NAT is Working

From server, check:
```bash
sudo iptables -t nat -L POSTROUTING -n -v | grep wlan0
```

Should show MASQUERADE rule with packet counts increasing.

