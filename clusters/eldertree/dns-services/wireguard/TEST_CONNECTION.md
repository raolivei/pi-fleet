# Test VPN Connection After Port Forwarding

Now that port forwarding is configured, test your connection:

## On Your Phone

1. **Open WireGuard app**
2. **Toggle the connection ON** (should show "Connected" in green)
3. **Check the status:**
   - Should show IP: `10.8.0.3`
   - Should show data transferred (bytes sent/received)
   - Should show "Last handshake" time

## Test Access

### Test 1: Ping the Cluster

From your phone, try pinging the cluster (if you have a network tool):

- Ping: `192.168.2.83`
- Should get responses

### Test 2: Access Cluster Services

Open browser on phone and try:

- **Canopy**: `https://canopy.eldertree.local`
- **Pi-hole**: `https://pihole.eldertree.local`
- **Vault**: `https://vault.eldertree.local`
- **Direct IP**: `https://192.168.2.83`

### Test 3: Check Server Status

The server should show an active handshake. Run this to check:

```bash
ssh raolivei@eldertree "sudo wg show"
```

You should see:

- `endpoint:` with your phone's IP
- `latest handshake:` with a recent timestamp
- `transfer:` showing bytes sent/received

## Success Indicators

✅ WireGuard app shows "Connected"  
✅ Shows data transferred  
✅ Can access `https://canopy.eldertree.local`  
✅ Server shows handshake time  
✅ Server shows endpoint IP

## If Still Not Working

1. **Check router firewall** - May need to allow UDP 51820
2. **Restart WireGuard on phone** - Toggle off/on
3. **Check mobile carrier** - Some block VPN connections
4. **Try from WiFi first** - To rule out carrier blocking
