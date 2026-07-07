# OpenClaw Deployment

Personal AI assistant powered by OpenClaw on eldertree. Uses a **local-first** model chain — a large model on the Mac primary, a small cluster-local model as fallback, then free cloud providers — plus Elder for cluster ops, code, and GitHub.

## Model chain (local-first)

Configured in [`configmap.yaml`](configmap.yaml) under `agents.defaults.model`:

| Tier | Model | Runs on | Notes |
| ---- | ----- | ------- | ----- |
| **primary** | `ollama/gemma4:31b-mlx` | Mac Ollama (`100.97.229.104:11434` via Tailscale) | 31B, best quality |
| **fallback 1** | `ollama-cluster/qwen2.5:3b` | Raspberry Pi 5 in-cluster (`ollama-fallback` svc) | 100% local, always-on; CPU-only, ~3-6 tok/s |
| **fallback 2+** | `openrouter/*` (Gemini Flash, Claude Haiku, Llama 4 Scout) | Cloud (OpenRouter free tier) | last resort, fast |
| _compaction_ | `ollama/qwen2.5:7b` | Mac Ollama | context summarization only |

The **cluster fallback** is deployed by [`ollama-fallback.yaml`](ollama-fallback.yaml): a pinned
`ollama/ollama:0.31.1` Deployment (soft-pinned to node-1, the node with most free RAM), a `local-path`
PVC for the model, and an ingress NetworkPolicy. The model is pulled on first boot and the pod is
only `Ready` once `qwen2.5:3b` exists. `OLLAMA_KEEP_ALIVE=30m` keeps it warm so a failover isn't a
CPU cold-start.

> **⚠️ Primary requires the Mac reachable from the cluster.** The primary routes to
> `100.97.229.104:11434`, a **Tailscale** address — if Tailscale is **stopped** on the Mac, the
> cluster cannot reach it (`http_code=000`) and every request silently falls through to the fallback
> tiers. Keep Tailscale **up and persistent** (login item) on the Mac. Alternative: point the `ollama`
> provider `baseUrl` in [`configmap.yaml`](configmap.yaml) at the Mac's LAN IP (e.g.
> `http://192.168.2.107:11434/v1`) with a DHCP reservation. Verify the path from inside the cluster:
> `kubectl -n openclaw exec deploy/openclaw -- curl -s --max-time 8 http://100.97.229.104:11434/api/tags`.

> **Reasoning-model caveat.** `gemma4:31b-mlx` emits a `reasoning` field. Leave its `reasoning`
> **unset** (= `false`) and do **not** enable `thinkingDefault` for this agent — setting `reasoning:true`
> on an `openai-completions` Ollama endpoint triggers `reasoning_effort` injection that breaks tool
> calling ([openclaw#33272](https://github.com/openclaw/openclaw/issues/33272)). If gemma ever returns
> empty content, raise its `maxTokens` (currently 4096) rather than touching `reasoning`.

> **Context caveat:** Ollama caps context at `OLLAMA_CONTEXT_LENGTH` (set to `16384` on the cluster
> pod, matching the provider's `contextWindow`). For the Mac primary, set `num_ctx`/`OLLAMA_CONTEXT_LENGTH`
> on the Mac side if you need the full declared window.

To change the fallback model, edit both `OLLAMA_CONTEXT_LENGTH`/the `ollama pull` line in
`ollama-fallback.yaml` **and** the `ollama-cluster` provider entry in `configmap.yaml`.

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
- **Local-first LLM chain**: Mac `gemma4:31b-mlx` primary → cluster `qwen2.5:3b` fallback → OpenRouter/Groq cloud last resort (see [Model chain](#model-chain-local-first))
- **Elder best-answer**: Elder can query Gemini + Groq in parallel and judge the best answer
- **SwimTO Integration**: Query Toronto pool schedules
- **Kubernetes Access**: Cluster-wide operator RBAC via in-pod `kubectl` (workloads, Flux, ingress, secrets, etc.); storage (PV/PVC/snapshots/StorageClass) and cluster control-plane APIs are read-only — see [rbac.yaml](rbac.yaml)
- **Elder Agent**: Code browsing, GitHub issues/PRs, FluxCD, project planning
- **Control Center**: Live cluster topology + health at `https://control.eldertree.local` (Elder SPA; LAN/Tailscale) — see [CONTROL_CENTER.md](../../../docs/CONTROL_CENTER.md)
- **Web Search**: Brave Search API
- **Web UI**: `https://openclaw.eldertree.local`

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────────────────────────┐
│  Telegram   │────▶│   OpenClaw   │────▶│  1. Mac gemma4:31b-mlx  (Tailscale)  │
│   Web UI    │◀────│   Gateway    │◀────│  2. Cluster qwen2.5:3b  (Pi5, local) │
└─────────────┘     └──────┬───────┘     │  3. OpenRouter/Groq     (cloud)      │
                           │             └──────────────────────────────────────┘
                           ▼
                    ┌──────────────┐     ┌──────────────┐
                    │    Elder     │────▶│  SwimTO API  │
                    │  (cluster,   │     │  (internal)  │
                    │   code, GH)  │     └──────────────┘
                    └──────────────┘
```

**Resilience:** OpenClaw tries the Mac primary first; if unreachable it falls back to the always-on
cluster-local `qwen2.5:3b`, then to cloud providers. Elder can use `elder_best_answer` to query
Gemini + Groq in parallel and return the judged best answer.

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

## Web UI Access (Gateway Token)

The gateway uses **`auth.mode: token`** so **in-pod tools** (sessions list, internal WebSocket clients) authenticate with `OPENCLAW_GATEWAY_TOKEN` — trusted-proxy cannot work for those loopback connections (no `X-Forwarded-User`). Open https://openclaw.eldertree.local and **paste the gateway token** when prompted (value from Vault `secret/openclaw/gateway` property `token`, or `kubectl get secret openclaw-secrets -n openclaw -o jsonpath='{.data.OPENCLAW_GATEWAY_TOKEN}' | base64 -d`).

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

Paste the token from Vault `secret/openclaw/gateway` (synced into `openclaw-secrets` as `OPENCLAW_GATEWAY_TOKEN`). Ensure `gateway.auth.mode` is `token` and `gateway.auth.token` expands `${OPENCLAW_GATEWAY_TOKEN}` in [`configmap.yaml`](configmap.yaml), then restart the OpenClaw pod.
