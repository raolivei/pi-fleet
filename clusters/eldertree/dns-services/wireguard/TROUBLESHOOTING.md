# WireGuard VPN Troubleshooting

## Phone Shows "Nothing Happens" / Won't Connect

### Common Issues:

1. **Router Firewall Blocking Port**
   - UDP port 51820 must be forwarded to 192.168.2.83
   - Check router admin panel → Port Forwarding
   - Some routers block VPN traffic by default

2. **Mobile Carrier Blocking VPN**
   - Some carriers block VPN connections
   - Try connecting from WiFi first to test
   - If WiFi works but LTE doesn't, carrier may be blocking

3. **NAT Traversal Issues**
   - WireGuard needs UDP port forwarding
   - Some routers don't handle UDP NAT well
   - May need to enable "UPnP" or configure static port forwarding

### Quick Tests:

**Test 1: Can phone reach server?**
- From phone browser: Try `http://184.147.64.214` (should timeout, but confirms IP is reachable)
- If this fails, phone can't reach your public IP at all

**Test 2: Is port open?**
- Use online port checker: https://www.yougetsignal.com/tools/open-ports/
- Check UDP port 51820
- If closed, router firewall is blocking

**Test 3: Try from WiFi first**
- Connect phone to same WiFi network
- Try connecting WireGuard
- If WiFi works but LTE doesn't → carrier blocking or router NAT issue

### Fixes:

**Fix 1: Router Port Forwarding**
1. Log into router (usually 192.168.2.1 or 192.168.1.1)
2. Find "Port Forwarding" or "Virtual Server"
3. Add rule:
   - Protocol: UDP
   - External Port: 51820
   - Internal IP: 192.168.2.83
   - Internal Port: 51820
4. Save and restart router if needed

**Fix 2: Check Router Firewall**
- Some routers have firewall rules blocking VPN
- Look for "VPN Passthrough" or "PPTP/L2TP Passthrough"
- Enable if available

**Fix 3: Test Server Locally**
```bash
# On Pi, test if WireGuard is listening:
sudo ss -ulnp | grep 51820

# Should show WireGuard listening
```

**Fix 4: Verify Client Config**
- Make sure Endpoint IP matches your public IP: `184.147.64.214`
- Make sure port is `51820`
- Verify PublicKey matches server public key

### Debug Commands:

**On Server:**
```bash
# Check WireGuard status
sudo wg show

# Check if listening
sudo ss -ulnp | grep 51820

# Check firewall rules
sudo iptables -L -n -v | grep wg0

# Check logs
sudo journalctl -u wg-quick@wg0.service -f
```

**On Phone:**
- WireGuard app → Tap your connection → "View Log"
- Look for connection errors
- Check if it shows "Resolving endpoint" or "Handshake failed"

### Alternative: Use Tailscale

If WireGuard continues to have issues, consider Tailscale which handles NAT traversal automatically:
- Easier setup
- Works through most firewalls
- No port forwarding needed
- Free for personal use

