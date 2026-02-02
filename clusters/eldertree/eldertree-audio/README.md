# ElderTree Audio System

Minimal audio hosting infrastructure for ElderTree blog recordings.

## Overview

- **URL**: `https://audio.eldertree.local`
- **Storage**: 20GB Longhorn PVC (replicated)
- **Server**: nginx (static file server)
- **Architecture**: ARM64 (Raspberry Pi compatible)

## Policy

All audio uses the author's real human voice. No AI TTS. No voice cloning.

See `pi-fleet-blog/docs/AUDIO_SYSTEM.md` for the complete system specification.

## Endpoints

| Path | Description |
|------|-------------|
| `/` | Landing page |
| `/audio/` | Audio file directory listing |
| `/feed.xml` | RSS feed for podcast apps |
| `/health` | Health check endpoint |

## Uploading Audio Files

Audio files are stored in the PVC at `/data/audio/`. To upload:

### Method 1: kubectl cp (Recommended)

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Get pod name
POD=$(kubectl get pods -n eldertree-audio -l app=eldertree-audio -o jsonpath='{.items[0].metadata.name}')

# Upload a file
kubectl cp ./my-episode.mp3 eldertree-audio/$POD:/data/audio/

# Upload multiple files
for f in *.mp3; do
  kubectl cp "$f" eldertree-audio/$POD:/data/audio/
done

# Verify
kubectl exec -n eldertree-audio $POD -- ls -la /data/audio/
```

### Method 2: Temporary upload pod

```bash
# Create a temporary pod with the same PVC
kubectl run audio-upload -n eldertree-audio --rm -it \
  --image=alpine \
  --overrides='{"spec":{"containers":[{"name":"audio-upload","image":"alpine","stdin":true,"tty":true,"volumeMounts":[{"name":"audio","mountPath":"/data"}]}],"volumes":[{"name":"audio","persistentVolumeClaim":{"claimName":"audio-storage"}}]}}' \
  -- sh

# Then from another terminal, copy files to this pod
kubectl cp ./my-episode.mp3 eldertree-audio/audio-upload:/data/audio/
```

## RSS Feed

Create `/data/feed.xml` manually or use a script:

```bash
# Create a basic feed (run inside the pod or locally then copy)
cat > feed.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Building Eldertree</title>
    <description>The real journey of running Kubernetes on Raspberry Pis</description>
    <link>https://audio.eldertree.local</link>
    <language>en-us</language>
    <itunes:author>Rafael Oliveira</itunes:author>
    <itunes:category text="Technology"/>
    <!-- Add items here -->
  </channel>
</rss>
EOF

# Copy to pod
kubectl cp feed.xml eldertree-audio/$POD:/data/feed.xml
```

## File Naming Convention

```
eldertree-audio-YYYY-MM-DD-title-slug.mp3
```

Example: `eldertree-audio-2026-02-15-the-beginning.mp3`

## Monitoring

```bash
# Check pod status
kubectl get pods -n eldertree-audio

# View logs
kubectl logs -n eldertree-audio -l app=eldertree-audio

# Check storage usage
kubectl exec -n eldertree-audio $POD -- df -h /data
```

## Troubleshooting

### Pod not starting

```bash
kubectl describe pod -n eldertree-audio -l app=eldertree-audio
```

### PVC not bound

```bash
kubectl get pvc -n eldertree-audio
kubectl describe pvc audio-storage -n eldertree-audio
```

### Ingress not working

```bash
kubectl get ingress -n eldertree-audio
curl -k https://audio.eldertree.local/health
```
