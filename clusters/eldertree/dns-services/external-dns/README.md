# External-DNS with RFC2136

Automated DNS record management for Kubernetes Ingress resources using external-dns with RFC2136 provider.

## Overview

External-DNS automatically creates DNS records in Pi-hole when Ingress resources are created, eliminating manual ConfigMap updates.

## Architecture

**BIND Backend for RFC2136:** Pi-hole uses dnsmasq which doesn't support RFC2136, so a BIND sidecar container handles RFC2136 dynamic DNS updates:

1. **BIND sidecar** runs alongside Pi-hole, listening on port 5353
2. **External-DNS** connects to BIND via RFC2136 protocol to create/update DNS records
3. **dnsmasq** forwards `eldertree.local` queries to BIND for resolution
4. **BIND** manages the `eldertree.local` zone with RFC2136 updates

**Current Status:** ✅ BIND backend configured and ready. External-DNS will automatically create DNS records when Ingress resources are created.

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

### 2. BIND Backend Configuration

BIND is configured as a sidecar container in the Pi-hole deployment:
- Listens on port 5353 for RFC2136 updates
- Manages `eldertree.local` zone
- Accepts updates authenticated with TSIG key
- dnsmasq forwards `eldertree.local` queries to BIND

Configuration files:
- `pihole/bind-configmap.yaml` - BIND named.conf and zone file
- `pihole/deployment.yaml` - BIND sidecar container configuration

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

