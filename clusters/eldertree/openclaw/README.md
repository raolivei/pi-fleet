# OpenClaw Deployment

Personal AI assistant powered by OpenClaw on eldertree. Uses a **local-first** model chain — a large model on the Mac primary, a small cluster-local model as fallback, then free cloud providers — plus Elder for cluster ops, code, and GitHub.

## Model chain (local-first, with on-demand cloud escalation)

Configured in [`configmap.yaml`](configmap.yaml) under `agents.defaults.model`:

| Tier | Model | Runs on | Notes |
| ---- | ----- | ------- | ----- |
| **primary** | `ollama-lan/qwen2.5:32b` | Mac Ollama, **LAN** (`192.168.2.107:11434`) | Mac is always home on the same LAN as the cluster; fast (~12s cold load, <1s TTFT) |
| **fallback 1** | `ollama-tailscale/qwen2.5:32b` | Mac Ollama, **Tailscale** (`100.97.229.104:11434`) | same model, in case the Mac ever leaves the LAN. LAN connect-refused fails in ~7ms, so this fires near-instantly — no manual toggling needed. Keep Tailscale running as an always-on login item; it costs nothing when idle. |
| **fallback 2** | `ollama-cluster/qwen2.5:3b` | Raspberry Pi 5 in-cluster (`ollama-fallback` svc) | 100% local, always-on regardless of the Mac; CPU-only, ~3-6 tok/s |
| **fallback 3+** | `openrouter/*` (Gemini Flash, Claude Haiku, Llama 4 Scout) | Cloud (OpenRouter free tier) | last resort, fast |
| _compaction_ | `ollama-lan/qwen2.5:32b` | Mac (LAN) | **not** the cluster — measured the Pi5's real prefill speed at 14.35 tok/s; OpenClaw's ~180s compaction budget only fits ~2,583 tokens at that rate, far below real conversation sizes (15-16k+ tokens). The Mac processes the same size prompt in ~44s. Moving compaction to the cluster (an earlier fix, see CHANGELOG) *sounded* right — decouple from Mac reachability — but the Pi5's CPU genuinely cannot do this task in time regardless of context-window tuning. Accepted trade-off: compaction now shares the Mac-reachability risk with primary again, but the LAN/Tailscale dual-path makes that risk small in practice. |

Why LAN-primary with Tailscale as a passive fallback tier (not primary): OpenClaw's fallback chain is
**reliability-based** (tries the next entry only when a call fails/errors), not quality-based — so
ordering LAN first is a pure latency win with no downside, and Tailscale silently covers the "Mac left
home" case without anyone needing to remember to flip anything.

**For genuinely hard investigations** (deep multi-file/log tracing) that need more reasoning than a
local ~30B model reliably gives: don't change this passive chain. Instead call Elder's
`elder_best_answer` with `"anthropic"` in `providers` to explicitly escalate to Claude Sonnet 5 (via
OpenRouter, reuses this same key) — see [`elder` README](https://github.com/raolivei/elder#readme).
This keeps the default chat path free/local/private and only pays for cloud when you deliberately ask.

The **cluster fallback** is deployed by [`ollama-fallback.yaml`](ollama-fallback.yaml): a pinned
`ollama/ollama:0.31.1` Deployment (soft-pinned to node-1, the node with most free RAM), a `local-path`
PVC for the model, and an ingress NetworkPolicy. The model is pulled on first boot and the pod is
only `Ready` once `qwen2.5:3b` exists. `OLLAMA_KEEP_ALIVE=30m` keeps it warm so a failover isn't a
CPU cold-start.

> **Context caveat:** Ollama caps context at `OLLAMA_CONTEXT_LENGTH` (set to `32768` on the cluster
> pod, matching the provider's `contextWindow` — matches the Mac providers so no tier is structurally
> too small to hold the baseline system prompt). For the Mac providers, set `num_ctx`/`OLLAMA_CONTEXT_LENGTH`
> on the Mac side if you need a window other than qwen2.5:32b's default.
>
> **Compaction headroom:** `reserveTokens` and `reserveTokensFloor` were retired before
> OpenClaw 2026.9.5 and must not be reintroduced. The current runtime manages its own
> compaction headroom. `agents.defaults.contextTokens` was also retired; each configured
> model's `contextWindow` is now authoritative. We retain safeguard mode and the explicit
> Mac-hosted compaction model. `keepRecentTokens` is not a replacement for the removed
> reserve settings because it controls how much recent conversation is preserved.

To change the primary/fallback Mac model, edit both `ollama-lan` and `ollama-tailscale` provider
entries in `configmap.yaml` (keep them in sync — same model, different `baseUrl`). To change the
cluster fallback model, edit both the `ollama pull` line in `ollama-fallback.yaml` **and** the
`ollama-cluster` provider entry in `configmap.yaml`.

## ARM64 Build

OpenClaw publishes a multi-architecture image with `linux/arm64` support. Our
GitHub Actions workflow builds a thin cluster image from that digest-pinned
runtime and adds a checksummed ARM64 `kubectl` binary.

**Image:** `ghcr.io/raolivei/openclaw:v2026.9.5`

**Workflow:** `.github/workflows/build-openclaw-arm64.yml`

The Dockerfile pins a reviewed upstream release and manifest digest in
`OPENCLAW_VERSION`, `OPENCLAW_UPSTREAM_TAG`, and `OPENCLAW_IMAGE_DIGEST`. A
merge that changes the Dockerfile automatically wraps that official ARM64
runtime with cluster tools, publishes the same `vYYYY.M.P` tag to GHCR, and
Flux selects it with a semver image policy. This keeps the deployed tag tied to
the source release; the old weekly job only produced new date tags around
unchanged, pinned source.

To upgrade:

1. Review the upstream OpenClaw release notes and configuration changes.
2. Bump `ARG OPENCLAW_VERSION`, `ARG OPENCLAW_UPSTREAM_TAG` (same value without
   the `v` prefix), and the verified multi-arch `OPENCLAW_IMAGE_DIGEST` in
   `docker/Dockerfile`.
3. If the same PR changes config or pins the new tag in the HelmRelease, run
   the workflow manually on the branch first so the image exists before merge.
4. Merge the change to `main`; the ARM64 workflow rebuilds the release and
   Flux image automation tracks subsequent reviewed semver tags.
5. Verify the packaged-version smoke test and the Flux rollout before testing
   Telegram.

Use Actions → "Build OpenClaw ARM64" → "Run workflow" only to rebuild the
release already pinned on the selected branch.

`v2026.9.5` is an intentional migration bridge from the previously deployed
`v2026.7.1`. Upstream requires installations with retired pre-July state to
run `doctor --fix` on `2026.9.5` before moving to current releases. The pod
startup command performs that repair once per image version and ConfigMap hash,
after saving the pre-migration config on the PVC. Upgrade to `v2026.10.5` only
after the `v2026.9.5` rollout and Doctor migration are verified.

## Features

- **Telegram Integration**: Chat via `@eldertree_assistant_bot`
- **Local-first LLM chain**: Mac `qwen2.5:32b` primary (LAN, Tailscale fallback) → cluster `qwen2.5:3b` → OpenRouter/Groq cloud last resort (see [Model chain](#model-chain-local-first-with-on-demand-cloud-escalation))
- **Elder best-answer**: Elder can query Gemini + Groq + Ollama in parallel and judge the best answer; pass `"anthropic"` to opt in to Claude Sonnet 5 for harder investigations
- **SwimTO Integration**: Query Toronto pool schedules
- **Kubernetes Access**: Cluster-wide operator RBAC via in-pod `kubectl` (workloads, Flux, ingress, secrets, etc.); storage (PV/PVC/snapshots/StorageClass) and cluster control-plane APIs are read-only — see [rbac.yaml](rbac.yaml)
- **Elder Agent**: Code browsing, GitHub issues/PRs, FluxCD, project planning
- **Control Center**: Live cluster topology + health at `https://control.eldertree.local` (Elder SPA; LAN/Tailscale) — see [CONTROL_CENTER.md](../../../docs/CONTROL_CENTER.md)
- **Web Search**: Brave Search API
- **Web UI**: `https://openclaw.eldertree.local`

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌───────────────────────────────────────┐
│  Telegram   │────▶│   OpenClaw   │────▶│  1. Mac qwen2.5:32b  (LAN)           │
│   Web UI    │◀────│   Gateway    │◀────│  2. Mac qwen2.5:32b  (Tailscale)     │
└─────────────┘     └──────┬───────┘     │  3. Cluster qwen2.5:3b  (Pi5, local) │
                           │             │  4. OpenRouter/Groq     (cloud)       │
                           ▼             └───────────────────────────────────────┘
                    ┌──────────────┐     ┌──────────────┐
                    │    Elder     │────▶│  SwimTO API  │
                    │  (cluster,   │     │  (internal)  │
                    │   code, GH)  │     └──────────────┘
                    └──────────────┘
```

**Resilience:** OpenClaw tries the Mac over LAN first (fastest); a dead LAN path fails in ~7ms so it
falls through to the same Mac model over Tailscale near-instantly, then to the always-on cluster-local
`qwen2.5:3b`, then to cloud providers. Elder's `elder_best_answer` queries Gemini + Groq + Ollama in
parallel and judges the best answer for its normal tool calls; pass `"anthropic"` in `providers` to
explicitly escalate a hard investigation to Claude Sonnet 5 (see [Model chain](#model-chain-local-first-with-on-demand-cloud-escalation)).

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
