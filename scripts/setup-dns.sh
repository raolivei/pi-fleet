#!/bin/bash
# Setup DNS for *.eldertree.local domains
# Supports both Pi-hole DNS and /etc/hosts fallback

set -e

ELDERTREE_IP="${ELDERTREE_IP:-192.168.2.83}"
PIHOLE_PORT="${PIHOLE_PORT:-30053}"

echo "🔧 DNS Setup for *.eldertree.local"
echo ""

# Check if Pi-hole is deployed
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
if kubectl get deployment pihole -n pihole &> /dev/null; then
    echo "✅ Pi-hole is deployed"
    echo ""
    echo "Option 1: Router DNS (Recommended - Network-wide)"
    echo "  Set router DNS to: ${ELDERTREE_IP}:${PIHOLE_PORT}"
    echo ""
    echo "Option 2: macOS System Settings"
    echo "  System Settings → Network → DNS → Add: ${ELDERTREE_IP}"
    echo ""
else
    echo "⚠️  Pi-hole not deployed, using /etc/hosts fallback"
    echo ""
fi

# Setup /etc/hosts entries
echo "Option 3: /etc/hosts (Fallback)"
read -p "Add entries to /etc/hosts? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    HOSTS_FILE="/etc/hosts"
    DOMAINS=("eldertree" "canopy.eldertree.local" "grafana.eldertree.local" "prometheus.eldertree.local" "vault.eldertree.local" "pihole.eldertree.local")
    
    for domain in "${DOMAINS[@]}"; do
        if ! grep -q "$domain" "$HOSTS_FILE" 2>/dev/null; then
            echo "${ELDERTREE_IP}  $domain" | sudo tee -a "$HOSTS_FILE" > /dev/null
            echo "✅ Added $domain"
        else
            echo "✓ $domain already exists"
        fi
    done
    
    echo ""
    echo "✅ /etc/hosts configured"
fi

echo ""
echo "🌐 Services accessible at:"
echo "  - https://canopy.eldertree.local"
echo "  - https://grafana.eldertree.local"
echo "  - https://prometheus.eldertree.local"
echo "  - https://vault.eldertree.local"
echo "  - https://pihole.eldertree.local"
echo ""

