# Pitanga Namespace

Infrastructure namespace for Pitanga LLC in the ElderTree k3s cluster.

## Purpose

This namespace provides the foundation for Pitanga LLC's infrastructure, including:

- **DNS Configuration**: Documentation and setup for custom domains
- **Email Infrastructure**: Email forwarding configuration
- **Future Expansion**: Ready for additional services as needed

## Current Status

- ✅ Namespace created
- ✅ Website deployed (pitanga-website)
- ✅ DNS documentation for Framer site
- ✅ Email forwarding setup (Cloudflare Email Routing)

## Structure

```
pitanga/
├── namespace.yaml              # Kubernetes namespace definition
├── kustomization.yaml          # Kustomize resources
├── website-deployment.yaml     # Website deployment
├── website-service.yaml        # Website service
├── website-ingress.yaml        # Website ingress (local + public)
├── image-automation.yaml       # Flux image automation
├── README.md                   # This file
├── FRAMER_DNS_SETUP.md         # DNS configuration for Framer site
├── CLOUDFLARE_EMAIL_SETUP.md   # Cloudflare Email Routing setup
└── IMPROVMX_SETUP.md           # Legacy email setup (deprecated)
```

## Documentation

### DNS Setup

- **[FRAMER_DNS_SETUP.md](FRAMER_DNS_SETUP.md)**: Complete guide for configuring `www.pitanga.cloud` and `pitanga.cloud` to work with Framer

### Email Setup

- **[CLOUDFLARE_EMAIL_SETUP.md](CLOUDFLARE_EMAIL_SETUP.md)**: Guide for setting up email forwarding via Cloudflare Email Routing (Recommended)
- **[IMPROVMX_SETUP.md](IMPROVMX_SETUP.md)**: Legacy guide for ImprovMX (deprecated)

### Website Deployment

The Pitanga website is deployed as a Next.js static site served via nginx:

- **Image**: `ghcr.io/raolivei/pitanga-website:latest`
- **Automation**: Managed via Flux Image Automation (semver: `0.1.x`)
- **Local Access**: `https://pitanga.eldertree.local` (self-signed cert)
- **Public Access**: `https://pitanga.cloud` and `https://www.pitanga.cloud` (Cloudflare Origin Certificate)
- **Deployment**: Managed via FluxCD GitOps
- **Source**: [pitanga-website repository](../../../../pitanga-website/)

**Prerequisites**:

- Cloudflare Origin Certificate stored as Kubernetes secret: `pitanga-cloudflare-origin-tls`
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

- Website is deployed and running in the cluster
- DNS and email are managed via Cloudflare (external to cluster)
- Local DNS records are managed by External-DNS via Pi-hole
- Future services can be added as needed
