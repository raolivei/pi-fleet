# Multi-Site Setup for pitanga.cloud

This namespace hosts two websites simultaneously at different subdomains:

- **pitanga.cloud** → Pitanga website (`pitanga-website`)
- **northwaysignal.pitanga.cloud** → Northwaysignal website (`northwaysignal-website`)

## Architecture

```
pitanga.cloud
    │
    └─> pitanga-website-service → pitanga-website deployment

northwaysignal.pitanga.cloud
    │
    └─> northwaysignal-website-service → northwaysignal-website deployment
```

Both websites run simultaneously in the `pitanga` namespace. Each has its own:

- Deployment
- Service
- Ingress (with separate hostnames)

## Components

### Pitanga Website

- **Deployment**: `pitanga-website`
- **Service**: `pitanga-website-service` (port 80)
- **Ingress**: `pitanga-website-public`
- **Domains**:
  - `pitanga.cloud`
  - `www.pitanga.cloud`
  - `pitanga.eldertree.local` (local)

### Northwaysignal Website

- **Deployment**: `northwaysignal-website`
- **Service**: `northwaysignal-website-service` (port 80 → container port 5000)
- **Ingress**: `northwaysignal-website-public`
- **Domains**:
  - `northwaysignal.pitanga.cloud`

## Deployment

Both websites are deployed via GitOps (Flux CD) from the `pi-fleet` repository.

### Resources

All resources are in `pi-fleet/clusters/eldertree/pitanga/`:

```
pitanga/
├── namespace.yaml                    # Namespace definition
├── ghcr-secret-external.yaml        # GHCR image pull secret
├── website-deployment.yaml          # Pitanga website deployment
├── website-service.yaml             # Pitanga website service
├── website-ingress.yaml             # Pitanga website ingress (local + public)
├── northwaysignal-deployment.yaml   # Northwaysignal website deployment
├── northwaysignal-service.yaml      # Northwaysignal website service
├── northwaysignal-ingress.yaml      # Northwaysignal website ingress (public)
├── image-automation.yaml            # Flux image automation for pitanga-website
└── kustomization.yaml               # Kustomize resources
```

### Manual Deployment

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Apply all resources
kubectl apply -k pi-fleet/clusters/eldertree/pitanga/

# Or apply individually
kubectl apply -f pi-fleet/clusters/eldertree/pitanga/northwaysignal-deployment.yaml
kubectl apply -f pi-fleet/clusters/eldertree/pitanga/northwaysignal-service.yaml
kubectl apply -f pi-fleet/clusters/eldertree/pitanga/northwaysignal-ingress.yaml
```

## DNS Configuration

### Cloudflare DNS

External-DNS automatically creates DNS records via Cloudflare API:

- `pitanga.cloud` → A record (proxied)
- `www.pitanga.cloud` → CNAME to `pitanga.cloud` (proxied)
- `northwaysignal.pitanga.cloud` → A record (proxied)

### Local DNS

Pi-hole DNS (via External-DNS RFC2136):

- `pitanga.eldertree.local` → Cluster IP

## SSL/TLS Certificates

Both public domains use the same Cloudflare Origin Certificate:

- **Secret**: `pitanga-cloudflare-origin-tls`
- **Domains**: `pitanga.cloud`, `www.pitanga.cloud`, `northwaysignal.pitanga.cloud`
- **Mode**: Full (strict) in Cloudflare

See [CLOUDFLARE_ORIGIN_CERT_SETUP.md](CLOUDFLARE_ORIGIN_CERT_SETUP.md) for certificate setup.

## Verification

### Check Deployments

```bash
kubectl get deployments -n pitanga
```

Should show:

- `pitanga-website` (1 replica)
- `northwaysignal-website` (1 replica)

### Check Services

```bash
kubectl get services -n pitanga
```

Should show:

- `pitanga-website-service` (ClusterIP, port 80)
- `northwaysignal-website-service` (ClusterIP, port 80)

### Check Ingress

```bash
kubectl get ingress -n pitanga
```

Should show:

- `pitanga-website-local` (pitanga.eldertree.local)
- `pitanga-website-public` (pitanga.cloud, www.pitanga.cloud)
- `northwaysignal-website-public` (northwaysignal.pitanga.cloud)

### Check Pods

```bash
kubectl get pods -n pitanga
```

Both pods should be `Running`.

### Test Access

```bash
# Pitanga website
curl -v https://pitanga.cloud
curl -v https://www.pitanga.cloud

# Northwaysignal website
curl -v https://northwaysignal.pitanga.cloud

# Local access
curl -k https://pitanga.eldertree.local
```

## Troubleshooting

### Northwaysignal Pod Not Starting

1. **Check image pull:**

   ```bash
   kubectl describe pod -n pitanga -l app=northwaysignal-website
   ```

   Look for `ImagePullBackOff` errors.

2. **Verify GHCR secret:**

   ```bash
   kubectl get secret ghcr-secret -n pitanga
   ```

3. **Check image exists:**
   - Visit: https://github.com/raolivei/northwaysignal-website/pkgs/container/northwaysignal-website
   - Ensure `latest` tag exists

### DNS Not Resolving

1. **Check External-DNS logs:**

   ```bash
   kubectl logs -n external-dns deployment/external-dns-cloudflare -f
   ```

2. **Verify DNS records in Cloudflare:**

   - Go to Cloudflare Dashboard → DNS → Records
   - Should see `northwaysignal.pitanga.cloud` record

3. **Test DNS resolution:**
   ```bash
   dig northwaysignal.pitanga.cloud
   ```

### Ingress Not Working

1. **Check ingress status:**

   ```bash
   kubectl describe ingress northwaysignal-website-public -n pitanga
   ```

2. **Verify service exists:**

   ```bash
   kubectl get svc northwaysignal-website-service -n pitanga
   ```

3. **Check Traefik logs:**
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=traefik -f
   ```

### Certificate Errors

1. **Verify certificate secret:**

   ```bash
   kubectl get secret pitanga-cloudflare-origin-tls -n pitanga
   ```

2. **Check certificate includes domain:**

   ```bash
   kubectl get secret pitanga-cloudflare-origin-tls -n pitanga -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep -A 1 "Subject Alternative Name"
   ```

   Should include `northwaysignal.pitanga.cloud`

3. **Verify Cloudflare SSL mode:**
   - Cloudflare Dashboard → SSL/TLS → Overview
   - Should be "Full (strict)"

## Image Updates

### Pitanga Website

Automatically updated via Flux Image Automation:

- Monitors `ghcr.io/raolivei/pitanga-website`
- Updates deployment when new images are available
- See `image-automation.yaml` for configuration

### Northwaysignal Website

Currently manual updates. To update:

```bash
# Trigger rebuild in GitHub Actions
# Or manually update deployment:
kubectl set image deployment/northwaysignal-website \
  website=ghcr.io/raolivei/northwaysignal-website:latest \
  -n pitanga
```

## Resource Limits

### Pitanga Website

- **Memory**: 64Mi request, 128Mi limit
- **CPU**: 50m request, 100m limit

### Northwaysignal Website

- **Memory**: 128Mi request, 256Mi limit
- **CPU**: 100m request, 200m limit

## Related Documentation

- [Pitanga Namespace README](README.md) - General namespace documentation
- [Cloudflare Origin Certificate Setup](CLOUDFLARE_ORIGIN_CERT_SETUP.md) - SSL/TLS certificate configuration
- [Cloudflare Email Setup](CLOUDFLARE_EMAIL_SETUP.md) - Email forwarding configuration
