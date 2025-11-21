# Cloudflare Free Domain Options for eldertree

This guide covers free domain options available through Cloudflare for your eldertree k3s cluster.

## Overview

Cloudflare offers several options for getting domains for your eldertree cluster:

1. **Cloudflare Registrar** - Free domain registration (limited TLDs)
2. **Cloudflare DNS** - Free DNS management for existing domains
3. **Cloudflare Tunnel** - Free tunnel service (no port forwarding needed)

## Option 1: Cloudflare Registrar (Free Domains)

Cloudflare Registrar offers **free domain registration** for certain TLDs, but availability is limited.

### Available Free TLDs

Cloudflare occasionally offers promotions for free domains. Check their current offerings:

- Visit: https://www.cloudflare.com/products/registrar/
- Look for promotional pricing or free domain offers

**Note:** Free domain promotions are typically:
- Limited-time offers
- May require annual renewal fees
- Subject to availability

### Registration Process

1. **Sign up for Cloudflare account** (free)
   - Go to https://dash.cloudflare.com/sign-up
   - Use your email address

2. **Search for available domains**
   - Use Cloudflare's domain search tool
   - Look for domains matching `eldertree` theme:
     - `eldertree.dev` (if available)
     - `eldertree.tech` (if available)
     - `eldertree.site` (if available)
     - `eldertree.online` (if available)

3. **Register the domain**
   - Add to cart and checkout
   - Cloudflare charges at-cost pricing (often cheaper than other registrars)

### Cost

- **Registration**: Free (during promotions) or at-cost pricing
- **Renewal**: At-cost pricing (typically $8-15/year for common TLDs)
- **DNS**: Free forever
- **SSL/TLS**: Free forever (Cloudflare SSL)

## Option 2: Use Existing Domain with Cloudflare DNS (Recommended)

If you already have a domain (from any registrar), you can use Cloudflare's free DNS service.

### Benefits

- ✅ **Free DNS management**
- ✅ **Free SSL/TLS certificates** (Cloudflare SSL)
- ✅ **DDoS protection**
- ✅ **CDN capabilities**
- ✅ **Analytics**
- ✅ **Works with Let's Encrypt** (for cert-manager)

### Setup Steps

1. **Add Domain to Cloudflare**
   - Log in to Cloudflare Dashboard
   - Click "Add a Site"
   - Enter your domain name
   - Select Free plan

2. **Update Nameservers**
   - Cloudflare will provide nameservers (e.g., `ns1.cloudflare.com`)
   - Update nameservers at your domain registrar
   - Wait for DNS propagation (usually 24-48 hours)

3. **Configure DNS Records**
   - Add A records pointing to your public IP:
     ```
     eldertree.yourdomain.com     A    <your-public-ip>
     canopy.yourdomain.com        A    <your-public-ip>
     swimto.yourdomain.com        A    <your-public-ip>
     api.swimto.yourdomain.com    A    <your-public-ip>
     ```

4. **Enable SSL/TLS**
   - Go to SSL/TLS settings
   - Set encryption mode to "Full" or "Full (strict)"
   - This enables HTTPS between Cloudflare and your server

5. **Configure cert-manager for Let's Encrypt**
   - Your existing cert-manager setup will work
   - Use HTTP-01 challenge (requires ports 80/443 open)
   - Or use DNS-01 challenge with Cloudflare API token (no port forwarding needed)

## Option 3: Cloudflare Tunnel (Best for Home Networks)

Cloudflare Tunnel (formerly Argo Tunnel) provides **free** secure tunnels without port forwarding.

### Benefits

- ✅ **No port forwarding required**
- ✅ **Works behind NAT/firewall**
- ✅ **Free SSL/TLS certificates**
- ✅ **DDoS protection**
- ✅ **Works with dynamic IPs**

### How It Works

1. Install `cloudflared` on your Raspberry Pi
2. Create a tunnel that connects your cluster to Cloudflare
3. Configure DNS records to point to the tunnel
4. Traffic flows: Internet → Cloudflare → Tunnel → Your Cluster

### Setup Steps

1. **Install cloudflared**
   ```bash
   # On Raspberry Pi (eldertree)
   curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o /usr/local/bin/cloudflared
   chmod +x /usr/local/bin/cloudflared
   ```

2. **Create Tunnel**
   ```bash
   cloudflared tunnel login
   cloudflared tunnel create eldertree
   ```

3. **Configure Tunnel**
   Create `~/.cloudflared/config.yml`:
   ```yaml
   tunnel: <tunnel-id>
   credentials-file: /root/.cloudflared/<tunnel-id>.json
   
   ingress:
     - hostname: canopy.yourdomain.com
       service: http://localhost:80
     - hostname: swimto.yourdomain.com
       service: http://localhost:80
     - service: http_status:404
   ```

4. **Run Tunnel**
   ```bash
   cloudflared tunnel run eldertree
   ```

5. **Configure DNS**
   - In Cloudflare Dashboard, add CNAME records:
     ```
     canopy.yourdomain.com    CNAME    <tunnel-id>.cfargotunnel.com
     swimto.yourdomain.com    CNAME    <tunnel-id>.cfargotunnel.com
     ```

6. **Deploy as Kubernetes Service** (Optional)
   - Create a Deployment and Service for cloudflared
   - Use ConfigMap for tunnel configuration
   - See example below

### Kubernetes Integration

You can deploy Cloudflare Tunnel as a Kubernetes deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflared
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
        - tunnel
        - run
        - --config
        - /etc/cloudflared/config.yml
        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared
        - name: credentials
          mountPath: /root/.cloudflared
      volumes:
      - name: config
        configMap:
          name: cloudflared-config
      - name: credentials
        secret:
          secretName: cloudflared-credentials
```

## Option 4: Free Subdomain Services

If you don't want to register a domain, you can use free subdomain services:

### DuckDNS (Recommended)

- **URL**: https://www.duckdns.org
- **Free subdomains**: `*.duckdns.org`
- **Works with Let's Encrypt**: ✅ Yes
- **Dynamic DNS**: ✅ Yes (updates automatically)

**Setup:**
1. Sign up at DuckDNS
2. Create subdomain: `eldertree.duckdns.org`
3. Update DNS to point to your IP
4. Use in ingress.yaml: `eldertree.duckdns.org`

### No-IP

- **URL**: https://www.noip.com
- **Free subdomains**: `*.ddns.net`, `*.hopto.org`, etc.
- **Works with Let's Encrypt**: ✅ Yes
- **Dynamic DNS**: ✅ Yes (requires monthly confirmation)

### Freenom (Free .tk, .ml, .ga domains)

- **URL**: https://www.freenom.com
- **Free TLDs**: `.tk`, `.ml`, `.ga`, `.cf`, `.gq`
- **Works with Let's Encrypt**: ✅ Yes
- **Note**: Some registrars may have restrictions

## Recommended Approach for eldertree

### For Production/Public Access

**Best Option: Cloudflare Tunnel**

1. ✅ No port forwarding needed
2. ✅ Works with dynamic IPs
3. ✅ Free SSL/TLS
4. ✅ DDoS protection
5. ✅ Easy to set up

**Steps:**
1. Get a free domain (Cloudflare Registrar, DuckDNS, or existing domain)
2. Set up Cloudflare Tunnel
3. Configure DNS records
4. Update ingress.yaml files to use public domain
5. cert-manager will automatically get Let's Encrypt certificates

### For Development/Testing

**Current Setup: `.eldertree.local`**

- Keep using `.eldertree.local` for internal development
- Add public domain for production/mobile access
- Both can coexist in the same ingress.yaml

## Integration with eldertree Cluster

### Update Ingress Resources

Once you have a domain, update your ingress files:

```yaml
# Example: clusters/eldertree/swimto/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: swimto-web-public
  namespace: swimto
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    external-dns.alpha.kubernetes.io/hostname: swimto.yourdomain.com
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - swimto.yourdomain.com
      secretName: swimto-public-tls
  rules:
    - host: swimto.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: swimto-web-service
                port:
                  number: 3000
```

### Update cert-manager Email

Edit `clusters/eldertree/core-infrastructure/issuers/helmrelease.yaml`:

```yaml
acme:
  enabled: true
  email: "your-email@example.com"  # Update this!
  server: https://acme-v02.api.letsencrypt.org/directory
```

## Cost Comparison

| Option | Registration | Annual Cost | DNS | SSL | Port Forwarding |
|--------|-------------|-------------|-----|-----|----------------|
| Cloudflare Registrar | Free/At-cost | $8-15/year | Free | Free | Required |
| Cloudflare DNS | N/A | $0 | Free | Free | Required |
| Cloudflare Tunnel | N/A | $0 | Free | Free | **Not Required** |
| DuckDNS | Free | $0 | Free | Via Let's Encrypt | Required |
| Freenom | Free | $0 | Free | Via Let's Encrypt | Required |

## Next Steps

1. **Choose your domain option** (recommended: Cloudflare Tunnel)
2. **Set up domain/DNS** following the chosen option
3. **Update ingress.yaml files** with your domain
4. **Deploy changes** via FluxCD
5. **Verify certificates** are created automatically

## References

- [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [DuckDNS](https://www.duckdns.org)
- [Let's Encrypt](https://letsencrypt.org)
- [cert-manager DNS-01 Challenge](https://cert-manager.io/docs/configuration/acme/dns01/)



