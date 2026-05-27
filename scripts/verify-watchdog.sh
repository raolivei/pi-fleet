#!/bin/bash
# Verify hardware watchdog status on all eldertree nodes

set -e

NODES=("10.0.0.1" "10.0.0.2" "10.0.0.3")
NAMES=("node-1" "node-2" "node-3")
SSH_KEY="~/.ssh/id_ed25519_raolivei"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"

echo "=== Hardware Watchdog Status Check ==="
echo "Date: $(date)"
echo ""

for i in "${!NODES[@]}"; do
  NODE="${NODES[$i]}"
  NAME="${NAMES[$i]}"

  echo "--- $NAME ($NODE) ---"

  # Check if node is reachable
  if ! ssh $SSH_OPTS -i $SSH_KEY raolivei@$NODE "exit" 2>/dev/null; then
    echo "✗ Node unreachable (SSH failed)"
    echo ""
    continue
  fi

  # Service status
  if ssh $SSH_OPTS -i $SSH_KEY raolivei@$NODE "systemctl is-active watchdog" 2>/dev/null | grep -q "active"; then
    echo "✓ Service: running"
  else
    echo "✗ Service: NOT RUNNING"
  fi

  # Boot counter
  COUNTER=$(ssh $SSH_OPTS -i $SSH_KEY raolivei@$NODE "cat /var/lib/watchdog-boot-count 2>/dev/null" || echo "N/A")
  echo "Boot counter: $COUNTER"

  if [ "$COUNTER" != "N/A" ] && [ "$COUNTER" -ge 5 ]; then
    echo "⚠️  WARNING: Boot counter at max ($COUNTER/5) - watchdog may be disabled!"
  fi

  # Recent reboots (last 24 hours)
  REBOOTS=$(ssh $SSH_OPTS -i $SSH_KEY raolivei@$NODE "journalctl -u watchdog --since '24 hours ago' 2>/dev/null | grep -c 'stopping\|started'" 2>/dev/null || echo "0")
  echo "Watchdog restarts (24h): $REBOOTS"

  # Last reboot time
  LAST_REBOOT=$(ssh $SSH_OPTS -i $SSH_KEY raolivei@$NODE "uptime -s 2>/dev/null" || echo "unknown")
  echo "System boot time: $LAST_REBOOT"

  # Check configuration
  TIMEOUT=$(ssh $SSH_OPTS -i $SSH_KEY raolivei@$NODE "grep -E '^watchdog-timeout' /etc/watchdog.conf 2>/dev/null | awk '{print \$3}'" || echo "N/A")
  echo "Watchdog timeout: ${TIMEOUT}s"

  # Check for recent watchdog activity
  LAST_LOG=$(ssh $SSH_OPTS -i $SSH_KEY raolivei@$NODE "journalctl -u watchdog --since '1 hour ago' --no-pager 2>/dev/null | tail -1" || echo "No recent logs")
  if [ "$LAST_LOG" != "No recent logs" ]; then
    echo "Last watchdog log: $(echo "$LAST_LOG" | cut -c1-80)..."
  fi

  echo ""
done

echo "=== Summary ==="
echo "Check complete. Review any warnings above."
echo ""
echo "To check detailed logs on a specific node:"
echo "  ssh raolivei@10.0.0.X 'journalctl -u watchdog -n 50'"
echo ""
echo "To check system logs from previous boot:"
echo "  ssh raolivei@10.0.0.X 'journalctl --boot=-1 | tail -100'"
