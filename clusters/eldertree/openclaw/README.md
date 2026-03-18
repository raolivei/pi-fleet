# OpenClaw Deployment

Personal AI assistant powered by OpenClaw on eldertree with OpenRouter (primary) and Groq fallback, plus Elder for cluster ops, code, and GitHub.

## ARM64 Build

The official OpenClaw image doesn't support ARM64 (Raspberry Pi). We build our own image using GitHub Actions.

**Image:** `ghcr.io/raolivei/openclaw:latest`

**Workflow:** `.github/workflows/build-openclaw-arm64.yml`

To rebuild manually:

1. Go to Actions → "Build OpenClaw ARM64"
2. Click "Run workflow"
3. Optionally set version input (e.g. `v1.0.0`)
4. Wait for build (~10-15 min)

## Features

- **Telegram Integration**: Chat via `@eldertree_assistant_bot`
- **Multi-Provider LLM**: OpenRouter primary (e.g. Llama, Gemini, Claude) + Groq fallback
- **Elder best-answer**: Elder can query Gemini + Groq in parallel and judge the best answer
- **SwimTO Integration**: Query Toronto pool schedules
- **Kubernetes Access**: Read-only cluster access (pods, logs, events)
- **Elder Agent**: Code browsing, GitHub issues/PRs, FluxCD, project planning
- **Web Search**: Brave Search API
- **Web UI**: `https://openclaw.eldertree.local`

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────────────────┐
│  Telegram   │────▶│   OpenClaw   │────▶│  OpenRouter (primary)       │
│   Web UI    │◀────│   Gateway    │◀────│  Groq (fallback)            │
└─────────────┘     └──────┬───────┘     └─────────────────────────────┘
                           │
                           ▼
                    ┌──────────────┐     ┌──────────────┐
                    │    Elder     │────▶│  SwimTO API  │
                    │  (cluster,   │     │  (internal)  │
                    │   code, GH)  │     └──────────────┘
                    └──────────────┘
```

**Resilience:** OpenClaw uses OpenRouter first; if it fails, fallbacks to Groq. Elder can use `elder_best_answer` to query Gemini + Groq in parallel and return the judged best answer.

## Quick Start

### 1. Get Credentials

1. **Telegram Bot**: Message [@BotFather](https://t.me/botfather), send `/newbot`
2. **OpenRouter API Key**: [openrouter.ai](https://openrouter.ai) (primary LLM for OpenClaw)
3. **Groq API Key** (optional): [console.groq.com](https://console.groq.com) (fallback)
4. **Gemini API Key** (optional): [aistudio.google.com](https://aistudio.google.com) (for Elder best-answer only)

### 2. Store Secrets

Run the setup script:

```bash
./scripts/setup-openclaw.sh
```

Prompts for: Telegram, OpenRouter, Groq (optional), Gemini (optional, for Elder).

### 3. Deploy

OpenClaw is enabled in `clusters/eldertree/kustomization.yaml`. Push to trigger Flux deployment.

## META Actions (Self-Upgrade)

Elder can upgrade itself or OpenClaw:

- **elder_upgrade**: Trigger GitHub Actions rebuild (requires approval)
- **elder_version**: Get current Elder and OpenClaw versions

Example: "Upgrade OpenClaw to v1.0.0" → creates approval → user approves → workflow runs → Flux deploys.

## Secrets

| Path                          | Description                                      |
| ----------------------------- | ------------------------------------------------ |
| `secret/openclaw/telegram`    | Telegram bot token                               |
| `secret/openclaw/openrouter`  | OpenRouter API key (primary LLM)                 |
| `secret/openclaw/groq`        | Groq API key (optional fallback)                 |
| `secret/openclaw/gemini`      | Google AI key (optional; Elder best-answer only)|
| `secret/openclaw/gateway`     | Gateway authentication token (auto-generated)    |
| `secret/openclaw/brave`       | Brave Search API key (for web search)            |

## Verification (Post-Deploy)

After pushing changes and Flux reconciling:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# 1. Pods running
kubectl get pods -n openclaw

# 2. Elder best-answer endpoint (requires ELDER API key or auth)
curl -X POST https://elder.eldertree.local/api/llm/best-answer \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is 2+2?", "providers": ["gemini", "groq"], "judge": false}'

# 3. Provider status
curl https://elder.eldertree.local/api/llm/providers
```

## Monitoring

```bash
kubectl get pods -n openclaw
kubectl logs -n openclaw -l app=openclaw -f
kubectl get externalsecret -n openclaw
```

## Web UI Access (No Manual Token)

The Web UI uses **trusted-proxy auth**: Traefik injects `X-Forwarded-User: local` for all requests. OpenClaw trusts requests from the proxy (pod network) and skips manual token entry. Just open https://openclaw.eldertree.local — no Control UI token needed.

## Troubleshooting

### Bot not responding

1. Check pod: `kubectl get pods -n openclaw`
2. Check logs: `kubectl logs -n openclaw -l app=openclaw`
3. Verify secrets: `kubectl get externalsecret -n openclaw`

### Secret sync failed

1. Unseal Vault: `./scripts/operations/unseal-vault.sh`
2. Verify secret exists in Vault
3. `kubectl describe externalsecret openclaw-secrets -n openclaw`

### API rate limits

OpenRouter and Groq have their own limits. Fallback to Groq activates automatically when OpenRouter fails.

### Web UI "gateway token missing"

If you see this error, trusted-proxy auth may not be active. Ensure:
1. ConfigMap has `gateway.auth.mode: "trusted-proxy"` and `gateway.auth.trustedProxy.userHeader: "x-forwarded-user"`
2. Ingress uses the `add-trusted-proxy-user` middleware
3. OpenClaw pod has restarted to pick up config changes
