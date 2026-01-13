# Fix Pi-hole DNS Timeout Issue

## Problem

When setting `192.168.2.201` as the only DNS on MacBook, DNS queries timeout and network stops resolving names.

## Root Cause

**MetalLB is not properly advertising the LoadBalancer IP (192.168.2.201)** on the network. Evidence:
- ARP entry shows `(incomplete)` - MacBook can't resolve MAC address for 192.168.2.201
- DNS queries timeout even though port 53 is "reachable"
- Pi-hole is working correctly inside the cluster (listening on port 53, can resolve queries)

## Current Status

✅ **Pi-hole Pod**: Running and healthy
✅ **Pi-hole Service**: LoadBalancer IP assigned (192.168.2.201)
✅ **Pi-hole DNS**: Listening on port 53 (UDP/TCP)
✅ **MetalLB Config**: L2Advertisement configured with `wlan0` interface
❌ **MetalLB Advertising**: ARP entry incomplete, IP not reachable from MacBook

## Solution Options

### Option 1: Fix MetalLB Interface Configuration (Recommended)

The issue might be that MetalLB speakers don't have proper access to the `wlan0` interface. Check:

1. **Verify MetalLB speaker has network access**:
   ```bash
   KUBECONFIG=~/.kube/config-eldertree kubectl describe daemonset -n metallb-system metallb-speaker | grep -i "hostNetwork\|privileged"
   ```

2. **Check if wlan0 interface exists on nodes**:
   ```bash
   # SSH to a node and check
   ssh pi@192.168.2.101 "ip link show wlan0"
   ```

3. **Restart MetalLB speakers**:
   ```bash
   KUBECONFIG=~/.kube/config-eldertree kubectl rollout restart daemonset -n metallb-system metallb-speaker
   ```

4. **Check MetalLB logs for interface errors**:
   ```bash
   KUBECONFIG=~/.kube/config-eldertree kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker --tail=50 | grep -i "wlan0\|interface\|error"
   ```

### Option 2: Use NodePort Instead of LoadBalancer (Workaround)

If MetalLB continues to have issues, use NodePort to access Pi-hole directly:

1. **Change service type to NodePort**:
   ```yaml
   # In helm/pi-hole/values.yaml
   service:
     type: NodePort
   ```

2. **Access Pi-hole via node IP**:
   - Use `192.168.2.101:30053`, `192.168.2.102:30053`, or `192.168.2.103:30053`
   - Or configure router to forward DNS to one of these

3. **Configure MacBook DNS**:
   - Primary: `192.168.2.101` (or any node IP)
   - This will use NodePort 30053 automatically

### Option 3: Use Router as DNS Forwarder (If Supported)

If your router supports DNS forwarding:

1. **Enable DNS forwarding** in router settings
2. **Set forwarder to**: `192.168.2.201`
3. **Keep router IP (192.168.2.1) as DNS** on MacBook
4. Router will forward queries to Pi-hole

### Option 4: Use Pi-hole NodePort Directly (Quick Fix)

Since nodes are reachable (192.168.2.101, 102, 103), use NodePort:

1. **Check current NodePort**:
   ```bash
   KUBECONFIG=~/.kube/config-eldertree kubectl get svc -n pihole pi-hole
   # Look for 30053/UDP and 30053/TCP
   ```

2. **Configure MacBook DNS to use node IP**:
   - System Settings → Network → DNS
   - Add: `192.168.2.101` (or 102, 103)
   - macOS will automatically use port 53 (standard DNS port)

   **Note**: This might not work if NodePort requires explicit port. In that case, you'd need to use `192.168.2.101:30053` which requires special DNS client configuration.

## Immediate Workaround

**Use router DNS with fallback**:

1. **Keep router (192.168.2.1) as primary DNS**
2. **Add Pi-hole (192.168.2.201) as secondary DNS**
3. **Or use Cloudflare (1.1.1.1) as secondary** for external domains

This way:
- External domains resolve via router/Cloudflare
- When Pi-hole becomes reachable, it will be used
- Network doesn't break completely

## Verification Steps

After applying fix:

```bash
# 1. Check ARP entry
arp -a | grep "192.168.2.201"
# Should show MAC address (not "incomplete")

# 2. Test DNS query
nslookup google.com 192.168.2.201
# Should resolve

# 3. Test local domain
nslookup grafana.eldertree.local 192.168.2.201
# Should resolve to 192.168.2.200

# 4. Check MetalLB logs
KUBECONFIG=~/.kube/config-eldertree kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker --tail=20 | grep "192.168.2.201"
# Should show "service has IP, announcing"
```

## Next Steps

1. ✅ Check MetalLB speaker network configuration
2. ✅ Verify wlan0 interface on nodes
3. ✅ Check MetalLB logs for errors
4. ⏳ Apply fix based on findings
5. ⏳ Test DNS resolution
