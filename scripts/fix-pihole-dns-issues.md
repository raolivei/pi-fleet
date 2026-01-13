# Fix Pi-hole DNS Issues

## Current Problems

1. ❌ **Pi-hole IP (192.168.2.201) is not reachable** - MetalLB not advertising
2. ⚠️ **DNS queries going to router (192.168.2.1)** instead of Pi-hole
3. ❌ **grafana.eldertree.local not resolving** - DNS record may not exist

## Step 1: Fix MetalLB (Pi-hole IP Not Reachable)

**SSH to the Pi and run these commands:**

```bash
# SSH to Pi
ssh pi@192.168.2.101

# Check MetalLB status
kubectl get pods -n metallb-system

# Check MetalLB speaker logs for errors
kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker --tail=50

# Check if Pi-hole service has LoadBalancer IP assigned
kubectl get svc -n pihole pi-hole

# Check MetalLB IPAddressPool and L2Advertisement
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system

# If L2Advertisement doesn't have wlan0 interface, fix it:
kubectl get l2advertisement -n metallb-system default -o yaml
# Should have: interfaces: [wlan0]

# Restart MetalLB speaker to pick up changes
kubectl rollout restart daemonset -n metallb-system metallb-speaker

# Wait for pods to restart
kubectl get pods -n metallb-system -w
```

**If MetalLB config is missing wlan0 interface:**

```bash
# Apply the fix from the repo
cd /path/to/pi-fleet
kubectl apply -f clusters/eldertree/core-infrastructure/metallb/config.yaml
kubectl rollout restart daemonset -n metallb-system metallb-speaker
```

**Verify Pi-hole IP is now reachable:**

From your MacBook:

```bash
ping -c 2 192.168.2.201
# Should get responses

nslookup google.com 192.168.2.201
# Should resolve
```

## Step 2: Configure Router DNS

Since you can't change DNS on WiFi (AWS VPN), configure the router:

### Option A: Router as DNS Forwarder (Recommended)

Configure router to forward DNS queries to Pi-hole:

1. Access router admin panel: `http://192.168.2.1` (or check router label)
2. Navigate to **DNS Settings** or **Internet Settings**
3. Set **Upstream DNS Server** or **DNS Forwarder** to: `192.168.2.201`
4. Save and apply

This way, when devices query the router (192.168.2.1), the router forwards to Pi-hole.

### Option B: Router DHCP Hands Out Pi-hole IP

Configure router DHCP to give clients Pi-hole as DNS:

1. Access router admin panel
2. Navigate to **DHCP Settings** or **LAN Settings**
3. Find **DNS Server** or **DHCP DNS** option
4. Set to: `192.168.2.201`
5. Save and apply
6. **Restart devices** or renew DHCP leases

**Renew DHCP on macOS:**

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
# Or restart network interface
```

## Step 3: Verify DNS Records

Once Pi-hole is reachable, check if ExternalDNS created the records:

```bash
# From Pi
kubectl get pods -n external-dns
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=50

# Check if DNS records exist in Pi-hole
kubectl exec -n pihole deployment/pi-hole -c bind -- nslookup grafana.eldertree.local localhost
```

**If records don't exist, check ExternalDNS configuration:**

```bash
# Check ExternalDNS HelmRelease
kubectl get helmrelease -n external-dns external-dns -o yaml

# Reconcile ExternalDNS
flux reconcile helmrelease -n external-dns external-dns
```

## Step 4: Test DNS Resolution

From your MacBook:

```bash
# Test Pi-hole directly
nslookup google.com 192.168.2.201
nslookup grafana.eldertree.local 192.168.2.201

# Test via router (should forward to Pi-hole)
nslookup grafana.eldertree.local

# Test local domain
dig grafana.eldertree.local
```

## Troubleshooting

### MetalLB Not Advertising IP

**Check ARP on MacBook:**

```bash
arp -a | grep 192.168.2.201
# If shows "incomplete", MetalLB isn't responding
```

**On Pi, check:**

```bash
# Check if MetalLB speaker is running
kubectl get pods -n metallb-system

# Check speaker logs for "notOwner" or "noIPAllocated" errors
kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker | grep -i error

# Verify interface configuration
kubectl get l2advertisement -n metallb-system default -o yaml | grep -A 5 interfaces
```

### Router Not Forwarding DNS

- Some routers don't support DNS forwarding
- In that case, use Option B (DHCP hands out Pi-hole IP)
- Or configure devices individually (but VPN may override)

### grafana.eldertree.local Not Resolving

1. Check if ExternalDNS is running: `kubectl get pods -n external-dns`
2. Check ExternalDNS logs for errors
3. Verify ingress exists: `kubectl get ingress -A | grep grafana`
4. Check Pi-hole BIND zone: `kubectl exec -n pihole deployment/pi-hole -c bind -- cat /etc/bind/eldertree.local.zone`

## Quick Fix Script

If you have SSH access to Pi, run:

```bash
# On Pi
cd /path/to/pi-fleet

# Apply MetalLB fix
kubectl apply -f clusters/eldertree/core-infrastructure/metallb/config.yaml
kubectl rollout restart daemonset -n metallb-system metallb-speaker

# Wait for restart
sleep 10

# Check status
kubectl get svc -n pihole pi-hole
kubectl get pods -n metallb-system
```
