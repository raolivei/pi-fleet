#!/bin/bash
# Verify hardware watchdog status on all eldertree nodes.
# Checks service state AND whether the daemon actually holds /dev/watchdog.

set -euo pipefail

# Prefer gigabit; fall back to WiFi when SSH from a laptop fails on 10.0.0.x
NODE_NAMES=("node-1" "node-2" "node-3")
NODE_IPS_GB=("10.0.0.1" "10.0.0.2" "10.0.0.3")
NODE_IPS_WIFI=("192.168.2.101" "192.168.2.102" "192.168.2.103")
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_raolivei}"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"

ssh_node() {
  local ip=$1
  shift
  ssh $SSH_OPTS -i "$SSH_KEY" "raolivei@${ip}" "$@"
}

resolve_ip() {
  local idx=$1
  local ip
  for ip in "${NODE_IPS_GB[$idx]}" "${NODE_IPS_WIFI[$idx]}"; do
    if ssh_node "$ip" "exit" 2>/dev/null; then
      echo "$ip"
      return 0
    fi
  done
  return 1
}

echo "=== Hardware Watchdog Status Check ==="
echo "Date: $(date)"
echo ""

FAILURES=0

for i in "${!NODE_NAMES[@]}"; do
  NAME="${NODE_NAMES[$i]}"
  IP=""
  if ! IP=$(resolve_ip "$i"); then
    echo "--- $NAME (unreachable) ---"
    echo "✗ SSH failed on ${NODE_IPS_GB[$i]} and ${NODE_IPS_WIFI[$i]}"
    echo ""
    FAILURES=$((FAILURES + 1))
    continue
  fi

  echo "--- $NAME ($IP) ---"

  if ssh_node "$IP" "systemctl is-active watchdog" 2>/dev/null | grep -q "active"; then
    echo "✓ Service: running"
  else
    echo "✗ Service: NOT RUNNING"
    FAILURES=$((FAILURES + 1))
  fi

  if ssh_node "$IP" "test ! -f /usr/lib/systemd/system.conf.d/40-rpi-enable-watchdog.conf" 2>/dev/null; then
    echo "✓ RPI systemd drop-in: absent (good)"
  else
    echo "✗ RPI systemd drop-in: PRESENT — disables hardware watchdog for daemon"
    FAILURES=$((FAILURES + 1))
  fi

  if ssh_node "$IP" "sudo lsof /dev/watchdog 2>/dev/null | awk 'NR>1 && \$1==\"watchdog\" {found=1} END {exit !found}'" 2>/dev/null; then
    echo "✓ Device: watchdog daemon holds /dev/watchdog"
  else
    echo "✗ Device: watchdog daemon does NOT hold /dev/watchdog"
    ssh_node "$IP" "sudo lsof /dev/watchdog 2>/dev/null | head -3" || true
    FAILURES=$((FAILURES + 1))
  fi

  COUNTER=$(ssh_node "$IP" "cat /var/lib/watchdog-boot-count 2>/dev/null" || echo "N/A")
  echo "Boot counter: $COUNTER"
  if [ "$COUNTER" != "N/A" ] && [ "$COUNTER" -ge 5 ] 2>/dev/null; then
    echo "⚠️  WARNING: Boot counter at max ($COUNTER/5)"
  fi

  LAST_REBOOT=$(ssh_node "$IP" "awk '/btime/ {print \$2}' /proc/stat | xargs -I{} date -d @{} 2>/dev/null" || echo "unknown")
  echo "Kernel boot time: $LAST_REBOOT"

  TIMEOUT=$(ssh_node "$IP" "grep -E '^watchdog-timeout' /etc/watchdog.conf 2>/dev/null | awk '{print \$3}'" || echo "N/A")
  echo "Watchdog timeout: ${TIMEOUT}s"
  echo ""
done

echo "=== Summary ==="
if [ "$FAILURES" -eq 0 ]; then
  echo "All nodes protected (daemon holds /dev/watchdog)."
else
  echo "$FAILURES check(s) failed — see warnings above."
  exit 1
fi
