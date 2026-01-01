# Framer DNS Setup for pitanga.cloud

This guide explains how to configure DNS records in Cloudflare to connect your Framer site to the `pitanga.cloud` domain.

## Prerequisites

1. Domain `pitanga.cloud` added to Cloudflare account
2. Nameservers configured at your domain registrar to point to Cloudflare
3. Framer site created and published
4. Access to Cloudflare Dashboard

## Overview

Framer requires CNAME records to connect your custom domain. We'll configure:
- `www.pitanga.cloud` → CNAME to Framer
- `pitanga.cloud` (apex domain) → CNAME flattening or A record

## Step 1: Get Framer Domain Information

1. **Log in to Framer**
   - Go to https://framer.com
   - Open your site project

2. **Navigate to Site Settings**
   - Click on your site name
   - Go to **Settings** → **Custom Domain**

3. **Add Custom Domain**
   - Enter `www.pitanga.cloud`
   - Framer will provide you with a CNAME target (e.g., `www.pitanga.cloud.cdn.framer.com` or similar)
   - Note down this CNAME target value

4. **Add Apex Domain (Optional)**
   - If Framer supports apex domains, add `pitanga.cloud`
   - Note down any additional configuration needed

## Step 2: Configure DNS in Cloudflare

### Option A: www.pitanga.cloud (CNAME)

1. **Log in to Cloudflare Dashboard**
   - Go to https://dash.cloudflare.com
   - Select `pitanga.cloud` domain

2. **Navigate to DNS Records**
   - Go to **DNS** → **Records**

3. **Add CNAME Record for www**
   - Click **Add record**
   - **Type**: CNAME
   - **Name**: `www`
   - **Target**: (The CNAME target from Framer, e.g., `www.pitanga.cloud.cdn.framer.com`)
   - **Proxy status**: Proxied (orange cloud) - Recommended for HTTPS and DDoS protection
   - **TTL**: Auto
   - Click **Save**

### Option B: pitanga.cloud (Apex Domain)

For the apex domain (`pitanga.cloud`), you have two options:

#### Option B1: CNAME Flattening (Recommended)

Cloudflare automatically flattens CNAME records at the apex. This is the easiest method:

1. **Add CNAME Record**
   - **Type**: CNAME
   - **Name**: `@` (or `pitanga.cloud`)
   - **Target**: (The CNAME target from Framer)
   - **Proxy status**: Proxied (orange cloud)
   - **TTL**: Auto
   - Click **Save**

   Cloudflare will automatically handle CNAME flattening.

#### Option B2: A Record (If Framer Provides IP)

If Framer provides an IP address for the apex domain:

1. **Add A Record**
   - **Type**: A
   - **Name**: `@` (or `pitanga.cloud`)
   - **IPv4 address**: (IP address from Framer)
   - **Proxy status**: Proxied (orange cloud)
   - **TTL**: Auto
   - Click **Save**

## Step 3: Configure SSL/TLS in Cloudflare

1. **Navigate to SSL/TLS Settings**
   - Go to **SSL/TLS** → **Overview**

2. **Set Encryption Mode**
   - Select **Full (strict)** or **Full**
   - This ensures HTTPS is enabled end-to-end

3. **Enable Automatic HTTPS Rewrites**
   - Go to **SSL/TLS** → **Edge Certificates**
   - Enable **Always Use HTTPS**
   - Enable **Automatic HTTPS Rewrites**

## Step 4: Verify DNS Configuration

### Check DNS Propagation

```bash
# Check www subdomain
dig www.pitanga.cloud

# Check apex domain
dig pitanga.cloud

# Both should resolve to Cloudflare IPs (if proxied) or Framer IPs
```

### Verify in Framer

1. **Check Domain Status in Framer**
   - Go to **Settings** → **Custom Domain**
   - Verify domain shows as "Connected" or "Active"
   - Wait a few minutes for DNS propagation (can take up to 48 hours, usually much faster)

2. **Test Website Access**
   - Visit `https://www.pitanga.cloud`
   - Visit `https://pitanga.cloud`
   - Both should load your Framer site with valid SSL certificate

## Step 5: Redirect Configuration (Optional)

If you want to redirect `pitanga.cloud` to `www.pitanga.cloud`:

1. **Create Page Rule in Cloudflare**
   - Go to **Rules** → **Page Rules**
   - Click **Create Page Rule**
   - **URL**: `pitanga.cloud/*`
   - **Setting**: Forwarding URL
   - **Status Code**: 301 (Permanent Redirect)
   - **Destination URL**: `https://www.pitanga.cloud/$1`
   - Click **Save and Deploy**

## Troubleshooting

### DNS Not Resolving

1. **Check DNS Records**
   ```bash
   # Verify records exist
   dig www.pitanga.cloud
   dig pitanga.cloud
   ```

2. **Check Cloudflare Status**
   - Ensure domain is active in Cloudflare
   - Verify nameservers are correctly configured at registrar

3. **Wait for Propagation**
   - DNS changes can take up to 48 hours (usually much faster)
   - Use `dig` or online DNS checkers to verify

### SSL Certificate Issues

1. **Check SSL/TLS Mode**
   - Must be "Full" or "Full (strict)"
   - "Flexible" won't work properly with Framer

2. **Verify Proxy Status**
   - DNS records should have orange cloud (proxied)
   - Gray cloud = DNS only (no SSL from Cloudflare)

3. **Check Framer Domain Status**
   - Verify domain is connected in Framer dashboard
   - Check for any error messages

### Website Not Loading

1. **Check Framer Site Status**
   - Ensure site is published in Framer
   - Verify custom domain is enabled in Framer settings

2. **Check Cloudflare Settings**
   - Review Page Rules for any conflicting rules
   - Check Firewall rules for any blocks

3. **Test Direct Access**
   - Try accessing Framer's default domain to verify site is working
   - Compare behavior between default and custom domain

## Security Best Practices

- **Always Use HTTPS**: Enable "Always Use HTTPS" in Cloudflare
- **Proxy Enabled**: Keep orange cloud (proxied) for DDoS protection
- **Full (strict) SSL**: Use strict mode for maximum security
- **Regular Monitoring**: Check Cloudflare Analytics for any issues

## References

- [Framer Custom Domain Documentation](https://www.framer.com/help/articles/custom-domain/)
- [Cloudflare DNS Documentation](https://developers.cloudflare.com/dns/)
- [Cloudflare SSL/TLS Modes](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)
- [CNAME Flattening](https://developers.cloudflare.com/dns/additional-options/cname-flattening/)

