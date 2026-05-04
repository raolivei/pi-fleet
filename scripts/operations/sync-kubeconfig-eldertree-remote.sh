#!/usr/bin/env bash
# Build ~/.kube/config-eldertree-remote from ~/.kube/config-eldertree so Lens/kubectl
# can reach the API via node-1's Tailscale IP (TLS SAN does not include TS IPs).
#
# See docs/TAILSCALE.md — table "kubeconfig for Remote Access".
# Override API host: ELDERTREE_TS_API_IP=100.116.185.57 ./sync-kubeconfig-eldertree-remote.sh

set -euo pipefail

SOURCE="${ELDERTREE_KUBECONFIG_SOURCE:-$HOME/.kube/config-eldertree}"
DEST="${ELDERTREE_KUBECONFIG_REMOTE:-$HOME/.kube/config-eldertree-remote}"
# node-1 Tailscale IP (pi-fleet/docs/TAILSCALE.md)
NODE1_TS_IP="${ELDERTREE_TS_API_IP:-100.86.241.124}"

if [[ ! -f "$SOURCE" ]]; then
  echo "❌ Missing kubeconfig: $SOURCE"
  echo "   Create it first (e.g. scripts/update-kubeconfig-vip.sh or setup-kubeconfig-eldertree.sh)."
  exit 1
fi

CLIENT_CERT=$(grep client-certificate-data "$SOURCE" | awk '{print $2}')
CLIENT_KEY=$(grep client-key-data "$SOURCE" | awk '{print $2}')

if [[ -z "${CLIENT_CERT:-}" || -z "${CLIENT_KEY:-}" ]]; then
  echo "❌ Could not read client-certificate-data / client-key-data from $SOURCE"
  exit 1
fi

umask 077
mkdir -p "$(dirname "$DEST")"
cat >"$DEST" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://${NODE1_TS_IP}:6443
  name: eldertree-remote
contexts:
- context:
    cluster: eldertree-remote
    user: eldertree-admin
  name: eldertree-remote
current-context: eldertree-remote
users:
- name: eldertree-admin
  user:
    client-certificate-data: ${CLIENT_CERT}
    client-key-data: ${CLIENT_KEY}
EOF

chmod 600 "$DEST"
echo "✅ Wrote $DEST (server https://${NODE1_TS_IP}:6443)"
echo "   Lens: Add cluster from this file. Requires Tailscale + Accept Routes when off-LAN."
echo "   If :6443 times out, run: bash scripts/operations/diagnose-eldertree-tailscale-k8s-api.sh"
echo "   then set ELDERTREE_TS_API_IP to a working node (often node-2 when node-1 shows rx 0 in tailscale status)."
