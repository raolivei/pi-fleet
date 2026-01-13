# Pitanga Namespace

Infrastructure namespace for Pitanga LLC in the ElderTree k3s cluster.

## Purpose

This namespace provides the foundation for Pitanga LLC's infrastructure, including:

- **DNS Configuration**: Documentation and setup for custom domains
- **Email Infrastructure**: Email forwarding configuration
- **Future Expansion**: Ready for additional services as needed

## Current Status

- ✅ Namespace created
- ✅ Pitanga website deployed (pitanga-website) at `pitanga.cloud` and `www.pitanga.cloud`
- ✅ Northwaysignal website deployed (northwaysignal-website) at `northwaysignal.pitanga.cloud`
- ✅ Cloudflare Tunnel configured and connected (all sites accessible)
- ✅ DNS documentation for Framer site
- ✅ Email forwarding setup (Cloudflare Email Routing)
- ✅ All sites operational and accessible via HTTPS

**Last Updated**: January 12, 2026  
**Deployment Status**: Complete - See [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md) for details

## Structure

```text
pitanga/
├── namespace.yaml                          # Kubernetes namespace definition
├── kustomization.yaml                      # Kustomize resources
├── ghcr-secret-external.yaml               # GHCR image pull secret (ExternalSecret)
├── cloudflare-origin-cert-external.yaml    # Cloudflare Origin Certificate (ExternalSecret)
├── website-deployment.yaml                 # Pitanga website deployment
├── website-service.yaml                    # Pitanga website service
├── website-ingress.yaml                    # Pitanga website ingress (local + public)
├── northwaysignal-deployment.yaml          # Northwaysignal website deployment
├── northwaysignal-service.yaml             # Northwaysignal website service
├── northwaysignal-ingress.yaml             # Northwaysignal website ingress (public)
├── image-automation.yaml                   # Flux image automation
├── store-cert-in-vault.sh                 # Script to store certificate in Vault
├── create-ghcr-secret-direct.sh           # Quick script to create GHCR secret
├── setup-ghcr-secret.sh                    # Interactive GHCR secret setup
├── README.md                               # This file
├── DEPLOYMENT_SUMMARY.md                   # Complete deployment summary and status
├── DEPLOYMENT_CHECKLIST.md                # Step-by-step deployment guide
├── QUICK_FIX.md                            # Quick troubleshooting guide
├── MULTI_SITE_SETUP.md                     # Multi-site configuration documentation
├── CLOUDFLARE_ORIGIN_CERT_SETUP.md        # Cloudflare Origin Certificate setup
├── CLOUDFLARE_TUNNEL_SETUP.md             # Cloudflare Tunnel configuration guide
├── FRAMER_DNS_SETUP.md                     # DNS configuration for Framer site
├── CLOUDFLARE_EMAIL_SETUP.md              # Cloudflare Email Routing setup
└── IMPROVMX_SETUP.md                       # Legacy email setup (deprecated)
```

## Documentation

### DNS Setup

- **[FRAMER_DNS_SETUP.md](FRAMER_DNS_SETUP.md)**: Complete guide for configuring `www.pitanga.cloud` and `pitanga.cloud` to work with Framer

### Website Setup

- **[MULTI_SITE_SETUP.md](MULTI_SITE_SETUP.md)**: Complete guide for multi-site configuration (pitanga.cloud and northwaysignal.pitanga.cloud)
- **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)**: Step-by-step deployment and verification checklist
- **[QUICK_FIX.md](QUICK_FIX.md)**: Quick troubleshooting guide for common issues

### Email Setup

- **[CLOUDFLARE_EMAIL_SETUP.md](CLOUDFLARE_EMAIL_SETUP.md)**: Guide for setting up email forwarding via Cloudflare Email Routing (Recommended)
- **[IMPROVMX_SETUP.md](IMPROVMX_SETUP.md)**: Legacy guide for ImprovMX (deprecated)

### Website Deployments

This namespace hosts two websites simultaneously:

#### Pitanga Website

- **Image**: `ghcr.io/raolivei/pitanga-website:latest`
- **Automation**: Managed via Flux Image Automation (semver: `0.1.x`)
- **Local Access**: `https://pitanga.eldertree.local` (self-signed cert)
- **Public Access**: `https://pitanga.cloud` and `https://www.pitanga.cloud` (Cloudflare Origin Certificate)
- **Deployment**: Managed via FluxCD GitOps
- **Source**: [pitanga-website repository](../../../../pitanga-website/)

#### Northwaysignal Website

- **Image**: `ghcr.io/raolivei/northwaysignal-website:latest`
- **Public Access**: `https://northwaysignal.pitanga.cloud` (Cloudflare Origin Certificate)
- **Deployment**: Managed via FluxCD GitOps
- **Source**: [northwaysignal-website repository](../../../../northwaysignal-website/)

See [MULTI_SITE_SETUP.md](MULTI_SITE_SETUP.md) for detailed documentation on the multi-site configuration.

**Prerequisites**:

- Cloudflare Origin Certificate stored in Vault and synced to Kubernetes secret: `pitanga-cloudflare-origin-tls`
  - Stored in Vault at: `secret/pitanga/cloudflare-origin-cert`
  - Synced via ExternalSecret: `cloudflare-origin-cert-external.yaml`
  - See [CLOUDFLARE_ORIGIN_CERT_SETUP.md](CLOUDFLARE_ORIGIN_CERT_SETUP.md) for setup instructions
- GHCR secret (`ghcr-secret`) configured in namespace for image pulls
  - Managed via External Secrets Operator (syncs from Vault)
  - Secret path in Vault: `secret/pitanga/ghcr-token`

## Quick Start

### 1. Deploy Namespace

The namespace is managed via FluxCD GitOps. To deploy manually:

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl apply -k .
```

**⚠️ Important**: Before deploying, ensure:

- GHCR secret is created (see [QUICK_FIX.md](QUICK_FIX.md) or run `./create-ghcr-secret-direct.sh`)
- Cloudflare Origin Certificate is synced from Vault (check ExternalSecret status)

For detailed deployment steps, see [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md).

### 2. Configure DNS

Follow the guide in [FRAMER_DNS_SETUP.md](FRAMER_DNS_SETUP.md) to:

- Configure `www.pitanga.cloud` CNAME in Cloudflare
- Configure `pitanga.cloud` apex domain
- Set up SSL/TLS

### 3. Configure Email

Follow the guide in [CLOUDFLARE_EMAIL_SETUP.md](CLOUDFLARE_EMAIL_SETUP.md) to:

- Enable Email Routing in Cloudflare
- Configure forwarding to `rafa.oliveira1@gmail.com`
- Set up custom addresses for `contact` and `raolivei`

## Future Expansion

This namespace is prepared for future services:

- **Ingress Resources**: For services hosted in the cluster
- **Secrets Management**: Via External Secrets Operator
- **Monitoring**: Service monitoring and alerts
- **Mailu**: Self-hosted email server (replacing ImprovMX)

## Standards Compliance

This namespace follows workspace conventions:

- **Naming**: Lowercase with hyphens (`pitanga`)
- **Labels**: `app: pitanga`, `environment: production`
- **Structure**: Consistent with other namespaces (`journey`, `swimto`)
- **Documentation**: Clear, actionable guides following org standards
- **GitOps**: Managed via FluxCD

## Related Resources

- [Workspace Conventions](../../../../PROJECT_CONVENTIONS.md)
- [ElderTree Cluster Documentation](../../README.md)
- [External-DNS Configuration](../../dns-services/external-dns/README.md)

## Notes

- Both websites are deployed and running in the cluster simultaneously
- DNS and email are managed via Cloudflare (external to cluster)
- Local DNS records are managed by External-DNS via Pi-hole
- Both sites share the same Cloudflare Origin Certificate
- Future services can be added as needed
