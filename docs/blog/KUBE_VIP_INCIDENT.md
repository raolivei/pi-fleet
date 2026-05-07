# The Great kube-vip Incident: When Infrastructure Upgrades Go Wrong

**Date**: May 4-7, 2026  
**Duration**: 3 days  
**Severity**: High (Control Plane Outage)  
**Status**: Resolved with rollback, permanent fix pending

## TL;DR

Attempted to upgrade kube-vip from v0.8.3 to v1.1.2 to support `loadBalancerClass` field. The upgrade broke the control plane VIP, causing cluster outage. Rolled back to v0.8.3, recovered via Tailscale. Learned valuable lessons about infrastructure upgrade procedures.

## The Original Problem

Pi-hole DNS service needed a LoadBalancer IP (`192.168.2.201`) for network-wide ad blocking on my MacBook. The service manifest had `loadBalancerClass: kube-vip.io/kube-vip` set, but kube-vip v0.8.3 was **ignoring** it:

```
time="2026-05-04T02:25:15Z" level=info msg="(svcs) [pi-hole] specified the loadBalancer class [kube-vip.io/kube-vip], ignoring"
```

Result: Service stuck in `<pending>` state, no DNS resolution.

## The "Obvious" Fix

Reading kube-vip release notes, v1.1.2 added proper `loadBalancerClass` support. Perfect! Let's upgrade:

```bash
# Updated clusters/eldertree/kube-vip/kube-vip-daemonset.yaml
- image: ghcr.io/kube-vip/kube-vip:v0.8.3
+ image: ghcr.io/kube-vip/kube-vip:v1.1.2

# Applied directly (mistake #1: not via Flux)
kubectl apply -f kube-vip-daemonset.yaml
```

## What Went Wrong

**Immediately after upgrade**: Control plane VIP (`192.168.2.100`) went down.

```bash
$ kubectl get nodes
Unable to connect to the server: dial tcp 192.168.2.100:6443: connect: host is down

$ ping 192.168.2.100
100.0% packet loss
```

The cluster was effectively **offline**. API server unreachable, kubectl dead, panic mode activated.

### Why It Failed

kube-vip v1.1.2 changed how it handles ARP/VIP advertisement. The new version:
1. Started advertising but didn't establish leader election properly
2. Lost the control plane VIP (192.168.2.100)  
3. All three nodes thought someone else was leader
4. Result: No node advertising the VIP

Logs showed:
```
2026/05/04 05:01:09 INFO starting Kube-vip Manager mode=ARP
2026/05/04 05:01:09 INFO Start ARP/NDP advertisement Global
```

But no actual VIP binding occurred.

## The Recovery

### Step 1: Tailscale to the Rescue

Fortunately, I had Tailscale subnet routing configured on all nodes:

```bash
# Nodes advertise their subnets via Tailscale
node-1: 100.86.241.124 (routes 192.168.2.0/24)
node-2: 100.116.185.57
node-3: 100.104.30.105
```

Could reach API via Tailscale:
```bash
$ nc -zv 100.86.241.124 6443
Connection succeeded!
```

### Step 2: Create Emergency Kubeconfig

```bash
# Replace VIP with Tailscale IP and skip TLS verification
kubectl config view --raw | \
  sed 's|https://192.168.2.100:6443|https://100.86.241.124:6443|g' | \
  sed 's|certificate-authority-data:.*|insecure-skip-tls-verify: true|g' \
  > /tmp/kubeconfig-tailscale-insecure

export KUBECONFIG=/tmp/kubeconfig-tailscale-insecure
kubectl get nodes  # SUCCESS!
```

### Step 3: Rollback kube-vip

```bash
# Revert to v0.8.3
git checkout HEAD~1 -- clusters/eldertree/kube-vip/kube-vip-daemonset.yaml

# Apply rollback
kubectl apply --validate=false -f kube-vip-daemonset.yaml

# Wait for rollout
kubectl rollout status daemonset/kube-vip -n kube-system
```

### Step 4: Verify VIP Recovery

```bash
$ ping 192.168.2.100
64 bytes from 192.168.2.100: icmp_seq=0 ttl=64 time=9.989 ms
✅ VIP is back!

$ kubectl --kubeconfig ~/.kube/config-eldertree get nodes
NAME                     STATUS   ROLES                       AGE
node-1.eldertree.local   Ready    control-plane,etcd,master   127d
node-2.eldertree.local   Ready    control-plane,etcd,master   114d
node-3.eldertree.local   Ready    control-plane,etcd,master   113d
✅ Cluster recovered!
```

## The Real Problem: K3s ServiceLB

After recovering the cluster, Pi-hole service still had `<pending>` external IP. Investigation revealed:

```bash
$ kubectl get pods -n kube-system | grep svclb
svclb-pi-hole-886f9660-2bl5c   0/7   Pending   0   14h
svclb-pi-hole-886f9660-mndqd   0/7   Pending   0   14h
svclb-pi-hole-886f9660-nlxq2   0/7   Pending   0   14h
```

**K3s built-in ServiceLB (Klipper)** was trying to handle the LoadBalancer service by creating DaemonSet pods that:
- Try to bind host port 53
- Conflict with CoreDNS
- Get stuck in Pending
- Block kube-vip from assigning the IP

### The Helm Values Persistence Issue

Even after removing `loadBalancerClass` from git, the service still had it:

```yaml
# In git (removed):
service:
  type: LoadBalancer
  loadBalancerIP: 192.168.2.201
  # loadBalancerClass removed

# But in cluster:
spec:
  loadBalancerClass: kube-vip.io/kube-vip  # Still here!
```

**Why?** Helm **merges** values rather than replacing them. Old releases had the field, new releases didn't specify it, so it persisted.

**Fix:** Explicitly set to `null`:
```yaml
service:
  loadBalancerClass: null  # Forces Helm to remove it
```

## Lessons Learned

### 1. Infrastructure Upgrades Need Better Process

**What I did wrong:**
- ❌ Upgraded kube-vip directly without testing
- ❌ Applied manually instead of via Flux
- ❌ No rollback plan documented
- ❌ Upgraded control plane component in production

**What I should have done:**
- ✅ Test v1.1.2 on ONE node first
- ✅ Monitor for 30 minutes before rolling out
- ✅ Document rollback procedure beforehand
- ✅ Have emergency access confirmed (Tailscale ✓)
- ✅ Use Flux for GitOps, not manual kubectl apply

### 2. K3s ServiceLB Must Be Disabled

When using alternative LoadBalancer controllers (kube-vip, MetalLB), K3s ServiceLB **must** be disabled:

```bash
# Add to /etc/systemd/system/k3s.service
ExecStart=/usr/local/bin/k3s server \
  --disable servicelb \
  ... (other flags)
```

This is mentioned in k3s docs but easy to miss.

### 3. Helm Value Merging is Tricky

Removing a field from Helm values doesn't remove it from the resource. Must explicitly set to `null`:

```yaml
# Doesn't work (field persists):
service:
  type: LoadBalancer

# Works (field removed):
service:
  type: LoadBalancer
  loadBalancerClass: null
```

### 4. Tailscale Saved the Day

Having out-of-band network access via Tailscale was **critical** for recovery. Without it, would have needed:
- Physical access to nodes
- Serial console
- Or complete cluster rebuild

**Action**: Keep Tailscale configured and tested on all critical infrastructure.

### 5. Control Plane Components Need Extra Care

kube-vip manages the **control plane VIP**. Breaking it means:
- No API server access
- No kubectl
- No cluster management
- Potential data plane impact

**Never** upgrade control plane components without:
1. Tested rollback procedure
2. Alternative access method (Tailscale ✓)
3. Gradual rollout strategy
4. Monitoring and validation

## Current Status

### What's Working
- ✅ Cluster operational on kube-vip v0.8.3
- ✅ Control plane VIP stable (192.168.2.100)
- ✅ Traefik LoadBalancer working
- ✅ All applications running

### What's Not Working
- ❌ Pi-hole LoadBalancer IP still `<pending>`
- ❌ K3s ServiceLB creating conflicting pods
- ❌ Pi-hole in CrashLoopBackOff (waiting for DNS)

### Next Steps

1. **Disable K3s ServiceLB** on all nodes (requires restart)
2. **Delete and recreate Pi-hole service** to clear K3s ServiceLB pods
3. **Test kube-vip v1.1.2 properly** with gradual rollout
4. **Document all recovery procedures**
5. **Add pre-flight checks** for infrastructure upgrades

## The Bigger Picture

This incident highlighted gaps in my infrastructure upgrade process:

**Before:**
- Direct kubectl apply for infrastructure changes
- No testing strategy for control plane components
- Assumed vendor upgrades "just work"
- Recovery relied on luck (Tailscale happened to work)

**After:**
- GitOps for ALL infrastructure (including kube-vip)
- Gradual rollout with monitoring for control plane
- Document rollback before upgrade
- Test recovery procedures regularly
- Multiple access paths maintained

## Useful Commands for Future Incidents

### Emergency Access via Tailscale
```bash
# Test connectivity
nc -zv 100.86.241.124 6443

# Create emergency kubeconfig
kubectl config view --raw | \
  sed 's|https://192.168.2.100:6443|https://100.86.241.124:6443|g' | \
  sed 's|certificate-authority-data:.*|insecure-skip-tls-verify: true|g' \
  > /tmp/kubeconfig-emergency
```

### Check kube-vip Status
```bash
# Pod status
kubectl get pods -n kube-system -l app=kube-vip

# Logs
kubectl logs -n kube-system daemonset/kube-vip --tail=50

# VIP status
ping 192.168.2.100
```

### Rollback kube-vip
```bash
# Revert to last known good version
git show HEAD~1:clusters/eldertree/kube-vip/kube-vip-daemonset.yaml | \
  kubectl apply -f -

# Or edit directly
kubectl edit daemonset kube-vip -n kube-system
# Change image: ghcr.io/kube-vip/kube-vip:v1.1.2
# To:    image: ghcr.io/kube-vip/kube-vip:v0.8.3
```

## Conclusion

Infrastructure outages are stressful, but they're also the best learning opportunities. Key takeaways:

1. **Test before production** - especially for control plane components
2. **Have emergency access** - Tailscale subnet routing saved this recovery
3. **Document rollback first** - don't figure it out during an outage
4. **GitOps everything** - manual applies bypass safety checks
5. **Gradual rollouts** - one node at a time for critical components

The cluster is stable again on kube-vip v0.8.3. Pi-hole LoadBalancer fix is pending K3s ServiceLB disable. The v1.1.2 upgrade will be retried with proper testing procedure.

**Recovery time**: 3 hours (VIP down) + 3 days (root cause analysis)  
**Downtime**: 0 (applications unaffected, only management plane)  
**Data loss**: 0  
**Lessons learned**: Priceless

---

*Updated: May 7, 2026*  
*Status: Cluster stable, permanent fix in progress*
