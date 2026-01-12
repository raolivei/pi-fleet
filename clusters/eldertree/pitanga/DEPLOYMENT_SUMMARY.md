# Pitanga Deployment Summary

**Date**: January 12, 2026  
**Status**: ✅ Complete - All sites operational

## Overview

Successfully deployed and configured two websites in the `pitanga` namespace on the `eldertree` Kubernetes cluster:

1. **pitanga-website** - Available at `pitanga.cloud` and `www.pitanga.cloud`
2. **northwaysignal-website** - Available at `northwaysignal.pitanga.cloud`

Both sites are publicly accessible via HTTPS through Cloudflare Tunnel.

## What Was Deployed

### 1. Pitanga Website
- **Image**: `ghcr.io/raolivei/pitanga-website:latest` (ARM64)
- **Namespace**: `pitanga`
- **Deployment**: `pitanga-website`
- **Service**: `pitanga-website-service` (ClusterIP, port 80)
- **Ingress**: 
  - Local: `pitanga.eldertree.local`
  - Public: `pitanga.cloud`, `www.pitanga.cloud`
- **Health Check**: `/health` endpoint

### 2. Northwaysignal Website
- **Image**: `ghcr.io/raolivei/northwaysignal-website:latest` (ARM64)
- **Namespace**: `pitanga`
- **Deployment**: `northwaysignal-website`
- **Service**: `northwaysignal-website-service` (ClusterIP, port 80)
- **Ingress**: `northwaysignal.pitanga.cloud`
- **Health Check**: `/api/health` endpoint

## Issues Resolved

### 1. GHCR Image Pull Secret
- **Issue**: Pods failing to pull images from GitHub Container Registry
- **Solution**: Created `ghcr-secret` in namespace using External Secrets Operator
- **Status**: ✅ Resolved

### 2. Nginx Permission Errors
- **Issue**: `pitanga-website` pod in CrashLoopBackOff due to permission denied errors for `/var/cache/nginx` and `/var/run`
- **Solution**: Added `emptyDir` volume mounts for cache and runtime directories
- **Files Modified**: `website-deployment.yaml`
- **Status**: ✅ Resolved

### 3. Cloudflare Tunnel Configuration
- **Issue**: Tunnel missing ingress rules for `pitanga.cloud` and `northwaysignal.pitanga.cloud`
- **Solution**: Updated Cloudflare Tunnel configuration via API to include all three domains
- **API Token**: Updated permissions to include "Cloudflare Tunnel → Edit"
- **Status**: ✅ Resolved

### 4. Cloudflare Tunnel DNS Timeout
- **Issue**: Tunnel failing to connect due to cluster DNS (10.43.0.10) timeout
- **Solution**: Updated `TUNNEL_DNS_UPSTREAM` environment variable to use only public DNS servers (8.8.8.8,1.1.1.1)
- **Method**: Patched deployment directly via `kubectl patch`
- **Status**: ✅ Resolved

### 5. Cloudflare Origin Certificate
- **Issue**: TLS secret not found, causing SSL handshake failures
- **Solution**: Created TLS secret `pitanga-cloudflare-origin-tls` from Terraform output
- **Status**: ✅ Resolved

## Configuration Changes

### Kubernetes Resources Created/Modified

1. **Deployments**:
   - `pitanga-website` - Added volume mounts for Nginx cache/tmp
   - `northwaysignal-website` - Created new deployment

2. **Services**:
   - `pitanga-website-service` - Existing
   - `northwaysignal-website-service` - Created new service

3. **Ingress**:
   - `pitanga-website-public` - Existing (pitanga.cloud, www.pitanga.cloud)
   - `northwaysignal-website-public` - Created new ingress

4. **Secrets**:
   - `ghcr-secret` - Created for GitHub Container Registry authentication
   - `pitanga-cloudflare-origin-tls` - Created for Cloudflare Origin Certificate

### Cloudflare Configuration

1. **Tunnel Configuration** (`eldertree` tunnel):
   - Added ingress rule for `pitanga.cloud` → `http://10.43.23.214:80`
   - Added ingress rule for `www.pitanga.cloud` → `http://10.43.23.214:80`
   - Added ingress rule for `northwaysignal.pitanga.cloud` → `http://10.43.23.214:80`
   - Updated via Cloudflare API (bypassing Terraform due to token permission issues)

2. **Terraform Configuration**:
   - Updated `terraform/cloudflare.tf` to include new ingress rules
   - Note: Terraform apply failed due to API token permissions, but configuration is correct

3. **Cloudflared Deployment**:
   - Updated `TUNNEL_DNS_UPSTREAM` from `10.43.0.10,8.8.8.8,1.1.1.1` to `8.8.8.8,1.1.1.1`
   - Fixed via `kubectl patch` command

## Verification

### Tunnel Status
- **Status**: `healthy`
- **Connections**: 4 active connections to Cloudflare edge (yyz01, yyz04)
- **Last Active**: 2026-01-12T02:44:05Z

### Site Accessibility
All sites tested and confirmed working:

```bash
# pitanga.cloud
curl -I https://pitanga.cloud
# HTTP/2 200 ✅

# www.pitanga.cloud
curl -I https://www.pitanga.cloud
# HTTP/2 200 ✅

# northwaysignal.pitanga.cloud
curl -I https://northwaysignal.pitanga.cloud
# HTTP/2 200 ✅
```

### Pod Status
```bash
kubectl get pods -n pitanga
# pitanga-website-64d7fdf86-dssbl         1/1     Running   0
# northwaysignal-website-86fc7c858-x4p7j   1/1     Running   0
```

## Files Created/Modified

### New Files
- `northwaysignal-deployment.yaml`
- `northwaysignal-service.yaml`
- `northwaysignal-ingress.yaml`
- `cloudflare-origin-cert-external.yaml`
- `create-cert-secret.sh`
- `create-ghcr-secret-direct.sh`
- Various documentation files (see README.md)

### Modified Files
- `website-deployment.yaml` - Added volume mounts for Nginx
- `kustomization.yaml` - Added northwaysignal resources
- `terraform/cloudflare.tf` - Added tunnel ingress rules
- `scripts/update-cloudflare-tunnel-via-api.sh` - Updated with new routes

## Key Learnings

1. **Cloudflare Tunnel DNS**: The tunnel needs reliable DNS resolution. Cluster DNS timeouts can prevent connection establishment.

2. **Nginx Permissions**: Nginx containers running as non-root need write access to cache and runtime directories via volume mounts.

3. **API Token Permissions**: Cloudflare API tokens need specific permissions for tunnel management. The token was updated to include "Cloudflare Tunnel → Edit".

4. **Tunnel Connection Time**: After configuration changes, the tunnel can take 2-5 minutes to fully establish connections.

## Next Steps (Optional)

1. **Fix Vault Connection**: ClusterSecretStore Vault connection timeout (non-blocking, External Secrets can be created manually)
2. **Automate Tunnel Updates**: Consider automating tunnel configuration updates via Terraform once token permissions are fixed
3. **Monitor**: Set up monitoring/alerting for site availability
4. **Backup**: Ensure certificate secrets are backed up

## References

- [MULTI_SITE_SETUP.md](MULTI_SITE_SETUP.md) - Multi-site configuration guide
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Deployment checklist
- [QUICK_FIX.md](QUICK_FIX.md) - Troubleshooting guide
- [CLOUDFLARE_ORIGIN_CERT_SETUP.md](CLOUDFLARE_ORIGIN_CERT_SETUP.md) - Certificate setup
- [CLOUDFLARE_TUNNEL_SETUP.md](CLOUDFLARE_TUNNEL_SETUP.md) - Tunnel setup guide

