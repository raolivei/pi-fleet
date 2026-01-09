# Pi-hole DNS Troubleshooting Guide

## Problem: Pi-hole DNS (192.168.2.201) Not Working on Mac

When you configure your Mac to use only `192.168.2.201` as the DNS server, nothing works. DNS queries timeout and websites don't load.

## Root Cause

**The Pi-hole LoadBalancer IP (192.168.2.201) is not reachable from your Mac.**

This happens because **MetalLB is not advertising the LoadBalancer IP on the correct network interface**. MetalLB needs to advertise the IP on `wlan0` (the physical network interface), but it may be trying to advertise on the wrong interface or not advertising at all.

## Diagnosis

Run the diagnostic script to confirm:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
./scripts/diagnose-pihole-dns-mac.sh
```

**Expected symptoms:**
- ❌ `ping 192.168.2.201` fails
- ❌ `dig @192.168.2.201 google.com` times out
- ❌ DNS port (53) is not accessible
- ✅ Your Mac is on the correct network (192.168.2.0/24)
- ✅ Gateway/router is reachable
- ✅ Fallback DNS (8.8.8.8) works

## Solution

### Step 1: Verify MetalLB Configuration

On a machine with cluster access, check if MetalLB is configured correctly:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check MetalLB L2Advertisement configuration
kubectl get l2advertisement -n metallb-system default -o yaml
```

**Expected configuration:**
```yaml
spec:
  interfaces:
    - wlan0  # This is critical!
  ipAddressPools:
    - default
```

If `interfaces: [wlan0]` is missing, that's the problem.

### Step 2: Apply MetalLB Configuration

If the configuration is missing or incorrect, apply the correct configuration:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
export KUBECONFIG=~/.kube/config-eldertree

# Apply MetalLB configuration
kubectl apply -f clusters/eldertree/core-infrastructure/metallb/config.yaml

# Restart MetalLB speakers to pick up the new configuration
kubectl rollout restart daemonset -n metallb-system metallb-speaker

# Wait for restart
sleep 15
```

### Step 3: Verify MetalLB is Advertising

Check MetalLB logs to confirm it's advertising the IP:

```bash
kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker --tail=50 | grep -i "192.168.2.201\|wlan0\|announce"
```

You should see logs indicating that MetalLB is announcing/advertising the IP on wlan0.

### Step 4: Verify Pi-hole Service

Check that the Pi-hole service has the LoadBalancer IP assigned:

```bash
kubectl get svc -n pihole
```

**Expected output:**
```
NAME          TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)                        AGE
pi-hole       LoadBalancer   10.43.x.x     192.168.2.201   53:30053/UDP,53:30053/TCP...   ...
```

If `EXTERNAL-IP` shows `<pending>` instead of `192.168.2.201`, MetalLB hasn't assigned the IP yet.

### Step 5: Verify Pi-hole Pod is Running

```bash
kubectl get pods -n pihole
kubectl logs -n pihole -l app=pihole --tail=20
```

The pod should be `Running` and logs should show no errors.

### Step 6: Test from Your Mac

After applying the fixes, test from your Mac:

```bash
# Test connectivity
ping -c 3 192.168.2.201

# Test DNS
dig @192.168.2.201 google.com +short

# Test local DNS
dig @192.168.2.201 grafana.eldertree.local +short
```

If these work, your Mac should now be able to use `192.168.2.201` as the sole DNS server.

## Why This Happens

### MetalLB Layer 2 Mode

MetalLB uses Layer 2 mode to provide LoadBalancer services on bare metal. It works by:

1. Assigning a virtual IP (192.168.2.201) to the service
2. **Advertising that IP on the network** using ARP (Address Resolution Protocol)
3. When devices try to reach 192.168.2.201, they send ARP requests
4. MetalLB responds to those ARP requests, saying "I own this IP"
5. Traffic is then routed to the MetalLB speaker, which forwards it to the service

### The Problem

Your Raspberry Pi nodes have:
- **Internal IPs**: `10.0.0.1`, `10.0.0.2`, `10.0.0.3` (K3s internal network)
- **Physical IPs**: `192.168.2.x` on `wlan0` interface

If MetalLB doesn't know which interface to use, it may:
- Try to advertise on the wrong interface (10.0.0.x network)
- Not advertise at all
- Advertise on an interface that's not accessible from your Mac

By explicitly specifying `interfaces: [wlan0]` in the L2Advertisement, we tell MetalLB to advertise on the physical network interface that your Mac can reach.

## Alternative: Use Fallback DNS

If you can't fix MetalLB immediately, you can use a fallback DNS server:

**On Mac:**
1. System Settings > Network > [Your Connection] > Details > DNS
2. Add DNS servers in this order:
   - `192.168.2.201` (Pi-hole - primary)
   - `1.1.1.1` (Cloudflare - fallback)
   - `8.8.8.8` (Google - fallback)

macOS will try the first DNS server, and if it times out, it will automatically try the next one. This allows you to:
- Use Pi-hole when it's working (for ad-blocking and local DNS)
- Fall back to public DNS when Pi-hole is unreachable

**Note:** This is a workaround. The proper fix is to ensure MetalLB is advertising correctly.

## macOS DNS Cache

If you've fixed MetalLB but DNS still doesn't work, try flushing macOS DNS cache:

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

Then test again:

```bash
dig @192.168.2.201 google.com
```

## Quick Fix Script

If you have cluster access, you can run the automated fix script:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
export KUBECONFIG=~/.kube/config-eldertree
./scripts/dns-fix-when-cluster-accessible.sh
```

This script will:
1. Apply MetalLB configuration
2. Restart MetalLB speakers
3. Verify the configuration
4. Test DNS resolution

## Prevention

To prevent this issue in the future:

1. **Always specify the interface in MetalLB L2Advertisement** - Don't rely on MetalLB auto-detection
2. **Monitor MetalLB logs** - Set up alerts if LoadBalancer IPs become unreachable
3. **Use fallback DNS** - Configure fallback DNS servers on clients as a safety net
4. **Document network topology** - Keep track of which interfaces are used for which networks

## Related Documentation

- [DNS Fix Status](./DNS_FIX_STATUS.md) - Previous DNS troubleshooting
- [Pi-hole Latency Analysis](./PIHOLE_LATENCY_ANALYSIS.md) - Performance considerations
- [MetalLB Configuration](../clusters/eldertree/core-infrastructure/metallb/config.yaml) - Current MetalLB setup

## Still Not Working?

If the issue persists after following these steps:

1. **Check cluster connectivity** - Can you access the cluster API?
   ```bash
   kubectl get nodes
   ```

2. **Check Pi-hole pod logs** - Are there any errors?
   ```bash
   kubectl logs -n pihole -l app=pihole --tail=50
   ```

3. **Check MetalLB speaker logs** - Are there any errors?
   ```bash
   kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker --tail=50
   ```

4. **Verify network connectivity** - Can you ping the Raspberry Pi nodes?
   ```bash
   ping 192.168.2.101  # node-1
   ping 192.168.2.102  # node-2
   ping 192.168.2.103  # node-3
   ```

5. **Check firewall rules** - Ensure port 53 (UDP/TCP) is not blocked

6. **Check router configuration** - Some routers block ARP responses from non-router devices


