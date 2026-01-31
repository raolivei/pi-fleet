# OpenClaw Deployment

Personal AI assistant powered by OpenClaw (Moltbot) running on eldertree.

## Features

- **Telegram Integration**: Chat with your assistant via `@eldertree_assistant_bot`
- **Google Gemini AI**: Uses Gemini 1.5 Flash (free tier)
- **SwimTO Integration**: Query Toronto pool schedules
- **Web UI**: Access at `https://openclaw.eldertree.local`

## Quick Start

### 1. Get Credentials

1. **Telegram Bot**: Message [@BotFather](https://t.me/botfather), send `/newbot`
2. **Gemini API Key**: Get from [aistudio.google.com](https://aistudio.google.com)

### 2. Store Secrets

Run the setup script:

```bash
./scripts/setup-openclaw.sh
```

Or manually store in Vault:

```bash
# Get Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Store Telegram token
kubectl exec -n vault $VAULT_POD -- vault kv put secret/openclaw/telegram token="YOUR_BOT_TOKEN"

# Store Gemini API key
kubectl exec -n vault $VAULT_POD -- vault kv put secret/openclaw/gemini api-key="YOUR_API_KEY"
```

### 3. Enable Deployment

Edit `clusters/eldertree/kustomization.yaml` and add:

```yaml
resources:
  # ... existing resources ...
  - openclaw
```

### 4. Deploy

```bash
git add clusters/eldertree/openclaw/
git commit -m "feat(openclaw): add OpenClaw deployment"
git push
```

Flux will automatically deploy.

## Monitoring

```bash
# Check pod status
kubectl get pods -n openclaw

# View logs
kubectl logs -n openclaw -l app=openclaw -f

# Check External Secret sync
kubectl get externalsecret -n openclaw
```

## SwimTO Integration

Ask your bot questions like:

- "What pools have lane swim tonight?"
- "Show me Riverdale pool schedule"
- "Find pools near High Park"

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Telegram   │────▶│   OpenClaw   │────▶│   Gemini    │
│   (User)    │◀────│   Gateway    │◀────│    API      │
└─────────────┘     └──────┬───────┘     └─────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │  SwimTO API  │
                    │  (internal)  │
                    └──────────────┘
```

## Secrets

| Path | Description |
|------|-------------|
| `secret/openclaw/telegram` | Telegram bot token |
| `secret/openclaw/gemini` | Google AI Studio API key |

## Storage

Uses `local-path` storage class (k3s default) for config persistence.
Data stored on whichever node the pod runs on.

## Troubleshooting

### Bot not responding

1. Check pod is running: `kubectl get pods -n openclaw`
2. Check logs: `kubectl logs -n openclaw -l app=openclaw`
3. Verify secrets: `kubectl get externalsecret -n openclaw`

### Secret sync failed

1. Check Vault is unsealed: `./scripts/operations/unseal-vault.sh`
2. Verify secret exists in Vault
3. Check ExternalSecret status: `kubectl describe externalsecret openclaw-secrets -n openclaw`

### API rate limits

Gemini free tier: 60 requests/minute. If you hit limits, consider:
- Upgrading to paid tier
- Using a different provider (OpenAI, OpenRouter)
