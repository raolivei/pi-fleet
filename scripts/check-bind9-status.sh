#!/usr/bin/env bash
# BIND9 + external-dns status on Eldertree cluster
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
DNS_VIP="${DNS_VIP:-192.168.2.201}"

echo "=== BIND9 status ==="
kubectl get pods,svc -n bind -o wide
echo ""
kubectl get helmrelease -n bind bind9 2>/dev/null || true
echo ""
echo "=== external-dns ==="
kubectl get pods -n external-dns
kubectl logs -n external-dns deployment/external-dns --tail=15 2>/dev/null || true
echo ""
echo "=== DNS probes ==="
kubectl exec -n bind deployment/bind9 -- dig @127.0.0.1 grafana.eldertree.local +short 2>/dev/null || echo "(in-pod dig failed)"
if command -v dig >/dev/null 2>&1; then
  dig +short "@${DNS_VIP}" grafana.eldertree.local A || true
fi
