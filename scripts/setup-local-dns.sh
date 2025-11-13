#!/bin/bash
# Setup local DNS entries in /etc/hosts for eldertree.local domains

set -e

ELDERTREE_IP="${ELDERTREE_IP:-192.168.2.83}"
HOSTS_FILE="/etc/hosts"

echo "🔧 Setting up local DNS entries in ${HOSTS_FILE}"
echo ""

# Check if entries already exist
if grep -q "canopy.eldertree.local" "$HOSTS_FILE" 2>/dev/null; then
    echo "✅ canopy.eldertree.local already exists in ${HOSTS_FILE}"
else
    echo "➕ Adding canopy.eldertree.local..."
    echo "${ELDERTREE_IP}  canopy.eldertree.local" | sudo tee -a "$HOSTS_FILE" > /dev/null
fi

if grep -q "pihole.eldertree.local" "$HOSTS_FILE" 2>/dev/null; then
    echo "✅ pihole.eldertree.local already exists in ${HOSTS_FILE}"
else
    echo "➕ Adding pihole.eldertree.local..."
    echo "${ELDERTREE_IP}  pihole.eldertree.local" | sudo tee -a "$HOSTS_FILE" > /dev/null
fi

# Verify all entries
echo ""
echo "📋 Current eldertree.local entries in ${HOSTS_FILE}:"
grep "eldertree" "$HOSTS_FILE" || echo "No entries found"

echo ""
echo "✅ DNS setup complete!"
echo ""
echo "🌐 Accessible URLs:"
echo "   - https://canopy.eldertree.local"
echo "   - https://grafana.eldertree.local"
echo "   - https://prometheus.eldertree.local"
echo "   - https://vault.eldertree.local"
echo "   - https://pihole.eldertree.local"
echo ""

