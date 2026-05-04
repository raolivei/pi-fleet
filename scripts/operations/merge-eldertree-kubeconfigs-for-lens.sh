#!/usr/bin/env bash
# Merge LAN + Tailscale kubeconfigs so Lens can switch contexts without re-importing.
#
# 1. Ensures ~/.kube/config-eldertree-remote exists (runs sync from LAN kubeconfig).
# 2. Writes ~/.kube/config-eldertree-lens with contexts: eldertree (VIP), eldertree-remote (Tailscale).
#
# In Lens: Add cluster from ~/.kube/config-eldertree-lens
#   - At home (same LAN or Accept Routes): context "eldertree"
#   - Away / VIP timeout: context "eldertree-remote"
#
# See docs/LENS_CONNECTION_GUIDE.md and docs/TAILSCALE.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAN="${ELDERTREE_KUBECONFIG_SOURCE:-$HOME/.kube/config-eldertree}"
REMOTE="${ELDERTREE_KUBECONFIG_REMOTE:-$HOME/.kube/config-eldertree-remote}"
OUT="${ELDERTREE_KUBECONFIG_LENS:-$HOME/.kube/config-eldertree-lens}"

if [[ ! -f "$LAN" ]]; then
  echo "❌ Missing LAN kubeconfig: $LAN"
  echo "   Run: bash ${SCRIPT_DIR}/../setup-kubeconfig-eldertree.sh"
  echo "   or:  bash ${SCRIPT_DIR}/../update-kubeconfig-vip.sh"
  exit 1
fi

# Keep non-default Tailscale API IP across re-merge (e.g. node-2 when node-1 shows rx 0).
if [[ -z "${ELDERTREE_TS_API_IP:-}" ]] && [[ -f "$REMOTE" ]]; then
  if grep -q 'server: https://100\.' "$REMOTE"; then
    ELDERTREE_TS_API_IP=$(grep 'server: https://' "$REMOTE" | head -1 | sed -E 's|.*https://([^:]+):6443.*|\1|')
    export ELDERTREE_TS_API_IP
  fi
fi

ts_api="${ELDERTREE_TS_API_IP:-100.86.241.124 (default node-1)}"
echo "Syncing $REMOTE from $LAN (Tailscale API $ts_api)..."
bash "${SCRIPT_DIR}/sync-kubeconfig-eldertree-remote.sh"

if [[ ! -f "$REMOTE" ]]; then
  echo "❌ Remote kubeconfig not created: $REMOTE"
  exit 1
fi

umask 077
mkdir -p "$(dirname "$OUT")"
# Flatten merge: both clusters + contexts in one file; current-context = remote (works off-LAN by default)
KUBECONFIG="${LAN}:${REMOTE}" kubectl config view --flatten >"${OUT}.tmp"
mv "${OUT}.tmp" "$OUT"
chmod 600 "$OUT"
# Default to Tailscale context so Lens works off-LAN; at home switch to "eldertree" for VIP/HA.
kubectl config use-context eldertree-remote --kubeconfig="$OUT" >/dev/null

echo "✅ Wrote $OUT"
echo ""
echo "Lens:"
echo "  File → Add cluster → $OUT"
echo "  Contexts: eldertree (VIP) | eldertree-remote (Tailscale API from sync script)"
echo "  If you see dial tcp 192.168.2.100:6443 timeout → switch to eldertree-remote (Tailscale on + Accept Routes)."
echo ""
kubectl config get-contexts --kubeconfig="$OUT"
