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
    apt-get install -y --no-install-recommends git && \
    git clone --depth 1 https://github.com/openclaw/openclaw.git . && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN pnpm install --frozen-lockfile

RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
# Force pnpm for UI build (Bun may fail on ARM architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# Security hardening: Run as non-root user
USER node

EXPOSE 18789 18790

CMD ["node", "dist/index.js"]
