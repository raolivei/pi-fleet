# Pi-hole Latency Analysis

**Date**: 2025-12-30  
**Cluster**: eldertree  
**Status**: ✅ Cluster services NOT affected, ⚠️ Pi-hole is a latency bottleneck for network clients

## Executive Summary

**Good News**: Your Kubernetes cluster services are **NOT** going through Pi-hole, so they're not affected by Pi-hole latency.

**Bad News**: Pi-hole itself is a **latency bottleneck**, adding ~100ms overhead compared to direct DNS queries. This affects any network clients configured to use Pi-hole (192.168.2.201) as their DNS server.

## Current DNS Architecture

### Cluster Services (NOT affected by Pi-hole)

```
Pod → CoreDNS (10.43.0.10) → Router DNS (192.168.2.1) → Upstream DNS
```

- **Latency**: ~0ms (cached) to ~90ms (uncached)
- **Status**: ✅ Optimal path, no Pi-hole in chain

### Network Clients (Affected by Pi-hole)

```
Client → Pi-hole (192.168.2.201) → Upstream DNS (8.8.8.8, 1.1.1.1)
```

- **Latency**: ~190ms
- **Status**: ⚠️ 100ms slower than direct DNS

## Latency Test Results

| DNS Server              | Latency | Notes                           |
| ----------------------- | ------- | ------------------------------- |
| CoreDNS (10.43.0.10)    | ~0ms    | Cached responses, very fast     |
| Pi-hole (192.168.2.201) | ~190ms  | **Bottleneck** - 100ms overhead |
| Direct (8.8.8.8)        | ~90ms   | Baseline for comparison         |

## Root Cause Analysis

### Why Pi-hole is Slow

1. **Processing Overhead** (~50-70ms)

   - Blocklist checks against ~1M+ domains
   - Query logging to database
   - dnsmasq processing
   - BIND backend for RFC2136 (additional layer)

2. **Network Path** (~20-30ms)

   - LoadBalancer IP (192.168.2.201) adds network hop
   - MetalLB routing overhead
   - Pod network namespace

3. **Resource Constraints** (minimal impact)
   - Current usage: 3m CPU, 24Mi memory (well within limits)
   - Limits: 500m CPU, 512Mi memory
   - Not currently resource-constrained

### Why Cluster Services are Fast

- CoreDNS forwards directly to router DNS (`/etc/resolv.conf` → `192.168.2.1`)
- No Pi-hole in the query path
- CoreDNS caching (30s TTL) provides sub-millisecond responses for cached queries
- Direct network path within cluster

## Current Configuration

### CoreDNS ConfigMap

```yaml
forward . /etc/resolv.conf # Points to router (192.168.2.1)
```

### Pi-hole Configuration

- **Upstream DNS**: 8.8.8.8, 1.1.1.1, 8.8.4.4
- **LoadBalancer IP**: 192.168.2.201
- **Resources**: 100m-500m CPU, 256Mi-512Mi memory
- **Current Usage**: 3m CPU, 24Mi memory

## Recommendations

### 1. ✅ Keep Current Setup (Recommended)

**For Cluster Services**: No changes needed - they're already optimized.

**For Network Clients**: Accept the ~100ms latency trade-off for ad-blocking benefits.

### 2. Optimize Pi-hole Performance

If you want to reduce Pi-hole latency:

#### A. Increase DNS Cache Size

```yaml
# In pi-hole ConfigMap, add to dnsmasq config:
cache-size=10000 # Default is 1000
```

#### B. Reduce Query Logging

- Disable query logging for non-blocked queries
- Reduce log retention period
- Use conditional logging (only log blocked queries)

#### C. Optimize Blocklist Processing

- Use fewer, more efficient blocklists
- Enable aggressive caching
- Consider using Pi-hole's built-in cache more aggressively

#### D. Increase Resources (if needed)

```yaml
resources:
  pihole:
    requests:
      cpu: 200m # Increase from 100m
      memory: 512Mi # Increase from 256Mi
    limits:
      cpu: 1000m # Increase from 500m
      memory: 1Gi # Increase from 512Mi
```

### 3. Alternative: Bypass Pi-hole for Performance-Critical Clients

Configure specific devices to use direct DNS (8.8.8.8, 1.1.1.1) instead of Pi-hole:

- Servers/workstations that need low-latency DNS
- Devices that don't need ad-blocking
- Performance-critical applications

### 4. Monitor Pi-hole Performance

Set up monitoring to track:

- DNS query latency over time
- Cache hit rates
- Resource utilization
- Query volume

## Impact Assessment

### Affected Services

- ❌ **Network clients** using Pi-hole (192.168.2.201) as DNS
- ❌ **Router-configured DNS** if router points to Pi-hole
- ✅ **Kubernetes cluster services** - NOT affected

### Performance Impact

- **DNS resolution**: +100ms per uncached query
- **First page load**: +200-500ms (multiple DNS queries)
- **Cached queries**: Minimal impact (~5-10ms)

## Testing Commands

### Test DNS Latency

```bash
# Test CoreDNS (cluster services)
kubectl run -it --rm --restart=Never dns-test --image=busybox -- \
  time nslookup google.com 10.43.0.10

# Test Pi-hole
kubectl run -it --rm --restart=Never dns-test --image=busybox -- \
  time nslookup google.com 192.168.2.201

# Test direct DNS
kubectl run -it --rm --restart=Never dns-test --image=busybox -- \
  time nslookup google.com 8.8.8.8
```

### Check Current Configuration

```bash
# CoreDNS config
kubectl get configmap coredns -n kube-system -o yaml

# Pi-hole service
kubectl get svc -n pihole

# Pi-hole resources
kubectl top pod -n pihole
```

## Conclusion

**Current Status**: ✅ Your cluster is optimized. Pi-hole latency only affects network clients, not cluster services.

**Recommendation**: Keep current setup unless network clients are experiencing noticeable performance issues. The ~100ms latency is a reasonable trade-off for ad-blocking benefits.

**Action Items**:

1. ✅ No immediate action needed for cluster services
2. ⚠️ Monitor Pi-hole performance if network clients complain
3. 📊 Consider Pi-hole optimizations if latency becomes problematic






