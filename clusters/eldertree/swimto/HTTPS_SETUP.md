# swimTO HTTPS Setup for Mobile Location Services

## Problem

Mobile browsers require **trusted HTTPS certificates** for location services to work. Self-signed certificates (like `swimto.eldertree.local`) are not trusted by mobile browsers, preventing location services from functioning.

## Solution

Use a **public domain** with **Let's Encrypt** certificates. This provides trusted HTTPS that mobile browsers will accept.

## Setup Steps

### 1. Update ACME Email Address

Edit `clusters/eldertree/core-infrastructure/issuers/helmrelease.yaml` and update the email:

```yaml
acme:
  enabled: true
  email: "your-actual-email@example.com"  # Update this!
  server: https://acme-v02.api.letsencrypt.org/directory
  name: letsencrypt-prod
```

**Important:** Use a real email address - Let's Encrypt will send certificate expiration notices.

### 2. Configure Public Domain

You need a public domain name (e.g., `yourdomain.com`, `example.net`). If you don't have one, you can:

- Register a domain from providers like Namecheap, Cloudflare, Google Domains, etc.
- Use a free subdomain from services like DuckDNS, No-IP, etc.

### 3. Update DNS Records

Point your domain to your server's **public IP address**:

```
swimto.yourdomain.com  A  <your-public-ip>
```

**Note:** If you're accessing via WireGuard VPN, you may need to ensure the domain resolves correctly from mobile devices. Consider using a DNS provider that supports dynamic DNS if your IP changes.

### 4. Update swimTO Ingress

Edit `clusters/eldertree/swimto/ingress.yaml` and replace all instances of `swimto.yourdomain.com` with your actual domain:

```yaml
# Replace in swimto-api-public and swimto-web-public ingresses
host: swimto.yourdomain.com  # Change to your domain
```

### 5. Configure Firewall/Router

Ensure ports **80** (HTTP) and **443** (HTTPS) are open and forwarded to your Raspberry Pi:

- Port 80: Required for Let's Encrypt HTTP-01 challenge
- Port 443: Required for HTTPS access

### 6. Deploy Changes

Commit and push your changes. FluxCD will automatically sync:

```bash
git add clusters/eldertree/swimto/ingress.yaml
git add clusters/eldertree/core-infrastructure/issuers/helmrelease.yaml
git commit -m "feat: Enable Let's Encrypt for swimTO mobile location services"
git push
```

### 7. Verify Certificate Creation

Wait a few minutes, then check:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check ClusterIssuer
kubectl get clusterissuer letsencrypt-prod

# Check certificate status
kubectl get certificate -n swimto swimto-public-tls
kubectl describe certificate -n swimto swimto-public-tls

# Check certificate secret
kubectl get secret -n swimto swimto-public-tls
```

### 8. Test Access

From your mobile device (connected via WireGuard or on the same network):

1. Navigate to `https://swimto.yourdomain.com`
2. Verify the certificate is trusted (no warnings)
3. Test location services - they should now work!

## Troubleshooting

### Certificate Not Created

**Check cert-manager logs:**
```bash
kubectl logs -n cert-manager deployment/cert-manager
kubectl logs -n cert-manager deployment/cert-manager-webhook
```

**Common issues:**
- DNS not pointing to your server's public IP
- Ports 80/443 not accessible from internet
- Email address not updated in helmrelease.yaml
- Domain name not updated in ingress.yaml

### Certificate Created But Not Trusted

- Verify you're accessing via the public domain (not `.eldertree.local`)
- Check certificate details: `kubectl describe certificate -n swimto swimto-public-tls`
- Ensure mobile device can resolve the domain correctly

### Location Services Still Not Working

- Clear browser cache on mobile device
- Ensure you're accessing via HTTPS (not HTTP)
- Check browser console for errors
- Verify the certificate is valid and not expired

## Alternative: Using DuckDNS (Free Dynamic DNS)

If you don't have a domain, you can use DuckDNS:

1. Sign up at https://www.duckdns.org
2. Create a subdomain (e.g., `swimto.duckdns.org`)
3. Update DNS to point to your public IP
4. Update ingress.yaml to use `swimto.duckdns.org`
5. DuckDNS provides free subdomains that work with Let's Encrypt

## Current Configuration

- **Local domain (self-signed):** `swimto.eldertree.local` - Works for desktop browsers with certificate warnings
- **Public domain (Let's Encrypt):** `swimto.yourdomain.com` - Works for mobile browsers, trusted certificate
- **IP-based access:** Available via WireGuard VPN

All three access methods are configured and can be used simultaneously.


