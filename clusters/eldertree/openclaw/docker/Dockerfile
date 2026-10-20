# OpenClaw cluster image
# Upstream publishes a multi-architecture image, including linux/arm64. Keep
# this layer intentionally small: the cluster only needs kubectl in addition
# to the reviewed upstream runtime.

ARG OPENCLAW_VERSION=v2026.9.5
ARG OPENCLAW_UPSTREAM_TAG=2026.9.5
ARG OPENCLAW_IMAGE_DIGEST=sha256:ea298b62be8955d3ef750e2004a610dd90c3a30e5f9886e5d654d78a0c573218
FROM ghcr.io/openclaw/openclaw:${OPENCLAW_UPSTREAM_TAG}@${OPENCLAW_IMAGE_DIGEST}

USER root

# Match the cluster's Kubernetes minor version and verify the downloaded ARM64
# client before installing it into the upstream image.
ARG KUBECTL_VERSION=v1.35.0
ARG KUBECTL_ARM64_SHA256=58f82f9fe796c375c5c4b8439850b0f3f4d401a52434052f2df46035a8789e25
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl && \
    curl -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/arm64/kubectl" && \
    echo "${KUBECTL_ARM64_SHA256}  /usr/local/bin/kubectl" | sha256sum -c - && \
    chmod 0755 /usr/local/bin/kubectl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

USER node
