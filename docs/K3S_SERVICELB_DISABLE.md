# Disabling K3s ServiceLB (Klipper)

## Why Disable K3s ServiceLB?

K3s comes with a built-in LoadBalancer implementation called ServiceLB (formerly Klipper-lb). However, when using kube-vip for LoadBalancer services, K3s ServiceLB can create conflicts:

1. **Port 53 conflicts**: K3s ServiceLB tries to bind DNS port 53 on the host, conflicting with CoreDNS
2. **IP assignment delays**: Both controllers try to manage the same service
3. **kube-vip compatibility**: kube-vip v0.8.3 ignores services with `loadBalancerClass` set, but K3s ServiceLB doesn't respect this field

## Current Status

- **Traefik**: Has svclb pods running (not causing issues currently)
- **Pi-hole**: LoadBalancer IP stuck in `<pending>` because kube-vip ignores it due to `loadBalancerClass` field

## Solution: Disable K3s ServiceLB Cluster-Wide

### Step 1: Update K3s Server Configuration

On each control plane node, edit `/etc/systemd/system/k3s.service`:

```bash
# SSH to each node
ssh raolivei@192.168.2.101  # node-1
ssh raolivei@192.168.2.102  # node-2
ssh raolivei@192.168.2.103  # node-3

# Edit the service file
sudo nano /etc/systemd/system/k3s.service

# Add --disable servicelb to the ExecStart line:
ExecStart=/usr/local/bin/k3s server \
  --disable servicelb \
  ... (other existing flags)
```

### Step 2: Restart K3s

```bash
# On each node:
sudo systemctl daemon-reload
sudo systemctl restart k3s
```

### Step 3: Verify ServiceLB is Disabled

```bash
# Check that svclb pods are gone
kubectl get pods -n kube-system | grep svclb
# Should return nothing

# Check kube-vip is handling LoadBalancer services
kubectl get svc -A | grep LoadBalancer
```

### Step 4: Reconcile Pi-hole

```bash
# Delete the stuck service
kubectl delete svc pi-hole -n pihole

# Force Flux to reconcile
flux reconcile helmrelease pi-hole -n pihole

# Verify external IP is assigned
kubectl get svc pi-hole -n pihole
# Should show EXTERNAL-IP: 192.168.2.201
```

## Alternative: Upgrade kube-vip

Instead of disabling K3s ServiceLB, you could upgrade kube-vip to a version that supports `loadBalancerClass`. Check the latest version at: https://github.com/kube-vip/kube-vip/releases

Current version: v0.8.3

## DNS Configuration After Fix

Once Pi-hole has its LoadBalancer IP (192.168.2.201), configure your devices:

### macOS
1. System Settings → Network → Wi-Fi → Details → DNS
2. Add `192.168.2.201` as first DNS server
3. Keep `8.8.8.8` and `1.1.1.1` as fallback

### Router (for network-wide ad blocking)
Configure router DNS to point to `192.168.2.201`

### VPN Compatibility
This DNS setup won't interfere with AWS VPN - the VPN client manages its own DNS routing for VPN-specific domains.
