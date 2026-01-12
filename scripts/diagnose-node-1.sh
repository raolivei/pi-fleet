#!/bin/bash
# Diagnostic script for node-1 recurring issues
# Run this when node-1 is accessible to identify root cause

set -e

NODE1_IP="192.168.2.101"
NODE1_HOST="node-1.eldertree.local"

echo "=========================================="
echo "Node-1 Diagnostic Script"
echo "=========================================="
echo ""

# Check if node-1 is accessible
echo "=== Testing connectivity ==="
if ping -c 1 -W 2 $NODE1_IP > /dev/null 2>&1; then
    echo "✅ Node-1 is reachable via ping"
else
    echo "❌ Node-1 is NOT reachable via ping"
    echo "   Node-1 appears to be completely down"
    exit 1
fi

# Check SSH
echo ""
echo "=== Testing SSH ==="
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no raolivei@$NODE1_IP "echo 'SSH OK'" > /dev/null 2>&1; then
    echo "✅ SSH is working"
    SSH_WORKING=true
else
    echo "❌ SSH is NOT working"
    SSH_WORKING=false
fi

if [ "$SSH_WORKING" = false ]; then
    echo ""
    echo "⚠️  Cannot run remote diagnostics - SSH is down"
    echo "   Please use physical access to node-1"
    exit 1
fi

# Run diagnostics via SSH
echo ""
echo "=== System Resources ==="
ssh raolivei@$NODE1_IP << 'EOF'
echo "--- Memory ---"
free -h

echo ""
echo "--- Disk Space ---"
df -h | grep -E "Filesystem|/dev/"

echo ""
echo "--- System Load ---"
uptime

echo ""
echo "--- Top Processes (by CPU) ---"
ps aux --sort=-%cpu | head -10

echo ""
echo "--- Top Processes (by Memory) ---"
ps aux --sort=-%mem | head -10
EOF

echo ""
echo "=== k3s Service Status ==="
ssh raolivei@$NODE1_IP "sudo systemctl status k3s --no-pager | head -30" || echo "Cannot get k3s status"

echo ""
echo "=== k3s Recent Errors ==="
ssh raolivei@$NODE1_IP "sudo journalctl -u k3s -n 50 --no-pager | grep -i error | tail -10" || echo "No errors found or cannot access logs"

echo ""
echo "=== Network Interfaces ==="
ssh raolivei@$NODE1_IP "ip addr show | grep -E '^[0-9]+:|inet '"

echo ""
echo "=== Firewall Status ==="
ssh raolivei@$NODE1_IP "sudo ufw status verbose 2>/dev/null || echo 'UFW not active or not installed'"

echo ""
echo "=== System Errors (last hour) ==="
ssh raolivei@$NODE1_IP "sudo journalctl -p err --since '1 hour ago' --no-pager | tail -20" || echo "No errors found"

echo ""
echo "=== OOM Kills ==="
ssh raolivei@$NODE1_IP "dmesg | grep -i 'out of memory' | tail -5" || echo "No OOM kills found"

echo ""
echo "=== Hardware Temperature (if available) ==="
ssh raolivei@$NODE1_IP "vcgencmd measure_temp 2>/dev/null || echo 'Temperature check not available'"

echo ""
echo "=== Power Supply Status (if available) ==="
ssh raolivei@$NODE1_IP "vcgencmd get_throttled 2>/dev/null || echo 'Power status check not available'"

echo ""
echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="
echo ""
echo "Review the output above for:"
echo "- Low memory or disk space"
echo "- High CPU usage"
echo "- k3s service errors"
echo "- Network issues"
echo "- Hardware problems (temperature, power)"
echo ""

