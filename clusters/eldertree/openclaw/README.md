# OpenClaw Deployment

Personal AI assistant powered by OpenClaw running on eldertree with multi-provider LLM support (Gemini + Groq + Ollama) and Grove for cluster ops, code, and GitHub.

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
- **Multi-Provider LLM**: Gemini (primary) + Groq + Ollama fallback chain
- **Best-of-Three**: Grove can query all three providers in parallel and judge the best answer
- **SwimTO Integration**: Query Toronto pool schedules
- **Kubernetes Access**: Read-only cluster access (pods, logs, events)
- **Grove Agent**: Code browsing, GitHub issues/PRs, FluxCD, project planning
- **Web Search**: Brave Search API
- **Web UI**: `https://openclaw.eldertree.local`

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────────────────┐
│  Telegram   │────▶│   OpenClaw   │────▶│  Gemini (primary)           │
│   Web UI    │◀────│   Gateway    │◀────│  Groq (fallback)            │
└─────────────┘     └──────┬───────┘     │  Ollama (fallback, on Mac)  │
                           │             └─────────────────────────────┘
                           │
                           ▼
                    ┌──────────────┐     ┌──────────────┐
                    │    Grove     │────▶│  SwimTO API  │
                    │  (cluster,   │     │  (internal)  │
                    │   code, GH)  │     └──────────────┘
                    └──────────────┘
```

**Option A (Resilience):** Normal traffic uses primary (Gemini); if it fails, fallbacks to Groq, then Ollama.

**Option B (Best-of-Three):** For important questions, use `grove_best_answer` to query all three in parallel and get the judged best answer.

## Quick Start

### 1. Get Credentials

1. **Telegram Bot**: Message [@BotFather](https://t.me/botfather), send `/newbot`
2. **Gemini API Key**: [aistudio.google.com](https://aistudio.google.com)
3. **Groq API Key** (optional): [console.groq.com](https://console.groq.com)
4. **Ollama**: Run on Mac; cluster connects via Tailscale or LAN

### 2. Store Secrets

Run the setup script:

```bash
./scripts/setup-openclaw.sh
```

Prompts for: Telegram, Gemini, Groq (optional), Ollama base URL (e.g. `http://100.x.x.x:11434` for Tailscale Mac).

### 3. Ollama on Mac (for fallback / best-of-three)

Ollama cannot run large models on the Pi cluster (8GB ARM64). Run it on your M4 Mac:

```bash
# Install Ollama
brew install ollama

# Start and pull model
ollama serve   # or run as service
ollama pull qwen2.5:14b
```

**Connect from cluster:** Use your Mac's Tailscale IP (e.g. `http://100.86.241.124:11434`) as `OLLAMA_BASE_URL` in the setup script. Ensure Mac firewall allows port 11434 from the cluster network.

### 4. Deploy

OpenClaw is enabled in `clusters/eldertree/kustomization.yaml`. Push to trigger Flux deployment.

## META Actions (Self-Upgrade)

Grove can upgrade itself or OpenClaw:

- **grove_upgrade**: Trigger GitHub Actions rebuild (requires approval)
- **grove_version**: Get current Grove and OpenClaw versions

Example: "Upgrade OpenClaw to v1.0.0" → creates approval → user approves → workflow runs → Flux deploys.

## Secrets

| Path                       | Description                                   |
| -------------------------- | --------------------------------------------- |
| `secret/openclaw/telegram` | Telegram bot token                            |
| `secret/openclaw/gemini`   | Google AI Studio API key                      |
| `secret/openclaw/groq`     | Groq API key (optional)                       |
| `secret/openclaw/ollama`   | Ollama config: `api-key`, `base-url`          |
| `secret/openclaw/gateway`  | Gateway authentication token (auto-generated)|
| `secret/openclaw/brave`    | Brave Search API key (for web search)         |

## Verification (Post-Deploy)

After pushing changes and Flux reconciling:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# 1. Pods running
kubectl get pods -n openclaw

# 2. Grove best-answer endpoint (requires GROVE_API_KEY or auth)
curl -X POST https://grove.eldertree.local/api/llm/best-answer \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is 2+2?", "providers": ["gemini", "groq"], "judge": false}'

# 3. Provider status
curl https://grove.eldertree.local/api/llm/providers
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

### Ollama unreachable from cluster

- Ensure Ollama is running on Mac: `ollama list`
- Use Mac's Tailscale IP (not localhost) for `OLLAMA_BASE_URL`
- Test from a cluster pod: `kubectl run -it --rm debug --image=curlimages/curl -- curl -s http://<mac-ip>:11434/api/tags`

### API rate limits

Gemini free tier: 60 req/min. Fallbacks (Groq, Ollama) activate automatically when primary fails.

### Web UI "gateway token missing"

If you see this error, trusted-proxy auth may not be active. Ensure:
1. ConfigMap has `gateway.auth.mode: "trusted-proxy"` and `gateway.auth.trustedProxy.userHeader: "x-forwarded-user"`
2. Ingress uses the `add-trusted-proxy-user` middleware
3. OpenClaw pod has restarted to pick up config changes
