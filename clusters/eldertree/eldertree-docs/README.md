# Eldertree Docs + Audio

Kubernetes deployment for the eldertree documentation site and audio hosting.

## Overview

This deploys:
- VitePress-based documentation from [eldertree-docs](https://github.com/raolivei/eldertree-docs)
- Audio file hosting for ElderTree blog recordings

## Access

| URL | Description |
|-----|-------------|
| `https://docs.eldertree.xyz` | Public access via GitHub Pages |
| `https://docs.eldertree.local` | Local network access |
| `https://docs.eldertree.local/audio/` | Audio file directory |
| `https://docs.eldertree.local/feed.xml` | RSS feed for podcast apps |

## Audio Hosting

Audio files are served from a 20GB NVMe-backed PVC at `/audio/`.

**Policy:** All audio uses the author's real human voice. No AI TTS.

### Uploading Audio

```bash
export KUBECONFIG=~/.kube/config-eldertree
POD=$(kubectl get pods -n eldertree-docs -l app.kubernetes.io/name=eldertree-docs -o jsonpath='{.items[0].metadata.name}')

# Create audio directory (first time)
kubectl exec -n eldertree-docs $POD -- mkdir -p /data/audio

# Upload a file
kubectl cp ./episode.mp3 eldertree-docs/$POD:/data/audio/

# Verify
kubectl exec -n eldertree-docs $POD -- ls -la /data/audio/
```

### File Naming

```
eldertree-audio-YYYY-MM-DD-title-slug.mp3
```

## Deployment

```bash
# Apply manifests
kubectl apply -k clusters/eldertree/eldertree-docs/

# Force image pull
kubectl rollout restart deployment/eldertree-docs -n eldertree-docs
```

## DNS Configuration

Add to Pi-hole or /etc/hosts:

```
192.168.2.200  docs.eldertree.local
```

## Image

- Registry: `ghcr.io/raolivei/eldertree-docs`
- Platform: `linux/arm64` (ARM-only cluster)


