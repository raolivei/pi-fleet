#!/bin/bash
# Setup DNS for *.eldertree.local domains
# Supports BIND9 LAN DNS and /etc/hosts fallback
#
# NOTE: This script is a convenience wrapper. For better automation, use:
#   ansible-playbook ansible/playbooks/configure-dns.yml -e configure_hosts_file=true

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

TRAEFIK_VIP="${TRAEFIK_VIP:-192.168.2.200}"
DNS_VIP="${DNS_VIP:-192.168.2.201}"

echo "🔧 DNS Setup for *.eldertree.local"
echo ""

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
if kubectl get deployment bind9 -n bind &> /dev/null; then
    echo "✅ BIND9 is deployed (namespace bind)"
    echo ""
    echo "Option 1: Router DNS (Recommended - Network-wide)"
    echo "  Set router primary DNS to: ${DNS_VIP}"
    echo ""
    echo "Option 2: macOS System Settings"
    echo "  System Settings → Network → DNS → Add: ${DNS_VIP}"
    echo ""
else
    echo "⚠️  BIND9 not deployed, using /etc/hosts fallback"
    echo ""
fi

# Setup /etc/hosts entries
echo "Option 3: /etc/hosts (Fallback)"
read -p "Add entries to /etc/hosts? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Use Ansible playbook for DNS configuration
    cd "${ANSIBLE_DIR}"
    ansible-playbook playbooks/configure-dns.yml \
      -e "eldertree_ip=${TRAEFIK_VIP}" \
      -e "configure_hosts_file=true" \
      || {
        echo ""
        echo "⚠️  Ansible playbook failed, falling back to direct /etc/hosts update..."
        echo ""
        
        # Fallback to direct /etc/hosts update
        HOSTS_FILE="/etc/hosts"
        DOMAINS=("canopy.eldertree.local" "grafana.eldertree.local" "prometheus.eldertree.local" "vault.eldertree.local" "swimto.eldertree.local")
        
        for domain in "${DOMAINS[@]}"; do
            if ! grep -q "$domain" "$HOSTS_FILE" 2>/dev/null; then
                echo "${TRAEFIK_VIP}  $domain" | sudo tee -a "$HOSTS_FILE" > /dev/null
                echo "✅ Added $domain"
            else
                echo "✓ $domain already exists"
            fi
        done
        
        echo ""
        echo "✅ /etc/hosts configured"
      }
fi

echo ""
echo "🌐 Services accessible at:"
echo "  - https://canopy.eldertree.local"
echo "  - https://grafana.eldertree.local"
echo "  - https://prometheus.eldertree.local"
echo "  - https://vault.eldertree.local"
echo "  - https://swimto.eldertree.local"
echo ""

