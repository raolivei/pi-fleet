# Fixed NAT Configuration

## Issue
The WireGuard server was configured to use `eth0` for NAT masquerading, but the Raspberry Pi is using `wlan0` (WiFi) as its network interface.

## Automatic Fix

Run the fix script on the server:

```bash
# On your Mac, copy and run the fix script
scp fix-interface.sh raolivei@eldertree:/tmp/
ssh raolivei@eldertree
sudo bash /tmp/fix-interface.sh
```

Or download and run directly on the Pi:

```bash
ssh raolivei@eldertree
cd /tmp
curl -O https://raw.githubusercontent.com/raolivei/raolivei/main/pi-fleet/clusters/eldertree/infrastructure/wireguard/fix-interface.sh
chmod +x fix-interface.sh
sudo ./fix-interface.sh
```

## Manual Fix

If you prefer to fix manually:

1. SSH to the server: `ssh raolivei@eldertree`
2. Edit the config: `sudo nano /etc/wireguard/wg0.conf`
3. Find lines with `-o eth0 -j MASQUERADE` and replace `eth0` with `wlan0` (or your actual interface)
4. Restart WireGuard: `sudo systemctl restart wg-quick@wg0`

## Fix Applied
Updated `/etc/wireguard/wg0.conf` to use the correct network interface (detected automatically) instead of hardcoded `eth0`.

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

