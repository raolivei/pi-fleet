#!/usr/bin/env bash
# Complete cutover: Pi-hole → BIND9 LAN DNS (#232 / #234)
# Downtime OK — reconciles Flux, verifies BIND9 + external-dns, sweeps routing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
DNS_VIP="${DNS_VIP:-192.168.2.201}"

echo "=== BIND9 DNS cutover ==="
echo "KUBECONFIG=$KUBECONFIG"
echo ""

echo "1. Flux reconcile..."
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization flux-system -n flux-system --timeout=10m

echo ""
echo "2. HelmReleases (bind9, external-dns, monitoring-stack)..."
flux reconcile helmrelease bind9 -n bind --timeout=10m || true
flux reconcile helmrelease external-dns -n external-dns --timeout=5m || true
flux reconcile helmrelease monitoring-stack -n observability --timeout=10m || true

echo ""
echo "3. Cluster state..."
kubectl get pods,svc -n bind
kubectl get pods -n external-dns
kubectl get helmrelease -n bind bind9 -o wide 2>/dev/null || true

echo ""
echo "4. Prune legacy pi-hole namespace (if still present)..."
if kubectl get namespace pihole &>/dev/null; then
  echo "   Deleting namespace pihole..."
  kubectl delete namespace pihole --wait=false || true
else
  echo "   pi-hole namespace already gone"
fi

echo ""
echo "5. DNS verification..."
if command -v dig >/dev/null 2>&1; then
  for host in grafana.eldertree.local vault.eldertree.local control.eldertree.local; do
    ans=$(dig +short "@${DNS_VIP}" "$host" A 2>/dev/null | head -1 || true)
    if [[ -n "$ans" ]]; then
      echo "   OK  $host → $ans"
    else
      echo "   FAIL $host (no A record via $DNS_VIP)"
    fi
  done
  ext=$(dig +short "@${DNS_VIP}" google.com A 2>/dev/null | head -1 || true)
  if [[ -n "$ext" ]]; then
    echo "   OK  recursion (google.com → $ext)"
  else
    echo "   WARN recursion test failed"
  fi
else
  echo "   dig not installed — skip"
fi

echo ""
echo "6. Registry + routing sweep..."
cd "$PROJECT_ROOT"
./scripts/check-local-routing-registry.sh
./scripts/verify-service-routing.sh --host grafana.eldertree.local || true

echo ""
echo "=== Cutover script finished ==="
echo "Router DNS should remain: $DNS_VIP (no change)"
echo "Run full regression: ./scripts/verify-service-routing.sh --all-local"
