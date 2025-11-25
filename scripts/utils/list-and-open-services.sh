#!/bin/bash

# List and test all service ingresses, then open in Firefox
# Control plane IP
CLUSTER_IP="192.168.2.83"
DOMAIN="eldertree.local"

# Services with ingresses (only those actually deployed)
declare -a SERVICES=(
    "canopy"
    "pihole"
    "vault"
)

echo "=========================================="
echo "Pi Fleet Service Addresses"
echo "=========================================="
echo ""
echo "Control Plane IP: $CLUSTER_IP"
echo "Domain: $DOMAIN"
echo ""

# Get all service addresses from cluster
echo "All Services (from cluster):"
echo "----------------------------"
export KUBECONFIG=~/.kube/config-eldertree
kubectl get svc --all-namespaces -o wide 2>/dev/null | grep -E "NAME|canopy|pihole|vault|grafana|prometheus" || echo "  (Unable to query cluster)"

echo ""
echo "Services with Ingress (Frontends):"
echo "----------------------------------"

for service in "${SERVICES[@]}"; do
    # Pi-hole needs /admin path
    if [ "$service" = "pihole" ]; then
        url="https://${service}.${DOMAIN}/admin/"
    else
        url="https://${service}.${DOMAIN}"
    fi
    echo "  • $service: $url"
done

echo ""
echo "=========================================="
echo "Testing Ingress Connectivity"
echo "=========================================="
echo ""

# Test each service
for service in "${SERVICES[@]}"; do
    # Pi-hole needs /admin path for testing
    if [ "$service" = "pihole" ]; then
        url="https://${service}.${DOMAIN}/admin/"
    else
        url="https://${service}.${DOMAIN}"
    fi
    echo -n "Testing $service... "
    
    # Use curl with -k to ignore self-signed cert, -s for silent, -o /dev/null to discard output
    # -w "%{http_code}" to get status code, --max-time 5 for timeout
    http_code=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "302" ] || [ "$http_code" = "301" ] || [ "$http_code" = "401" ]; then
        echo "✓ OK (HTTP $http_code)"
    elif [ "$http_code" = "403" ] && [ "$service" = "pihole" ]; then
        # Pi-hole root path returns 403, but /admin/ works
        echo "✓ OK (HTTP $http_code - use /admin/ path)"
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

# Open all services in Firefox
for service in "${SERVICES[@]}"; do
    # Pi-hole needs /admin path
    if [ "$service" = "pihole" ]; then
        url="https://${service}.${DOMAIN}/admin/"
    else
        url="https://${service}.${DOMAIN}"
    fi
    echo "Opening $url..."
    open -a "Firefox" "$url" 2>/dev/null || {
        echo "  ⚠ Could not open Firefox. Please open manually: $url"
    }
    # Small delay to avoid overwhelming Firefox
    sleep 1
done

echo ""
echo "Done! All services should be opening in Firefox."
echo "Note: You may need to accept self-signed certificate warnings."

