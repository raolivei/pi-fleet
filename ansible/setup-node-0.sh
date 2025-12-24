#!/bin/bash
# Setup script for node-0
# This script runs the system setup playbook on node-0 safely

set -e

cd "$(dirname "$0")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Setting up node-0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Source password if script exists
if [ -f "set-password.sh" ]; then
    echo "📝 Loading password from set-password.sh..."
    source set-password.sh
fi

echo "🔍 Running system setup playbook on node-0..."
echo "   This will:"
echo "   - Detect current hostname and IP configuration"
echo "   - Convert 'node-x' to 'node-0.eldertree.local' if needed"
echo "   - Set static IP to 192.168.2.80 (only if different AND network is reachable)"
echo "   - Configure system packages, SSH, Bluetooth, etc."
echo "   - Preserve existing working network configuration"
echo "   - SKIP network changes if node is unreachable (prevents breaking connectivity)"
echo ""

ansible-playbook playbooks/setup-system.yml \
    --limit node-0 \
    --ask-pass \
    --ask-become-pass \
    -e "static_ip_override=192.168.2.80"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ node-0 setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

