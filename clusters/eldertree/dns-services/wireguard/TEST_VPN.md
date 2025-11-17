# Test VPN Connection from Phone

Now that you've activated WireGuard on your phone, test the connection:

## Quick Tests

### 1. Check VPN Status
On your phone, open WireGuard app and verify:
- Status shows "Connected" (green)
- Shows "10.8.0.3" as your IP
- Shows data transferred (bytes sent/received)

### 2. Test Basic Connectivity

**From your phone's browser:**
- Open browser
- Navigate to: `https://192.168.2.83`
- You should see Traefik or get a response (may show certificate warning - that's OK)

### 3. Test Cluster Services

**Canopy:**
- Navigate to: `https://canopy.eldertree.local`
- Should load the finance dashboard

**Pi-hole:**
- Navigate to: `https://pihole.eldertree.local`
- Should load Pi-hole admin interface

**Vault:**
- Navigate to: `https://vault.eldertree.local`
- Should load Vault UI

### 4. Test Kubernetes API (if you have kubectl on phone)

If you have a terminal app on your phone:
```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
kubectl get pods -A
```

## Troubleshooting

### Can't Connect
1. Check WireGuard app shows "Connected"
2. Verify server is running: `ssh raolivei@eldertree "sudo systemctl status wg-quick@wg0"`
3. Check firewall allows UDP 51820

### Can't Access Services
1. Check DNS resolution - try using IP directly: `https://192.168.2.83`
2. Verify Pi-hole DNS: `nslookup canopy.eldertree.local 192.168.2.83`
3. Check WireGuard handshake: Server should show recent handshake time

### Slow Connection
- Normal on mobile LTE - WireGuard adds minimal overhead
- First connection may be slower as routes are established

## Success Indicators

✅ WireGuard app shows "Connected"  
✅ Can ping `192.168.2.83`  
✅ Can access `https://canopy.eldertree.local`  
✅ Can access other cluster services  

## Next Steps

Once verified working:
- You can now access your cluster from anywhere!
- Switch between WiFi and mobile LTE - VPN stays connected
- All cluster services accessible via `.eldertree.local` domains

