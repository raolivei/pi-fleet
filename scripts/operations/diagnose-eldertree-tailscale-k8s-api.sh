#!/usr/bin/env bash
# Quick check: which Eldertree control-plane Tailscale IPs answer on :6443 from this Mac.
# Use when Lens/kubectl show: dial tcp 100.x.x.x:6443 i/o timeout
#
# If node-1 fails but node-2 works, regenerate remote kubeconfig:
#   ELDERTREE_TS_API_IP=100.116.185.57 bash scripts/operations/sync-kubeconfig-eldertree-remote.sh
#   bash scripts/operations/merge-eldertree-kubeconfigs-for-lens.sh

set -euo pipefail

TS_BIN=""
for c in tailscale "/Applications/Tailscale.app/Contents/MacOS/Tailscale"; do
  if command -v "$c" &>/dev/null; then
    TS_BIN=$(command -v "$c")
    break
  fi
  if [[ -x "$c" ]]; then
    TS_BIN="$c"
    break
  fi
done

echo "=== Tailscale (cluster nodes) ==="
ts_out=""
if [[ -n "$TS_BIN" ]]; then
  ts_out="$("$TS_BIN" status 2>&1)" || true
  echo "$ts_out" | grep -E 'node-[123]|100\.[0-9]+\.[0-9]+\.[0-9]+' || echo "$ts_out" | head -20
else
  echo "⚠️  tailscale CLI not found (install Tailscale or use /Applications/Tailscale.app)"
fi

echo ""
echo "=== TCP :6443 (2s timeout each) ==="
probe_tcp() {
  local ip="$1"
  python3 - "$ip" <<'PY' 2>/dev/null || true
import socket, sys
ip = sys.argv[1]
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(2)
try:
    s.connect((ip, 6443))
    sys.exit(0)
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
}

IPS=(100.86.241.124 100.116.185.57 100.104.30.105)
LABELS=(node-1 node-2 node-3)
ok=""
for i in "${!IPS[@]}"; do
  ip="${IPS[$i]}"
  label="${LABELS[$i]}"
  if probe_tcp "$ip"; then
    echo "✅ $label ($ip):6443 reachable"
    ok="${ok:+$ok }$ip"
  else
    echo "❌ $label ($ip):6443 no TCP handshake (timeout/refused)"
  fi
done

echo ""
if [[ -n "$ok" ]]; then
  first=$(echo "$ok" | awk '{print $1}')
  suggest="$first"
  # tailscale can show node-1 with rx 0 (broken return path) while TCP connect still fails or flakes in apps
  if [[ -n "$ts_out" ]] && echo "$ts_out" | grep 'node-1' | grep -q 'rx 0'; then
    alt=$(echo "$ok" | tr ' ' '\n' | grep -v '^100\.86\.241\.124$' | head -1)
    if [[ -n "$alt" ]]; then
      suggest="$alt"
      echo "⚠️  node-1 has rx 0 in tailscale status — suggesting $suggest for a healthier path (override with ELDERTREE_TS_API_IP)."
      echo ""
    fi
  fi
  echo "Suggested remote API IP: $suggest"
  echo "  ELDERTREE_TS_API_IP=$suggest bash $(dirname "$0")/sync-kubeconfig-eldertree-remote.sh"
  echo "Then refresh Lens / re-run merge-eldertree-kubeconfigs-for-lens.sh if you use the merged file."
else
  echo "None of the Tailscale API endpoints responded. Check:"
  echo "  - Tailscale logged in on this Mac; peers online"
  echo "  - Home power / ISP; nodes reachable via SSH on LAN if at home"
  echo "  - On node-1: sudo systemctl status tailscaled k3s"
fi
