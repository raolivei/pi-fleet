#!/usr/bin/env bash
# Open ElderTree project views: Grafana ops home, docs project page, optional kubectl status.
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config-eldertree}"

OPEN_BROWSER="${OPEN_BROWSER:-1}"
DOCS_URL="${ELDERTREE_DOCS_URL:-https://docs.eldertree.xyz/project}"
GRAFANA_URL="${ELDERTREE_GRAFANA_URL:-https://grafana.eldertree.local/d/eldertree-ops-home}"

echo "=== ElderTree cluster ==="
echo "KUBECONFIG=${KUBECONFIG}"
echo ""

if command -v kubectl >/dev/null 2>&1; then
  if kubectl cluster-info >/dev/null 2>&1; then
    kubectl get nodes -o custom-columns=NAME:.metadata.name,READY:.status.conditions[-1].type,STATUS:.status.conditions[-1].status,INTERNAL-IP:.status.addresses[?(@.type==\"InternalIP\")].address 2>/dev/null \
      | head -10 || kubectl get nodes
    echo ""
    not_ready="$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded -o name 2>/dev/null | wc -l | tr -d ' ')"
    echo "Pods not Running/Succeeded: ${not_ready}"
  else
    echo "(kubectl: cluster unreachable — check VPN / LAN / KUBECONFIG)"
  fi
else
  echo "(kubectl not installed)"
fi

echo ""
echo "Links:"
echo "  Grafana ops home: ${GRAFANA_URL}"
echo "  Project hub:      ${DOCS_URL}"
echo "  pi-fleet hub:     docs/ELDERTREE.md"
echo ""

if [[ "${OPEN_BROWSER}" == "1" ]] && command -v open >/dev/null 2>&1; then
  open "${GRAFANA_URL}" 2>/dev/null || true
  open "${DOCS_URL}" 2>/dev/null || true
fi
