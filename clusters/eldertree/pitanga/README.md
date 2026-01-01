# Pitanga Namespace

Infrastructure namespace for Pitanga LLC in the ElderTree k3s cluster.

## Purpose

This namespace provides the foundation for Pitanga LLC's infrastructure, including:

- **DNS Configuration**: Documentation and setup for custom domains
- **Email Infrastructure**: Email forwarding configuration
- **Future Expansion**: Ready for additional services as needed

## Current Status

- ✅ Namespace created
- ✅ DNS documentation for Framer site
- ✅ Email forwarding setup (ImprovMX)

## Structure

```
pitanga/
├── namespace.yaml              # Kubernetes namespace definition
├── kustomization.yaml          # Kustomize resources
├── README.md                   # This file
├── FRAMER_DNS_SETUP.md         # DNS configuration for Framer site
└── IMPROVMX_SETUP.md           # Email forwarding setup guide
```

## Documentation

### DNS Setup

- **[FRAMER_DNS_SETUP.md](FRAMER_DNS_SETUP.md)**: Complete guide for configuring `www.pitanga.cloud` and `pitanga.cloud` to work with Framer

### Email Setup

- **[IMPROVMX_SETUP.md](IMPROVMX_SETUP.md)**: Guide for setting up `contact@pitanga.cloud` email forwarding via ImprovMX

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

Follow the guide in [IMPROVMX_SETUP.md](IMPROVMX_SETUP.md) to:
- Set up ImprovMX account
- Configure MX records in Cloudflare
- Forward `contact@pitanga.cloud` to Gmail

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

- This namespace is currently infrastructure-only (no running pods)
- DNS and email are managed via Cloudflare (external to cluster)
- Future services can be added as needed

