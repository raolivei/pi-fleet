#!/usr/bin/env bash
#
# add-services-to-hosts.sh — sync /etc/hosts with ALL live eldertree.local services.
#
# The service list is derived LIVE from cluster Ingresses (never hardcoded), so it
# cannot drift as apps are added/removed. Services resolve to the Traefik ingress
# VIP; cluster nodes resolve to their own IPs.
#
# Usage:
#   bash scripts/add-services-to-hosts.sh        # prompts once for sudo to write /etc/hosts
#
# Env:
#   ELDERTREE_VIP   Traefik ingress VIP for service hostnames   (default 192.168.2.200)
#   KUBECONFIG      kubeconfig used to read Ingresses           (default ~/.kube/config-eldertree)
#
# Notes:
#   - 192.168.2.200 is the Traefik *ingress* VIP (app traffic). 192.168.2.201 is the
#     BIND9 *DNS* VIP (set that as your resolver, not as a hostname target).
#   - If services are unreachable via the VIP, the cause is usually router Wi-Fi
#     "AP/Client Isolation"; the documented fallback is node-1 (ELDERTREE_VIP=192.168.2.101).
#   - Re-running is idempotent: the managed block and any stray *.eldertree.local
#     lines are stripped and rewritten.
set -euo pipefail

VIP="${ELDERTREE_VIP:-192.168.2.200}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
HOSTS_FILE="/etc/hosts"
BEGIN="# Eldertree Cluster Services"
END="# End Eldertree Cluster Services"

echo "Deriving live eldertree.local services from cluster Ingresses (KUBECONFIG=$KUBECONFIG)..."
SERVICES="$(
  kubectl get ingress -A -o jsonpath='{range .items[*]}{range .spec.rules[*]}{.host}{"\n"}{end}{end}' \
    | grep -E '\.eldertree\.local$' \
    | grep -vE '^node-[0-9]+\.' \
    | sort -u
)"

if [ -z "$SERVICES" ]; then
  echo "ERROR: no *.eldertree.local Ingresses found." >&2
  echo "  Check cluster access: KUBECONFIG=$KUBECONFIG kubectl get ingress -A" >&2
  exit 1
fi

# Build the managed block (services -> VIP, nodes -> own IPs).
BLOCK_FILE="$(mktemp)"
{
  echo "$BEGIN"
  echo "# Generated from live cluster Ingresses by add-services-to-hosts.sh — do not edit by hand"
  echo "# Services -> VIP $VIP (Traefik ingress); nodes -> own IPs"
  while IFS= read -r host; do
    [ -n "$host" ] && printf '%s  %s\n' "$VIP" "$host"
  done <<< "$SERVICES"
  echo
  echo "# Cluster nodes (node-specific IPs)"
  echo "192.168.2.101  node-1.eldertree.local"
  echo "192.168.2.102  node-2.eldertree.local"
  echo "192.168.2.103  node-3.eldertree.local"
  echo "$END"
} > "$BLOCK_FILE"

# Strip any prior managed block AND any stray *.eldertree.local lines, then append the fresh block.
NEW_FILE="$(mktemp)"
{
  sed "/^${BEGIN}\$/,/^${END}\$/d" "$HOSTS_FILE" \
    | grep -vE '[[:space:]][A-Za-z0-9_.-]+\.eldertree\.local([[:space:]]|$)' \
    || true
  echo
  cat "$BLOCK_FILE"
} > "$NEW_FILE"

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"
BACKUP="${HOSTS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo "Backing up $HOSTS_FILE -> $BACKUP"
$SUDO cp "$HOSTS_FILE" "$BACKUP"
$SUDO cp "$NEW_FILE" "$HOSTS_FILE"
rm -f "$BLOCK_FILE" "$NEW_FILE"

COUNT="$(printf '%s\n' "$SERVICES" | grep -c . || true)"
echo "✅ /etc/hosts synced: ${COUNT} services -> ${VIP}, plus node-1/2/3."
printf '%s\n' "$SERVICES" | sed 's/^/   /'
