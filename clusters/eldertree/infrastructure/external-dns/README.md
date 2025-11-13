# External-DNS with RFC2136

Automated DNS record management for Kubernetes Ingress resources using external-dns with RFC2136 provider.

## Overview

External-DNS automatically creates DNS records in Pi-hole when Ingress resources are created, eliminating manual ConfigMap updates.

## Important Note: dnsmasq RFC2136 Limitations

**Pi-hole uses dnsmasq, which does NOT natively support RFC2136.** RFC2136 is designed for BIND-style DNS servers. To make this work, you have two options:

### Option A: BIND Backend for dnsmasq (Recommended)

Configure dnsmasq to use BIND as a backend for RFC2136 updates:

1. **Add BIND sidecar to Pi-hole deployment** (or run BIND separately)
2. **Configure dnsmasq to forward RFC2136 updates to BIND**
3. **Configure BIND to accept RFC2136 updates with TSIG**

### Option B: Keep Manual ConfigMap Approach

For now, continue using the manual ConfigMap approach. External-DNS is configured and ready, but won't work until Pi-hole has RFC2136 support via BIND backend.

**Current Status:** External-DNS is deployed but will fail to update DNS records until Pi-hole has RFC2136 support configured.

## Setup

### 1. Generate TSIG Key

```bash
tsig-keygen -a hmac-sha256 externaldns-key
```

Extract the secret and base64 encode:
```bash
echo -n "YOUR_SECRET_HERE" | base64
```

Update `secret.yaml` with the base64-encoded secret.

### 2. Configure Pi-hole for RFC2136

Pi-hole's dnsmasq needs BIND backend for RFC2136. Add to Pi-hole ConfigMap:

```yaml
# In pihole/configmap.yaml, add:
06-rfc2136.conf: |
  # Enable RFC2136 via BIND backend
  server=127.0.0.1#5353
  # Or configure dnsmasq to forward RFC2136 updates
```

**Alternative**: Use a BIND sidecar container in Pi-hole deployment.

### 3. Deploy External-DNS

Flux will automatically deploy external-dns from the HelmRelease.

Verify:
```bash
kubectl get pods -n external-dns
kubectl logs -n external-dns deployment/external-dns
```

## Usage

Create Ingress with annotation:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-service
  annotations:
    external-dns.alpha.kubernetes.io/hostname: myservice.eldertree.local
spec:
  rules:
    - host: myservice.eldertree.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

External-DNS will automatically create the DNS record.

## Troubleshooting

**DNS records not created:**
- Check external-dns logs: `kubectl logs -n external-dns deployment/external-dns`
- Verify TSIG key matches Pi-hole configuration
- Check Pi-hole accepts RFC2136 updates

**dnsmasq not accepting updates:**
- Consider BIND backend configuration
- Or use ConfigMap-based approach (manual/scripted)

## Configuration

- **Zone**: `eldertree.local`
- **TSIG Algorithm**: `hmac-sha256`
- **Policy**: `sync` (creates/updates/deletes records)
- **Registry**: `txt` (tracks ownership via TXT records)

