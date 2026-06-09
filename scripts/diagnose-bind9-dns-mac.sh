#!/usr/bin/env bash
# Diagnose BIND9 LAN DNS (192.168.2.201) from macOS
set -euo pipefail

DNS_VIP="${DNS_VIP:-192.168.2.201}"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== BIND9 LAN DNS diagnostic (Mac) ==="
echo "VIP: $DNS_VIP"
echo ""

echo "1. Ping VIP..."
if ping -c 2 -W 2000 "$DNS_VIP" >/dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} $DNS_VIP reachable"
else
  echo -e "${RED}✗${NC} $DNS_VIP not reachable (kube-vip / bind Service?)"
fi

echo ""
echo "2. UDP port 53..."
if nc -z -u -w 2 "$DNS_VIP" 53 2>/dev/null; then
  echo -e "${GREEN}✓${NC} port 53 open"
else
  echo -e "${YELLOW}!${NC} UDP probe inconclusive — try dig below"
fi

echo ""
echo "3. dig tests..."
if command -v dig >/dev/null 2>&1; then
  local_ans=$(dig +short "@${DNS_VIP}" grafana.eldertree.local A 2>/dev/null | head -1 || true)
  if [[ -n "$local_ans" ]]; then
    echo -e "${GREEN}✓${NC} grafana.eldertree.local → $local_ans"
  else
    echo -e "${RED}✗${NC} grafana.eldertree.local NXDOMAIN/timeout"
  fi
  ext_ans=$(dig +short "@${DNS_VIP}" google.com A 2>/dev/null | head -1 || true)
  if [[ -n "$ext_ans" ]]; then
    echo -e "${GREEN}✓${NC} google.com → $ext_ans (recursion OK)"
  else
    echo -e "${RED}✗${NC} external recursion failed"
  fi
else
  echo -e "${YELLOW}!${NC} dig not installed"
fi

echo ""
echo "4. macOS DNS config..."
scutil --dns 2>/dev/null | grep -A2 "nameserver\[0\]" | head -6 || true

echo ""
echo "Cluster checks (if kubectl available):"
echo "  kubectl get pods,svc -n bind"
echo "  kubectl logs -n external-dns deployment/external-dns --tail=30"
