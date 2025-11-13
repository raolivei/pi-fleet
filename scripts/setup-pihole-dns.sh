#!/bin/bash
# Setup Pi-hole DNS for *.eldertree.local
# This script helps configure Pi-hole DNS resolution

set -e

ELDERTREE_IP="${ELDERTREE_IP:-192.168.2.83}"
KUBECONFIG="${KUBECONFIG:-~/.kube/config-eldertree}"

echo "🔧 Pi-hole DNS Setup for *.eldertree.local"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed"
    exit 1
fi

# Check if Pi-hole is deployed
export KUBECONFIG="${KUBECONFIG/#\~/$HOME}"
if ! kubectl get deployment pihole -n pihole &> /dev/null; then
    echo "⚠️  Warning: Pi-hole deployment not found in namespace 'pihole'"
    echo "   Deploy Pi-hole first: kubectl apply -f clusters/eldertree/infrastructure/pihole/"
    exit 1
fi

echo "✅ Pi-hole is deployed"
echo ""

# Check Pi-hole pod status
POD_STATUS=$(kubectl get pods -n pihole -l app=pihole -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [ "$POD_STATUS" != "Running" ]; then
    echo "⚠️  Warning: Pi-hole pod is not running (status: ${POD_STATUS})"
    echo "   Check: kubectl get pods -n pihole"
    echo ""
fi

# Get Pi-hole service info
echo "📡 Pi-hole Service Information:"
kubectl get svc pihole -n pihole
echo ""

# Show DNS entries from ConfigMap
echo "📋 Current DNS Entries (from ConfigMap):"
kubectl get configmap pihole-dnsmasq -n pihole -o jsonpath='{.data.05-custom-dns\.conf}' 2>/dev/null || echo "ConfigMap not found"
echo ""
echo ""

# Show how to access Pi-hole
echo "🌐 Access Pi-hole:"
echo "   Web UI: https://pihole.eldertree.local"
echo "   Or: http://${ELDERTREE_IP}:30080"
echo ""

# Show how to configure DNS
echo "⚙️  Configure DNS on your device:"
echo ""
echo "   Option 1: Router DNS (Recommended - Network-wide)"
echo "   - Set Pi-hole as primary DNS: ${ELDERTREE_IP}:30053"
echo "   - All devices will automatically use Pi-hole"
echo ""
echo "   Option 2: macOS System Settings"
echo "   - System Settings → Network → Your connection → Details → DNS"
echo "   - Add: ${ELDERTREE_IP}"
echo "   - Note: Use port 30053 if your router requires port specification"
echo ""

# Show how to add new entries
echo "➕ To add new DNS entries:"
echo ""
echo "   1. Edit ConfigMap:"
echo "      kubectl edit configmap pihole-dnsmasq -n pihole"
echo ""
echo "   2. Or update file and apply:"
echo "      vim clusters/eldertree/infrastructure/pihole/configmap.yaml"
echo "      kubectl apply -f clusters/eldertree/infrastructure/pihole/configmap.yaml"
echo ""
echo "   3. Restart Pi-hole to reload:"
echo "      kubectl rollout restart deployment/pihole -n pihole"
echo ""

# Test DNS resolution
echo "🧪 Test DNS resolution:"
echo ""
echo "   nslookup canopy.eldertree.local ${ELDERTREE_IP}"
echo "   dig @${ELDERTREE_IP} canopy.eldertree.local"
echo ""

