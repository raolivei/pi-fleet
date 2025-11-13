#!/bin/bash
# Setup AdGuard Home DNS rewrites for *.eldertree.local
# This script adds DNS rewrites to AdGuard Home for automatic resolution

set -e

ADGUARD_URL="${ADGUARD_URL:-http://192.168.2.83:30000}"
ELDERTREE_IP="${ELDERTREE_IP:-192.168.2.83}"

echo "🔧 Setting up AdGuard Home DNS rewrites for *.eldertree.local"
echo ""

# Check if AdGuard Home is accessible
if ! curl -s "${ADGUARD_URL}" > /dev/null 2>&1; then
    echo "❌ Error: Cannot reach AdGuard Home at ${ADGUARD_URL}"
    echo "   Please ensure AdGuard Home is running and accessible"
    echo "   Check: kubectl get pods -n adshield"
    exit 1
fi

echo "✅ AdGuard Home is accessible at ${ADGUARD_URL}"
echo ""
echo "To add DNS rewrites:"
echo ""
echo "1. Open AdGuard Home web UI: ${ADGUARD_URL}"
echo "2. Go to: Settings → DNS settings → DNS rewrites"
echo "3. Add the following entries:"
echo ""
echo "   Domain: canopy.eldertree.local"
echo "   IP: ${ELDERTREE_IP}"
echo ""
echo "   Domain: grafana.eldertree.local"
echo "   IP: ${ELDERTREE_IP}"
echo ""
echo "   Domain: prometheus.eldertree.local"
echo "   IP: ${ELDERTREE_IP}"
echo ""
echo "   Domain: vault.eldertree.local"
echo "   IP: ${ELDERTREE_IP}"
echo ""
echo "4. Save the configuration"
echo ""
echo "Alternatively, use the API (requires admin credentials):"
echo ""
echo "export ADGUARD_USER='admin'"
echo "export ADGUARD_PASS='your_password'"
echo ""
echo "Then run the API commands in DNS_SETUP.md"
echo ""

