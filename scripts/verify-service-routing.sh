#!/usr/bin/env bash
# End-to-end routing verification for a *.eldertree.local service (cluster → DNS → Mac).
#
# Usage:
#   export KUBECONFIG=~/.kube/config-eldertree
#   ./scripts/verify-service-routing.sh --host swimto.eldertree.local
#   ./scripts/verify-service-routing.sh --all-local          # every host in registry
#   ./scripts/verify-service-routing.sh --host foo.eldertree.local --skip-mac
#
# Checks (in order):
#   1. Ingress exists with host rule and backend Service has endpoints
#   2. TLS Certificate Ready (if Ingress uses TLS)
#   3. external-dns hostname annotation present
#   4. LAN DNS (BIND9 VIP) resolves host
#   5. Traefik NodePort HTTPS with Host header (bypasses Mac DNS/Caddy)
#   6. Mac path: curl https://host (uses your DNS + optional Caddy)
#   7. Registry sync (check-local-routing-registry.sh) for that host

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="${ROOT}/docs/eldertree-local-services.yaml"
DNS_IP="${DNS_IP:-${PIHOLE_IP:-192.168.2.201}}"
TRAEFIK_HTTPS_NODEPORT="${TRAEFIK_HTTPS_NODEPORT:-}"
TRAEFIK_NODE_IP="${TRAEFIK_NODE_IP:-192.168.2.101}"
SKIP_MAC=false
HOST=""
ALL_LOCAL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --all-local) ALL_LOCAL=true; shift ;;
    --skip-mac) SKIP_MAC=true; shift ;;
    --dns-ip) DNS_IP="$2"; shift 2 ;;
    --pihole-ip) DNS_IP="$2"; shift 2 ;;  # deprecated alias
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}  $*"; }
fail() { echo -e "${RED}FAIL${NC}  $*"; FAILURES=$((FAILURES + 1)); }
warn() { echo -e "${YELLOW}WARN${NC}  $*"; }

FAILURES=0

require_kubectl() {
  if ! command -v kubectl >/dev/null 2>&1; then
    fail "kubectl not found"
    return 1
  fi
  if ! kubectl cluster-info >/dev/null 2>&1; then
    fail "kubectl cannot reach cluster (KUBECONFIG=${KUBECONFIG:-unset})"
    return 1
  fi
  return 0
}

detect_traefik_nodeport() {
  if [[ -n "$TRAEFIK_HTTPS_NODEPORT" ]]; then
    return 0
  fi
  local port
  port=$(kubectl get svc traefik -n kube-system -o jsonpath='{.spec.ports[?(@.name=="websecure")].nodePort}' 2>/dev/null || true)
  if [[ -z "$port" ]]; then
    port=$(kubectl get svc traefik -n kube-system -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}' 2>/dev/null || true)
  fi
  if [[ -n "$port" ]]; then
    TRAEFIK_HTTPS_NODEPORT="$port"
    pass "Traefik HTTPS NodePort: $port (via $TRAEFIK_NODE_IP)"
  else
    warn "Could not detect Traefik websecure NodePort; set TRAEFIK_HTTPS_NODEPORT"
  fi
}

verify_host() {
  local host="$1"
  echo ""
  echo "========== $host =========="

  # --- Cluster: find ingress ---
  local ing_line ns ing_name svc port endpoints
  ing_line=$(kubectl get ingress -A -o json 2>/dev/null | python3 -c "
import json, sys
host = sys.argv[1]
data = json.load(sys.stdin)
for item in data.get('items', []):
    for rule in item.get('spec', {}).get('rules', []) or []:
        if rule.get('host') == host:
            ns = item['metadata']['namespace']
            name = item['metadata']['name']
            paths = rule.get('http', {}).get('paths', [])
            svc = port = None
            if paths:
                be = paths[0].get('backend', {}).get('service', {})
                svc = be.get('name')
                port = be.get('port', {}).get('number')
            print(f'{ns}\t{name}\t{svc or \"-\"}\t{port or \"-\"}')
            sys.exit(0)
sys.exit(1)
" "$host" 2>/dev/null || true)

  if [[ -z "$ing_line" ]]; then
    fail "No Ingress with host $host in cluster"
    return
  fi
  IFS=$'\t' read -r ns ing_name svc port <<< "$ing_line"
  pass "Ingress $ns/$ing_name → Service $svc:$port"

  # --- Endpoints ---
  if [[ "$svc" != "-" ]]; then
    endpoints=$(kubectl get endpoints "$svc" -n "$ns" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
    if [[ -n "$endpoints" ]]; then
      pass "Service endpoints: $endpoints"
    else
      fail "Service $ns/$svc has no ready endpoints (503 at Traefik)"
    fi
  fi

  # --- TLS certificate ---
  local tls_secret
  tls_secret=$(kubectl get ingress "$ing_name" -n "$ns" -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null || true)
  if [[ -n "$tls_secret" ]]; then
    local cert_ready
    cert_ready=$(kubectl get certificate -n "$ns" -o json 2>/dev/null | python3 -c "
import json, sys
secret = sys.argv[1]
for c in json.load(sys.stdin).get('items', []):
    if c.get('spec', {}).get('secretName') == secret:
        for cond in c.get('status', {}).get('conditions', []):
            if cond.get('type') == 'Ready':
                print(cond.get('status', 'Unknown'))
                sys.exit(0)
print('Missing')
" "$tls_secret" 2>/dev/null || echo "Missing")
    if [[ "$cert_ready" == "True" ]]; then
      pass "Certificate for $tls_secret Ready"
    else
      fail "Certificate for $tls_secret not Ready ($cert_ready)"
    fi
  else
    warn "Ingress has no TLS block"
  fi

  # --- external-dns annotation ---
  local edns
  edns=$(kubectl get ingress "$ing_name" -n "$ns" -o jsonpath='{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}' 2>/dev/null || true)
  if [[ -n "$edns" ]]; then
    pass "external-dns hostname: $edns"
  else
    warn "Missing external-dns.alpha.kubernetes.io/hostname (external-dns may not auto-update)"
  fi

  # --- LAN DNS (BIND9) ---
  if command -v dig >/dev/null 2>&1; then
    local dns_answer
    dns_answer=$(dig +short "@${DNS_IP}" "$host" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || true)
    if [[ -n "$dns_answer" ]]; then
      pass "BIND9 LAN DNS ($DNS_IP) → $dns_answer"
    else
      fail "LAN DNS does not resolve $host (check external-dns / BIND9; is $DNS_IP reachable?)"
    fi
  else
    warn "dig not installed — skip LAN DNS check"
  fi

  # --- Traefik direct (cluster path) ---
  if [[ -n "$TRAEFIK_HTTPS_NODEPORT" ]]; then
    local code
    code=$(curl -sk --connect-timeout 8 -o /dev/null -w "%{http_code}" \
      --resolve "${host}:443:${TRAEFIK_NODE_IP}" \
      "https://${host}/" 2>/dev/null || echo "000")
    if [[ "$code" =~ ^(200|301|302|401|403|404)$ ]]; then
      pass "Traefik NodePort HTTPS → HTTP $code (routing works; 401/403 may be expected)"
    elif [[ "$code" == "503" ]]; then
      fail "Traefik NodePort → HTTP 503 (no backend — check pod/endpoints)"
    elif [[ "$code" == "000" ]]; then
      fail "Traefik NodePort curl failed (network/firewall/NodePort)"
    else
      warn "Traefik NodePort → HTTP $code (investigate)"
    fi
  fi

  # --- Mac path (DNS + optional Caddy) ---
  if ! $SKIP_MAC; then
    local mac_code
    mac_code=$(curl -sk --connect-timeout 8 -o /dev/null -w "%{http_code}" "https://${host}/" 2>/dev/null || echo "000")
    if [[ "$mac_code" =~ ^(200|301|302|401|403|404)$ ]]; then
      pass "Mac curl https://$host → HTTP $mac_code"
    elif [[ "$mac_code" == "503" ]]; then
      fail "Mac curl → HTTP 503 (Caddy/hosts/DNS wrong, or backend down)"
    elif [[ "$mac_code" == "000" ]]; then
      fail "Mac curl failed — DNS/hosts/Caddy not wired (see check-local-routing-registry.sh)"
    else
      warn "Mac curl → HTTP $mac_code"
    fi
  fi

  # --- Registry file sync for this host ---
  local missing_files=()
  for f in docs/eldertree-local-hosts-block.txt scripts/add-services-to-hosts.sh scripts/Caddyfile; do
    if ! grep -qF "$host" "${ROOT}/$f" 2>/dev/null; then
      missing_files+=("$f")
    fi
  done
  if [[ ${#missing_files[@]} -eq 0 ]]; then
    pass "Host listed in hosts block, add-services-to-hosts.sh, and Caddyfile"
  else
    fail "Host missing from: ${missing_files[*]}"
  fi
}

mapfile -t ALL_HOSTS < <(awk '/^  - host: / { print $3 }' "$REGISTRY" 2>/dev/null | sort -u)

if $ALL_LOCAL; then
  require_kubectl || exit 1
  detect_traefik_nodeport
  for h in "${ALL_HOSTS[@]}"; do
    verify_host "$h"
  done
elif [[ -n "$HOST" ]]; then
  require_kubectl || exit 1
  detect_traefik_nodeport
  verify_host "$HOST"
else
  echo "Usage: $0 --host <fqdn> | --all-local" >&2
  exit 2
fi

echo ""
if [[ $FAILURES -eq 0 ]]; then
  echo -e "${GREEN}All checks passed.${NC}"
  exit 0
else
  echo -e "${RED}$FAILURES check(s) failed.${NC} See docs/ONBOARDING_APP_ROUTING.md"
  exit 1
fi
