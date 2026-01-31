# OpenClaw ARM64 Build
# Based on upstream: https://github.com/openclaw/openclaw
# This builds the same image but for ARM64 architecture

FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# Clone OpenClaw source
RUN apt-get update && \
    apt-get install -y --no-install-recommends git curl && \
    git clone --depth 1 https://github.com/openclaw/openclaw.git . && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

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
  "gateway": {
    "mode": "local",
    "port": 18789
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
        "primary": "google/gemini-1.5-flash"
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

# Run doctor to fix any remaining issues (ignore errors)
echo "[entrypoint] Running doctor --fix..."
node dist/index.js doctor --fix --yes 2>&1 || true

# Start the gateway
echo "[entrypoint] Starting gateway..."
exec node dist/index.js gateway "$@"
ENTRYPOINT_EOF

RUN chmod +x /app/docker-entrypoint.sh

# Security hardening: Run as non-root user
USER node

EXPOSE 18789 18790

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD []
