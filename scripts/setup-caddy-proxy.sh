#!/bin/bash
# Setup Caddy local proxy for Eldertree services
# This allows accessing services without port numbers: https://grafana.eldertree.local

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CADDYFILE="$SCRIPT_DIR/Caddyfile"
HOSTS_FILE="/etc/hosts"
MARKER_START="# BEGIN Eldertree Caddy Proxy"
MARKER_END="# END Eldertree Caddy Proxy"

echo "=== Eldertree Caddy Proxy Setup ==="
echo ""

# Check if Caddy is installed
if ! command -v caddy &> /dev/null; then
    echo "❌ Caddy not installed. Install with: brew install caddy"
    exit 1
fi

echo "✅ Caddy installed: $(caddy version)"

# Update /etc/hosts to point to localhost
echo ""
echo "Updating /etc/hosts to point *.eldertree.local to 127.0.0.1..."

# Remove old entries
if grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
    echo "Removing old Caddy proxy entries..."
    sudo sed -i '' "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE"
fi

# Also remove old NodePort entries (192.168.2.101)
if grep -q "192.168.2.101.*eldertree.local" "$HOSTS_FILE" 2>/dev/null; then
    echo "Removing old NodePort entries..."
    sudo sed -i '' '/192.168.2.101.*eldertree.local/d' "$HOSTS_FILE"
fi

# Add new entries pointing to localhost
echo "Adding Caddy proxy entries..."
sudo tee -a "$HOSTS_FILE" > /dev/null << EOF

$MARKER_START
# Services proxied by Caddy to k3s cluster (NodePort 32474)
# Run: sudo caddy run --config $CADDYFILE
# Only includes DEPLOYED services (as of 2026-01-16)
127.0.0.1  grafana.eldertree.local
127.0.0.1  vault.eldertree.local
127.0.0.1  prometheus.eldertree.local
127.0.0.1  visage.eldertree.local
127.0.0.1  minio.eldertree.local
127.0.0.1  swimto.eldertree.local
127.0.0.1  pitanga.eldertree.local
127.0.0.1  flux.eldertree.local
127.0.0.1  dex.eldertree.local
127.0.0.1  pushgateway.eldertree.local
127.0.0.1  pihole.eldertree.local

# Node IPs (direct access)
192.168.2.101  node-1.eldertree.local
192.168.2.102  node-2.eldertree.local
192.168.2.103  node-3.eldertree.local
$MARKER_END
EOF

echo "✅ /etc/hosts updated"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To start Caddy proxy, run:"
echo "  sudo caddy run --config $CADDYFILE"
echo ""
echo "Or run in background:"
echo "  sudo caddy start --config $CADDYFILE"
echo ""
echo "Then access services without port:"
echo "  https://grafana.eldertree.local"
echo "  https://vault.eldertree.local"
echo "  https://prometheus.eldertree.local"
echo ""
echo "To stop Caddy:"
echo "  sudo caddy stop"
