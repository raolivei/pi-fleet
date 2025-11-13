# DNS Troubleshooting Guide

## Issue: ExternalDNS Cannot Deploy Due to DNS Resolution Failure

### Problem

The ExternalDNS HelmRelease fails to deploy because the HelmRepository cannot fetch the chart index from `kubernetes-sigs.github.io`. The root cause is that Kubernetes pods cannot resolve external DNS domains.

### Root Cause

Kubernetes pods (including CoreDNS) cannot make UDP DNS queries to external DNS servers (8.8.8.8, 1.1.1.1, router DNS, etc.). This is typically caused by:

1. **Firewall blocking UDP port 53**: The host firewall or router may be blocking UDP port 53 egress from Kubernetes pods
2. **Kubernetes CNI (Flannel) network policies**: Flannel may be blocking UDP port 53 traffic
3. **Circular DNS dependency**: CoreDNS forwards to Pi-hole, but Pi-hole uses CoreDNS, creating a loop

### Current Configuration

**CoreDNS Configuration:**

- Forwards `eldertree.local` queries to Pi-hole (10.43.188.68:53)
- Attempts to forward all other queries to router DNS (192.168.2.1) and ISP DNS (207.164.234.193)
- **Issue**: CoreDNS pods cannot reach these DNS servers on UDP port 53

**Pi-hole Configuration:**

- Uses `dnsPolicy: None` with custom DNS servers (8.8.8.8, 1.1.1.1, 8.8.4.4)
- **Issue**: Pi-hole pods also cannot reach external DNS servers on UDP port 53

### Verification

```bash
# Test DNS from host (works)
ssh raolivei@eldertree 'dig @8.8.8.8 google.com +short'

# Test DNS from pod (fails)
kubectl exec -n kube-system deployment/coredns -- nslookup google.com
# Error: connection refused / i/o timeout
```

### Solutions

#### Option 1: Fix Firewall Rules (Recommended)

Allow UDP port 53 egress from Kubernetes pods:

```bash
# On the Raspberry Pi host
sudo iptables -I OUTPUT -p udp --dport 53 -j ACCEPT
sudo iptables -I FORWARD -p udp --dport 53 -j ACCEPT

# Make rules persistent
sudo netfilter-persistent save
```

#### Option 2: Configure Router Firewall

If using a router firewall, ensure UDP port 53 egress is allowed for the Kubernetes network (10.42.0.0/16 or 10.43.0.0/16).

#### Option 3: Use Host DNS for CoreDNS

Configure CoreDNS to use hostNetwork mode or mount host `/etc/resolv.conf`:

**Note**: This requires modifying the CoreDNS deployment, which may be overwritten by k3s updates.

#### Option 4: Temporary Workaround - Manual Chart Installation

Until DNS is fixed, you can manually install ExternalDNS:

```bash
# Add Helm repo locally
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

# Install ExternalDNS manually
helm install external-dns external-dns/external-dns \
  --namespace external-dns \
  --create-namespace \
  --set provider=rfc2136 \
  --set rfc2136.host=192.168.2.83 \
  --set rfc2136.port=5353 \
  --set rfc2136.zone=eldertree.local \
  --set rfc2136.tsigKeyname=externaldns-key \
  --set rfc2136.tsigSecret=... \
  --set rfc2136.tsigSecretAlg=hmac-sha256
```

### Current Status

- ✅ Traefik: Working
- ✅ Cert-Manager: Working
- ✅ SSL Certificates: Working (3 certificates active)
- ❌ ExternalDNS: Not deployed (DNS resolution issue)
- ⚠️ CoreDNS: Configured but cannot resolve external domains
- ⚠️ Pi-hole: Running but cannot resolve external domains
- ⚠️ DNS Proxy: Running on port 5353 but upstream DNS queries failing

### Attempted Solutions

1. **Firewall Rules**: Added iptables rules to allow UDP/TCP port 53 egress
2. **DNS Proxy on Port 5353**: Created dns-proxy DaemonSet using hostNetwork to bypass port 53 restriction
3. **CoreDNS Configuration**: Updated to forward external queries to DNS proxy on port 5353

**Current Issue**: Even with DNS proxy on port 5353, dnsmasq cannot reach upstream DNS servers (8.8.8.8, 1.1.1.1) on port 53, suggesting a deeper network/firewall restriction.

### Next Steps

1. **Fix firewall rules** to allow UDP port 53 egress from Kubernetes pods
2. **Verify DNS resolution** from pods: `kubectl exec -n kube-system deployment/coredns -- nslookup google.com`
3. **Force HelmRepository reconciliation**: `kubectl patch helmrepository -n flux-system external-dns --type merge -p '{"metadata":{"annotations":{"fluxcd.io/reconcile":"now"}}}'`
4. **Verify ExternalDNS deployment**: `kubectl get pods -n external-dns`

### References

- [CoreDNS Forward Plugin](https://coredns.io/plugins/forward/)
- [Kubernetes DNS Debugging](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
- [Flannel Network Policies](https://github.com/flannel-io/flannel)
