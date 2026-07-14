# OpenClaw ARM64 Build
# Based on upstream: https://github.com/openclaw/openclaw
# This builds the same image but for ARM64 architecture

FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# Clone OpenClaw source and install kubectl for Kubernetes access
RUN apt-get update && \
    apt-get install -y --no-install-recommends git curl ca-certificates && \
    # Install kubectl (ARM64)
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/ && \
    # Clone OpenClaw — pin to a known-good release tag.
    # To upgrade: bump the tag, commit, and trigger build-openclaw-arm64.yml.
    git clone --depth 1 --branch 2026.6.11 https://github.com/openclaw/openclaw.git . && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# `pnpm build` renders CLI help text by spawning a subprocess per command; this
# repo builds under QEMU emulation (no arm64 CI runner yet -- see workflow
# comment), which is ~10-20x slower than native. Upstream hardcodes a 120s
# timeout for these renders (scripts/write-cli-startup-metadata.ts) with no
# env override; under emulation a single build phase here has taken 25+
# minutes, so 120s reliably times out. Raise to 10 minutes -- generous, but
# still bounded so a genuine hang doesn't run forever.
RUN sed -i \
    -e 's/^const ROOT_HELP_RENDER_TIMEOUT_MS = 120_000;/const ROOT_HELP_RENDER_TIMEOUT_MS = 600_000;/' \
    -e 's/^const BROWSER_HELP_RENDER_TIMEOUT_MS = 120_000;/const BROWSER_HELP_RENDER_TIMEOUT_MS = 600_000;/' \
    scripts/write-cli-startup-metadata.ts && \
    grep -q 'ROOT_HELP_RENDER_TIMEOUT_MS = 600_000' scripts/write-cli-startup-metadata.ts && \
    grep -q 'BROWSER_HELP_RENDER_TIMEOUT_MS = 600_000' scripts/write-cli-startup-metadata.ts

RUN pnpm install --frozen-lockfile

RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
# Force pnpm for UI build (Bun may fail on ARM architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# Create entrypoint script
RUN cat > /app/docker-entrypoint.sh << 'ENTRYPOINT_EOF'
#!/bin/bash
set -e

OPENCLAW_DIR="${HOME}/.openclaw"
CONFIG_FILE="${OPENCLAW_DIR}/openclaw.json"

echo "[entrypoint] Starting OpenClaw setup..."

# Create required directories
mkdir -p "${OPENCLAW_DIR}/agents/main/sessions"
mkdir -p "${OPENCLAW_DIR}/credentials"
mkdir -p "${OPENCLAW_DIR}/workspace"

# Create config if it doesn't exist or is empty
if [ ! -s "$CONFIG_FILE" ]; then
    echo "[entrypoint] Creating initial config..."
    cat > "$CONFIG_FILE" << 'CONFIGEOF'
{
  "providers": {
    "google": { "enabled": true },
    "groq": { "enabled": true },
    "ollama": { "enabled": true }
  },
  "gateway": {
    "mode": "local",
    "port": 18789,
    "trustedProxies": ["10.42.0.0/16", "10.43.0.0/16"]
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "open",
      "allowFrom": ["*"]
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "google:gemini-1.5-flash",
        "fallbacks": [
          "groq:llama-3.1-70b-versatile",
          "ollama:qwen2.5:14b"
        ]
      }
    }
  },
  "plugins": {
    "entries": {
      "telegram": {
        "enabled": true
      }
    }
  }
}
CONFIGEOF
fi

# Run doctor only when config is writable (skip when mounted read-only from ConfigMap)
if [ -w "$CONFIG_FILE" ] 2>/dev/null; then
  echo "[entrypoint] Running doctor --fix..."
  node dist/index.js doctor --fix --yes 2>&1 || true
else
  echo "[entrypoint] Config is read-only (ConfigMap mount), skipping doctor"
fi

# Start the gateway (bind to LAN for k8s networking)
echo "[entrypoint] Starting gateway..."
exec node dist/index.js gateway --bind lan "$@"
ENTRYPOINT_EOF

RUN chmod +x /app/docker-entrypoint.sh

# Security hardening: Run as non-root user
USER node

EXPOSE 18789 18790

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD []
