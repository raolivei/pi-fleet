# Build arguments come from build.lock.json through the standard shared
# docker-build.yml workflow. VERSION and GHCR tags are owned by that workflow.
ARG OPENCLAW_IMAGE
FROM ${OPENCLAW_IMAGE}

USER root

ARG KUBECTL_VERSION
ARG KUBECTL_SHA256
ARG TARGETARCH
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl && \
    test "${TARGETARCH}" = arm64 && \
    test -n "${KUBECTL_VERSION}" && test -n "${KUBECTL_SHA256}" && \
    curl --fail --silent --show-error --location --retry 3 \
      --connect-timeout 15 --max-time 120 -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" && \
    echo "${KUBECTL_SHA256}  /usr/local/bin/kubectl" | sha256sum -c - && \
    chmod 0755 /usr/local/bin/kubectl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --chmod=0755 startup.sh /usr/local/bin/openclaw-cluster-start

USER node
