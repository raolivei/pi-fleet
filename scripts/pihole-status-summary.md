# Pi-hole Status Summary

## Current Status: ✅ WORKING

### Components Status

1. **Pi-hole Pod**: ✅ Running (2/2 containers ready)

   - Pod: `pi-hole-dc976fffc-zdms5`
   - Node: `node-3.eldertree.local`
   - IP: `10.0.0.3`

2. **Pi-hole Service**: ✅ LoadBalancer IP Assigned

   - Type: `LoadBalancer`
   - ClusterIP: `10.43.227.7`
   - External IP: `192.168.2.201` ✅
   - Ports: 53/UDP, 53/TCP, 80/TCP, 443/TCP, 5353/UDP, 5353/TCP

3. **MetalLB**: ✅ Running and Advertising

   - Controller: Running
   - Speakers: 3/3 running (one restarting after config update)
   - IPAddressPool: `192.168.2.200-192.168.2.210`
   - L2Advertisement: ✅ Configured with `wlan0` interface

4. **ExternalDNS**: ✅ Running and Creating Records
   - RFC2136 provider: Running
   - Cloudflare provider: Running
   - DNS records created for:
     - `grafana.eldertree.local` → `192.168.2.200`
     - `prometheus.eldertree.local` → `192.168.2.200`
     - `vault.eldertree.local` → `192.168.2.200`
     - `pihole.eldertree.local` → `192.168.2.200`
     - `swimto.eldertree.local` → `192.168.2.200`
     - `pitanga.eldertree.local` → `192.168.2.200`
     - `flux-ui.eldertree.local` → `192.168.2.200`

### DNS Resolution Tests

✅ **Direct to Pi-hole (192.168.2.201)**:

```bash
$ nslookup grafana.eldertree.local 192.168.2.201
Server:		192.168.2.201
Address:	192.168.2.201#53

Non-authoritative answer:
Name:	grafana.eldertree.local
Address: 192.168.2.200
```

✅ **External DNS via Pi-hole**:

```bash
$ nslookup google.com 192.168.2.201
# Resolves correctly
```

⚠️ **Via Router (192.168.2.1)**:

- Currently queries go to router, which may not forward to Pi-hole
- Router needs to be configured to use Pi-hole as upstream DNS

### Pi-hole Functions

1. **DNS Server**: ✅ Working

   - Listens on port 53 (UDP/TCP)
   - Resolves external domains (e.g., google.com)
   - Resolves local domains (e.g., grafana.eldertree.local)

2. **BIND Backend**: ✅ Working

   - Listens on port 5353 (UDP/TCP)
   - Accepts RFC2136 dynamic updates from ExternalDNS
   - Zone: `eldertree.local`

3. **Web UI**: ✅ Available

   - Ingress: `pihole.eldertree.local`
   - LoadBalancer: `192.168.2.201:80`

4. **Ad-blocking**: ✅ Enabled
   - Upstream DNS: Cloudflare (1.1.1.1, 1.0.0.1)

### Recent Fixes Applied

1. ✅ **MetalLB L2Advertisement**: Added `wlan0` interface specification
   - File: `clusters/eldertree/core-infrastructure/metallb/config.yaml`
   - Applied: `kubectl apply -f clusters/eldertree/core-infrastructure/metallb/config.yaml`
   - Restarted: `kubectl rollout restart daemonset -n metallb-system metallb-speaker`

### Remaining Issues

1. ⚠️ **Router DNS Configuration**

   - MacBook uses router (192.168.2.1) as DNS
   - Router should forward to Pi-hole (192.168.2.201) or DHCP should hand out Pi-hole IP
   - **Action**: Configure router admin panel

2. ⚠️ **ICMP/Ping to 192.168.2.201**
   - Ping doesn't work (ICMP may be blocked)
   - DNS queries work (UDP port 53)
   - This is not critical - DNS is the important service

### Configuration Files

- **MetalLB Config**: `clusters/eldertree/core-infrastructure/metallb/config.yaml`
- **Pi-hole HelmRelease**: `clusters/eldertree/dns-services/pihole/helmrelease.yaml`
- **Pi-hole Values**: `helm/pi-hole/values.yaml`
- **ExternalDNS HelmRelease**: `clusters/eldertree/dns-services/external-dns/helmrelease.yaml`

### Verification Commands

```bash
# Check Pi-hole status
KUBECONFIG=~/.kube/config-eldertree kubectl get pods -n pihole
KUBECONFIG=~/.kube/config-eldertree kubectl get svc -n pihole

# Test DNS resolution
nslookup grafana.eldertree.local 192.168.2.201
nslookup google.com 192.168.2.201

# Check MetalLB
KUBECONFIG=~/.kube/config-eldertree kubectl get pods -n metallb-system
KUBECONFIG=~/.kube/config-eldertree kubectl get l2advertisement -n metallb-system

# Check ExternalDNS
KUBECONFIG=~/.kube/config-eldertree kubectl get pods -n external-dns
KUBECONFIG=~/.kube/config-eldertree kubectl logs -n external-dns external-dns-7c4775466c-kghr8 --tail=20
```

### Next Steps

1. ✅ **MetalLB Configuration**: Fixed (wlan0 interface specified)
2. ⏳ **Router DNS**: Configure router to use Pi-hole as upstream DNS
3. ✅ **DNS Records**: Verified working via ExternalDNS
4. ✅ **Pi-hole Functionality**: All functions working correctly

---

**Last Updated**: 2026-01-12
**Status**: ✅ DNS resolution working when querying Pi-hole directly
