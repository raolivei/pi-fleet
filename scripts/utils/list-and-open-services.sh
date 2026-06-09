#!/bin/bash

# List and test all service ingresses, then open in Firefox
CLUSTER_IP="192.168.2.200"
DOMAIN="eldertree.local"

declare -a SERVICES=(
    "canopy"
    "vault"
    "grafana"
)

echo "=========================================="
echo "Pi Fleet Service Addresses"
echo "=========================================="
echo ""
echo "Traefik VIP: $CLUSTER_IP"
echo "Domain: $DOMAIN"
echo ""

echo "All Services (from cluster):"
echo "----------------------------"
export KUBECONFIG=~/.kube/config-eldertree
kubectl get svc --all-namespaces -o wide 2>/dev/null | grep -E "NAME|canopy|bind|vault|grafana|prometheus" || echo "  (Unable to query cluster)"

echo ""
echo "Services with Ingress (Frontends):"
echo "----------------------------------"

for service in "${SERVICES[@]}"; do
    url="https://${service}.${DOMAIN}"
    echo "  • $service: $url"
done

echo ""
echo "=========================================="
echo "Testing Ingress Connectivity"
echo "=========================================="
echo ""

for service in "${SERVICES[@]}"; do
    url="https://${service}.${DOMAIN}"
    echo -n "Testing $service... "
    http_code=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
    if [ "$http_code" = "200" ] || [ "$http_code" = "302" ] || [ "$http_code" = "301" ] || [ "$http_code" = "401" ]; then
        echo "✓ OK (HTTP $http_code)"
    elif [ -n "$http_code" ]; then
        echo "⚠ Responding but unexpected status (HTTP $http_code)"
    else
        echo "✗ Failed (no response or timeout)"
    fi
done

echo ""
echo "=========================================="
echo "Opening Services in Firefox"
echo "=========================================="
echo ""

for service in "${SERVICES[@]}"; do
    url="https://${service}.${DOMAIN}"
    echo "Opening $url..."
    open -a "Firefox" "$url" 2>/dev/null || {
        echo "  ⚠ Could not open Firefox. Please open manually: $url"
    }
    sleep 1
done

echo ""
echo "LAN DNS: dig @192.168.2.201 grafana.eldertree.local +short"
