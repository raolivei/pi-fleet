# Eldertree Docs

Kubernetes deployment for the eldertree documentation and runbook site.

## Overview

This deploys the VitePress-based documentation site from [eldertree-docs](https://github.com/raolivei/eldertree-docs) repository.

## Access

| URL | Description |
|-----|-------------|
| `https://docs.eldertree.xyz` | Public access via GitHub Pages |
| `https://docs.eldertree.local` | Local network access via this deployment |

## Deployment

The site is automatically deployed when:

1. **GitHub Pages**: On push to main branch (via GitHub Actions)
2. **Kubernetes**: Docker image is built and pushed to ghcr.io

To manually update the Kubernetes deployment:

```bash
# Apply manifests
kubectl apply -k clusters/eldertree/eldertree-docs/

# Force image pull
kubectl rollout restart deployment/eldertree-docs -n eldertree-docs
```

## DNS Configuration

For local access, add to Pi-hole or /etc/hosts:

```
192.168.2.x  docs.eldertree.local
```

Where `192.168.2.x` is the Traefik ingress IP.

## Image

- Registry: `ghcr.io/raolivei/eldertree-docs`
- Platform: `linux/arm64` (eldertree cluster is ARM-only)


